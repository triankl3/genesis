local RunService = game:GetService("RunService")
local Perlin3D = {}
Perlin3D.__index = Perlin3D

local TERRAIN = workspace.Terrain
local BLOCK_SIZE = 4
local VECTOR3_BLOCK_SIZE = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)

local SNAP_RAY_PARAMS = RaycastParams.new()
SNAP_RAY_PARAMS.IgnoreWater = true
SNAP_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Include
SNAP_RAY_PARAMS.FilterDescendantsInstances = {TERRAIN}

-- Returns a float value from 0-1 that represents the density at the given 3D position, calculated using Perlin noise
local function getPerlinDensity(x, y, z, seed, frequency, verticalScale)
    return ((
        math.noise(y / frequency, z / frequency, seed) +
        math.noise(x / frequency, z / frequency, seed) * verticalScale +
        math.noise(x / frequency, y / frequency, seed)
    ) + 1) / 2
end

local function getSmoothCurve(x)
    return 3 * math.pow(x, 2) - 2 * math.pow(x, 3)
end

-- Returns a float value from 0-1 based on the distance from the center of the map in a spherical shape
local function getSphereFalloff(position, falloffRadius, mapRadius)
    local distance = (position - Vector3.new(0, 0, 0)).Magnitude
    if distance < falloffRadius then return 1 end -- No falloff until a certain distance

    -- Determine the falloff if applied
    local falloff = ((distance - falloffRadius) / mapRadius) / (1 - falloffRadius / mapRadius)
    falloff = math.clamp(falloff, 0, 1)
    return 1 - getSmoothCurve(falloff)
end

-- Simply writes a block of voxels to the terrain, simplifyting the process to just a position and material
local function writeVoxels(position, material)
    TERRAIN:WriteVoxels(
        Region3.new(position - Vector3.new(2, 2, 2), position + Vector3.new(2, 2, 2)):ExpandToGrid(BLOCK_SIZE),
        BLOCK_SIZE,
        {{{material, material},{material, material},},{{material, material},{material, material},}},
        {{{1, 1},{1, 1}},{{1, 1},{1, 1}}}
    )
end

-- Returns a random unit vector direction based on the given seed (equally distributed chances sphere)
local function randomUnitVector(seed)
    local rng = Random.new(seed)
	local sqrt = math.sqrt(-2 * math.log(rng:NextNumber()))
	local angle = 2 * math.pi * rng:NextNumber()

	return Vector3.new(
		sqrt * math.cos(angle),
		sqrt * math.sin(angle),
		math.sqrt(-2 * math.log(rng:NextNumber())) * math.cos(2 * math.pi * rng:NextNumber())
	).Unit
end

function Perlin3D.new(mapConfig, assetContainer, mapContainer)
    local self = setmetatable({}, Perlin3D)

    local debugStats = { total = {}, time = {} }
    debugStats["time"]["start"] = tick()

    -- Store references to the map config and map container
    self._mapConfig = mapConfig
    self._mapContainer = mapContainer

    -- Prepare seeds for generators, based on original supplied seed
    local rng = Random.new(mapConfig.seed or math.random(0, 10e6))
    self._densitySeed = rng:NextInteger(0, 10e6)
    self._outlineDensitySeed = rng:NextInteger(0, 10e6)
    self._alternativeMaterialSeed = rng:NextInteger(0, 10e6)
    self._noiseMaterialSeed = rng:NextInteger(0, 10e6)
    self._objectMaterialSeed = rng:NextInteger(0, 10e6)
    self._spikeSeed = rng:NextInteger(0, 10e6)
    self._objectSeed = rng:NextInteger(0, 10e6)

    -- Apply material colors from config
    local materialConfig = mapConfig.generatorConfig.material
    TERRAIN:SetMaterialColor(materialConfig.primaryMaterial, materialConfig.primaryMaterialColor)
    TERRAIN:SetMaterialColor(materialConfig.alternativeMaterial, materialConfig.alternativeMaterialColor)
    TERRAIN:SetMaterialColor(materialConfig.noiseMaterial, materialConfig.noiseMaterialColor)
    TERRAIN:SetMaterialColor(materialConfig.objectMaterial, materialConfig.objectMaterialColor)

    debugStats["time"]["prepare"] = tick()

    -- Perform generation
    local objectProbes, spikeProbes = self:_generateTerrain()
    while true do -- Wait for terrain to be hopefully updated after heavy generation and can finally be raycasted upon
        local rayResult = workspace:Raycast(
            Vector3.new(0, 0, 0),
            Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)),
            SNAP_RAY_PARAMS
        )
        if not rayResult then continue end
        if rayResult.Instance == TERRAIN then break end
        RunService.Heartbeat:Wait()
    end
    debugStats["time"]["terrain"] = tick()
    if objectProbes then
        debugStats["total"]["objectProbes"] = #objectProbes
    end
    if spikeProbes then
        debugStats["total"]["spikeProbes"] = #spikeProbes
    end

    local totalSpikes = self:_generateSpikes(spikeProbes)
    debugStats["time"]["spikes"] = tick()
    debugStats["total"]["spikes"] = totalSpikes

    local objectPoints = self:_prepareObjectPoints(objectProbes)
    debugStats["time"]["objectPoints"] = tick()
    if objectPoints then
        debugStats["total"]["objectPoints"] = #objectPoints
    end

    local objectPrefabs = self:_prepareObjectPrefabs(assetContainer)
    debugStats["time"]["objectPrefabs"] = tick()
    if objectPrefabs then
        debugStats["total"]["objectPrefabs"] = #objectPrefabs
    end

    local totalObjects = self:_generateObjects(objectPoints, objectPrefabs)
    debugStats["time"]["objectGeneration"] = tick()
    debugStats["total"]["objects"] = totalObjects

    return self, debugStats
end

function Perlin3D:Destroy()
    self = nil
end

function Perlin3D:_generateTerrain()
    local material2Rng = Random.new(self._alternativeMaterialSeed)
    local spikeRng = Random.new(self._spikeSeed)
    local objectRng = Random.new(self._objectSeed)

    local terrainConfig = self._mapConfig.generatorConfig.terrain
    local materialConfig = self._mapConfig.generatorConfig.material
    local spikesConfig = self._mapConfig.generatorConfig.spikes

    local mapSizeStuds = self._mapConfig.size
    local mapSizeBlocksHalf = (mapSizeStuds / BLOCK_SIZE) / 2

    local occupancyCache = {}
    local spikeProbes = {}
    local objectProbes = {}

    -- Loop over every block in the map, centered around 0,0,0
    for x = -mapSizeBlocksHalf, mapSizeBlocksHalf do
        occupancyCache[x] = {} -- Create a new table for the x axis
        for y = -mapSizeBlocksHalf, mapSizeBlocksHalf do
            occupancyCache[x][y] = {} -- Create a new table for the y axis
            for z = -mapSizeBlocksHalf, mapSizeBlocksHalf do
                local studsPosition = Vector3.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE) -- The position in real studs
                local terrainDensity = 0 -- The terrain density starts at 0 before being calculated

                -- If the minimum outline density is met, calculate real terrain density
                local outlineDensity = getPerlinDensity(x, y, z, self._outlineDensitySeed, terrainConfig.outlineFrequency, 1)
                if outlineDensity < terrainConfig.outlineMinDensity then
                    terrainDensity = getPerlinDensity(x, y, z, self._densitySeed, terrainConfig.frequency, terrainConfig.verticalScale)
                    terrainDensity *= getSphereFalloff(studsPosition, mapSizeStuds * terrainConfig.falloffStart, mapSizeStuds)
                end

                -- If the terrain density is above the minimum, generate terrain
                if terrainDensity > terrainConfig.minDensity then -- FILLED
                    -- Determine the final material used to fill the voxel that is being generated
                    local finalMaterial = materialConfig.primaryMaterial
                    if getPerlinDensity(x, y, z, self._noiseMaterialSeed, terrainConfig.noiseMaterialFrequency, 1) > terrainConfig.noiseMaterialMinDensity then
                        finalMaterial = materialConfig.noiseMaterial
                    else
                        if material2Rng:NextInteger(1, terrainConfig.alternativeMaterialChance) == 1 then
                            finalMaterial = materialConfig.alternativeMaterial
                        end
                    end

                    writeVoxels(studsPosition, finalMaterial)
                else -- AIR
                    -- Determine if a spike could be generated here
                    if spikesConfig then
                        if spikeRng:NextInteger(1, spikesConfig.chance) == 1 then
                            table.insert(spikeProbes, studsPosition)
                        end
                    end
                end

                -- Write to the occupancy cache
                local currentOccupancy = terrainDensity > terrainConfig.minDensity and true or false
                occupancyCache[x][y][z] = currentOccupancy

                -- Determine if there have been changes to the occupancy
                local xChange = false
                local yChange = false
                local zChange = false

                if occupancyCache[x-1] then
                    if currentOccupancy ~= occupancyCache[x-1][y][z] then
                        xChange = true
                    end
                end
                if occupancyCache[x][y-1] then
                    if currentOccupancy ~= occupancyCache[x][y-1][z] then
                        yChange = true
                    end
                end
                if occupancyCache[x][y][z-1] then
                    if currentOccupancy ~= occupancyCache[x][y][z-1] then
                        zChange = true
                    end
                end

                -- Apply object material based on the occupancy changes
                if yChange then
                    if getPerlinDensity(x, y, z, self._objectMaterialSeed, terrainConfig.objectMaterialFrequency, 1) > terrainConfig.objectMaterialMinDensity then
                        local previousPosition = studsPosition - Vector3.new(0, BLOCK_SIZE, 0)
                        TERRAIN:ReplaceMaterial(
                            Region3.new(previousPosition - VECTOR3_BLOCK_SIZE, previousPosition + VECTOR3_BLOCK_SIZE):ExpandToGrid(BLOCK_SIZE),
                            BLOCK_SIZE,
                            materialConfig.primaryMaterial,
                            materialConfig.objectMaterial
                        )
                    end
                end

                -- Only write a certain percentage of probes to improve performance / reduce density of object calculations
                if objectRng:NextInteger(1, terrainConfig.objectProbeChance) == 1 then
                    if xChange or yChange or zChange then
                        table.insert(objectProbes, {
                            position = studsPosition,
                            xChange = xChange,
                            yChange = yChange,
                            zChange = zChange,
                        })
                    end
                end
            end
        end
        RunService.Heartbeat:Wait()
    end

    return objectProbes, spikeProbes
end

function Perlin3D:_generateSpikes(spikeProbes)
    local spikesRng = Random.new(self._spikeSeed)
    local spikesConfig = self._mapConfig.generatorConfig.spikes
    local materialConfig = self._mapConfig.generatorConfig.material

    local totalSpikes = 0
    for _, spikeProbe in ipairs(spikeProbes) do
        -- Get random direction and try to hit terrain with it
        local direction = randomUnitVector(spikesRng:NextInteger(0, 10e6))
        local startRayResult = workspace:Raycast(spikeProbe, direction * 512, SNAP_RAY_PARAMS)
        if not startRayResult then continue end

        -- Calculate if there is enough space to generate the spike
        local endRayResult = workspace:Raycast(startRayResult.Position, startRayResult.Normal * (spikesConfig.lengthMax + spikesConfig.minGap), SNAP_RAY_PARAMS)
        if not endRayResult then -- Create a faux result in case we hit nothing
            endRayResult = {
                Distance = spikesConfig.lengthMax + spikesConfig.minGap,
                Position = startRayResult.Position + (startRayResult.Normal * (spikesConfig.lengthMax + spikesConfig.minGap))
            }
        end

        -- Make sure we have enough space to create a spike here
        if endRayResult.Distance < spikesConfig.lengthMin + spikesConfig.minGap then continue end

        -- Randomize the spike length based on how much space is available
        local spikeLength = spikesRng:NextInteger(spikesConfig.lengthMin, endRayResult.Distance - spikesConfig.minGap)

        -- Loop over points in the spike and create it using fill ball
        local currentDist = 0
        local currentCFrame = CFrame.new(startRayResult.Position, endRayResult.Position)
        while currentDist < spikeLength do
            local radius = math.clamp(spikesConfig.width * (1 - (currentDist / spikeLength)), 2, spikesConfig.width)
            TERRAIN:FillBall(
                currentCFrame.Position,
                radius,
                materialConfig.noiseMaterial
            )

            currentDist += 2
            currentCFrame *= CFrame.new(0, 0, -2)
        end

        totalSpikes += 1
    end

    return totalSpikes
end

function Perlin3D:_prepareObjectPoints(objectProbes)
    local materialConfig = self._mapConfig.generatorConfig.material
    local objectPoints = {}

    local function determineObjectPoint(position, direction, categoryName)
        -- Raycast to snap to terrain
        local rayResult = workspace:Raycast(
            position + (-direction * 16),
            direction * 16,
            SNAP_RAY_PARAMS
        )

        -- If no terrain on snap, discard probe
        if not rayResult then return end

        -- Only allow points to on these materials, otherwise discard probe
        local materialName
        if rayResult.Material == materialConfig.primaryMaterial then
            materialName = "primary"
        elseif rayResult.Material == materialConfig.alternativeMaterial then
            materialName = "alternative"
        elseif rayResult.Material == materialConfig.objectMaterial then
            materialName = "object"
        else
            return
        end

        -- Round the vector3 to make the object point table indexable like an array
        local finalX = math.round(rayResult.Position.X)
        local finalY = math.round(rayResult.Position.Y)
        local finalZ = math.round(rayResult.Position.Z)

        -- Insert into multidimensional dictionary of positions
        if not objectPoints[finalX] then objectPoints[finalX] = {} end
        if not objectPoints[finalX][finalY] then objectPoints[finalX][finalY] = {} end
        objectPoints[finalX][finalY][finalZ] = {
            ["material"] = materialName,
            ["normal"] = rayResult.Normal,
            ["direction"] = direction,
            ["category"] = categoryName
        }
    end

    for _, objectProbe in ipairs(objectProbes) do
        if objectProbe["xChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(1, 0, 0), "side")
            determineObjectPoint(objectProbe["position"], Vector3.new(-1, 0, 0), "side")
        end
        if objectProbe["yChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 1, 0), "ceiling")
            determineObjectPoint(objectProbe["position"], Vector3.new(0, -1, 0), "floor")
        end
        if objectProbe["zChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 0, 1), "side")
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 0, -1), "side")
        end
    end

    return objectPoints
end

function Perlin3D:_prepareObjectPrefabs(assetContainer)
    local objectPrefabs = {}
    local prefabConfig = self._mapConfig.generatorConfig.prefabs
    if not prefabConfig then return end

    return objectPrefabs
end

function Perlin3D:_generateObjects(objectPoints, objectPrefabs)
    if not objectPoints then return end
    local prefabConfig = self._mapConfig.generatorConfig.prefabs
    if not prefabConfig then return end
end

return Perlin3D