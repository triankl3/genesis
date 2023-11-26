--[[
    this oop module handles creating procedural cave maps from a multitude of highly customizable files
    optimized to be quick at generation of small to medium size maps, however complexity is O to 3, meaning
    it get's slower by cubed the larger the map is, keep that in mind

    the configuration files are called biomes and have a specific table layout for defining the generation properties and settings
    which in return allows for multiple interchangable configs, with different visual styles and gameplay related alterations
]]
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain
local RunService = game:GetService("RunService")
local scaleModel = require(ReplicatedStorage._SharedModule.Util:WaitForChild("ScaleModel"))
local tableDeepCopy = require(ReplicatedStorage._SharedModule.Util:WaitForChild("TableDeepCopy"))
local tableAverage = require(ReplicatedStorage._SharedModule.Util:WaitForChild("TableAverage"))

local STATIC_ASSET_PARENT = ReplicatedStorage.SharedAsset.Map:WaitForChild("Static")
local BLOCK_SIZE = 4
local MAX_MAP_SIZE = 512
local FOUR_VECTOR = Vector3.new(4, 4, 4)
local VERTICAL_MAP_REGION_MULTIPLIER = 4
local HORIZONTAL_MAP_REGION_MULTIPLIER = 2

local SNAP_RAY_PARAMS = RaycastParams.new()
SNAP_RAY_PARAMS.IgnoreWater = true
SNAP_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist
SNAP_RAY_PARAMS.FilterDescendantsInstances = {Terrain}

local PROXIMITY_OVERLAP_PARAMS = OverlapParams.new()
PROXIMITY_OVERLAP_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist
PROXIMITY_OVERLAP_PARAMS.MaxParts = 20

local function perlin3D(position, seed, frequency, vertDiv)
    assert(position, "You need to provide a position when using noise!")
    assert(seed, "You need to provide a seed when using noise!")
    vertDiv = vertDiv or 1

    return ((
        math.noise(position.Y / frequency, position.Z / frequency, seed) +
        math.noise(position.X / frequency, position.Z / frequency, seed) / vertDiv +
        math.noise(position.X / frequency, position.Y / frequency, seed)
    ) + 1) / 2
end

local function smoothCurve(x)
    return 3 * math.pow(x, 2) - 2 * math.pow(x, 3) --smooth, and faster
    --return 6 * math.pow(x, 5) - 15 * math.pow(x, 4) + 10 * math.pow(x, 3) --even smoother
end

local function getFalloff(startPosition, currentPosition, falloffRadius, mapRadius)
    local distance = (startPosition - currentPosition).Magnitude
    if distance < falloffRadius then return 1 end --no falloff until a certain distance

    --determine the falloff
    local x = ((distance - falloffRadius) / mapRadius) / (1 - falloffRadius / mapRadius)
    x = math.clamp(x, 0, 1)
    return 1 - smoothCurve(x)
end

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


local CaveMap = {}
CaveMap.__index = CaveMap

function CaveMap.new(mapContainer, objectContainer, mapModifiers)
    local self = setmetatable({}, CaveMap)

    local startTime = tick()

    --warn if the map is too large than we usually expect
    if mapModifiers["size"] > MAX_MAP_SIZE then error("GENERATING MAP LARGER THAN MAX SIZE: " .. tostring(mapModifiers["size"]) .. "studs!") end

    self._mapContainer = mapContainer
    self._objectContainer = objectContainer

    --get biome configuration file
    local biome = script.Biome:WaitForChild(mapModifiers["biome"])
    if not biome then error("Invalid biome name specified in map modifiers!") end
    biome = require(biome)

    --read map modifiers
    self._mapSizeStuds = mapModifiers["size"]
    self._mapSize = mapModifiers["size"] / BLOCK_SIZE

    --randomize or use supplied seed
    self._rng = Random.new(mapModifiers["seed"] or math.random(0, 10e6))
    self._noiseSeed1 = self._rng:NextInteger(0, 10e6)
    self._noiseSeed2 = self._rng:NextInteger(0, 10e6)
    self._noiseSeed3 = self._rng:NextInteger(0, 10e6)
    self._noiseSeed4 = self._rng:NextInteger(0, 10e6)
    self._secondaryMaterialSeed = self._rng:NextInteger(0, 10e6)
    self._spikesSeed = self._rng:NextInteger(0, 10e6)
    self._objectSeed = self._rng:NextInteger(0, 10e6)

    --read basic configuration file properties
    self._mapName = "Cave"
    self._biomeName = biome["name"]

    --apply per biome lighting settings overrides
    for k, v in pairs(biome["atmosphere"]) do
        Lighting.Atmosphere[k] = v
    end
    for k, v in pairs(biome["lighting"]) do
        Lighting[k] = v
    end
    for k, v in pairs(biome["colorCorrection"]) do
        Lighting.ColorCorrection[k] = v
    end

    --get settings for other mostly visual properties
    self._windSpeed = biome["wind"]["speed"]
    self._windDirection = biome["wind"]["direction"]
    self._windPower = biome["wind"]["power"]

    self._particlesType = biome["particles"]["type"]

    self._ambienceTrack = biome["music"]["ambience"]

    --get main terrain generation settings
    self._minDensity = biome["terrain"]["minDensity"]
    self._frequency = biome["terrain"]["frequency"]
    self._vertDiv = biome["terrain"]["vertDiv"]
    self._outlineMinDensity = biome["terrain"]["outlineMinDensity"]
    self._outlineFrequency = biome["terrain"]["outlineFrequency"]
    self._falloffStart = biome["terrain"]["falloffStart"]

    --get material related generation settings
    self._secondaryMaterialChance = biome["terrain"]["secondaryMaterialChance"]
    self._plantMaterialMinDensity = biome["terrain"]["plantMaterialMinDensity"]
    self._plantMaterialFrequency = biome["terrain"]["plantMaterialFrequency"]
    self._specialMaterialMinDensity = biome["terrain"]["specialMaterialMinDensity"]
    self._specialMaterialFrequency = biome["terrain"]["specialMaterialFrequency"]

    --get spike related generation settings
    self._spikesChance = biome["terrain"]["spikesChance"]
    self._spikesLengthMin = biome["terrain"]["spikesLengthMin"]
    self._spikesLengthMax = biome["terrain"]["spikesLengthMax"]
    self._spikesMinGap = biome["terrain"]["spikesMinGap"]
    self._spikesWidth = biome["terrain"]["spikesWidth"]

    --set up terrain materials
    self._primaryMaterial = biome["material"]["primary"]
    self._secondaryMaterial = biome["material"]["secondary"]
    self._plantMaterial = biome["material"]["plant"]
    self._specialMaterial = biome["material"]["special"]
    Terrain:SetMaterialColor(biome["material"]["primary"], biome["material"]["primaryColor"])
    Terrain:SetMaterialColor(biome["material"]["secondary"], biome["material"]["secondaryColor"])
    Terrain:SetMaterialColor(biome["material"]["plant"], biome["material"]["plantColor"])
    Terrain:SetMaterialColor(biome["material"]["special"], biome["material"]["specialColor"])

    --prepare material sounds table
    self._materialSounds = {
        [biome["material"]["primary"].Name] = biome["materialSounds"]["primary"],
        [biome["material"]["secondary"].Name] = biome["materialSounds"]["secondary"],
        [biome["material"]["plant"].Name] = biome["materialSounds"]["plant"],
        [biome["material"]["special"].Name] = biome["materialSounds"]["special"],
    }

    self._objectProbeChance = biome["object"]["probeChance"]
    self._objectColors = biome["object"]["colors"]
    self._objectPrefabs = biome["object"]["prefabs"]
    self._objectChances = biome["object"]["chances"]
    self._objectGroups = biome["object"]["groups"]

    --generate terrain
    local objectProbes, spikePoints = self:_generateTerrain() --generation returns possible points for other generation

    --wait for terrain to be hopefully updated after heavy generation
    while true do
        local rayResult = workspace:Raycast(
            Vector3.new(0, 0, 0),
            Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)),
            SNAP_RAY_PARAMS
        )
        if rayResult then
            if rayResult.Instance == Terrain then break end
        end
        RunService.Heartbeat:Wait()
    end

    --generate spikes
    self:_generateSpikes(spikePoints)

    --prepare and generate static objects
    self:_generateObjects(objectProbes)

    --set map region/border
    self._mapRegion = Region3.new(
        Vector3.new((-self._mapSizeStuds / 2) * HORIZONTAL_MAP_REGION_MULTIPLIER, (-self._mapSizeStuds / 2) * VERTICAL_MAP_REGION_MULTIPLIER, (-self._mapSizeStuds / 2) * HORIZONTAL_MAP_REGION_MULTIPLIER),
        Vector3.new((self._mapSizeStuds / 2) * HORIZONTAL_MAP_REGION_MULTIPLIER, (self._mapSizeStuds / 2) * VERTICAL_MAP_REGION_MULTIPLIER, (self._mapSizeStuds / 2) * HORIZONTAL_MAP_REGION_MULTIPLIER)
    )

    --create a bottom border part to allow for seamless drops from bottom to top of map
    local borderSize = self._mapSizeStuds * HORIZONTAL_MAP_REGION_MULTIPLIER
    local borderHeight = BLOCK_SIZE * BLOCK_SIZE
    local newBottomBorder = Instance.new("Part")
    newBottomBorder.Name = "MapBottomBorder"
    newBottomBorder.Transparency = 1
    newBottomBorder.Anchored = true
    newBottomBorder.CanCollide = false
    newBottomBorder.Size = Vector3.new(borderSize, borderHeight, borderSize)
    newBottomBorder.CFrame = CFrame.new(0, ((-self._mapSizeStuds / 2) * VERTICAL_MAP_REGION_MULTIPLIER) + borderHeight, 0)
    newBottomBorder.Parent = self._mapContainer

    --calculate final generation time
    self._genTime = math.round((tick() - startTime) * 100) / 100

    return self
end


function CaveMap:Destroy()
    self = nil
end


function CaveMap:_generateTerrain()
    --loop over all points in map and generate main terrain
    local objectProbes = {}
    local spikePoints = {}
    local occupancyCache = {}

    local secondaryMaterialRng = Random.new(self._secondaryMaterialSeed)
    local spikesRng = Random.new(self._spikesSeed)
    local actualTerrainSize = (self._mapSize / 2) - BLOCK_SIZE --inseam the terrain by a blocksize(helps with accuracy of object probes)
    local objectRng = Random.new(self._objectSeed)

    --loop over all points in space of the map
    for x = -self._mapSize / 2, self._mapSize / 2 do
        for y = -self._mapSize / 2, self._mapSize / 2 do
            for z = -self._mapSize / 2, self._mapSize / 2 do
                local position = Vector3.new(x * BLOCK_SIZE, y * BLOCK_SIZE, z * BLOCK_SIZE) --the current position in studs
                local terrainDensity = perlin3D(Vector3.new(x, y, z), self._noiseSeed1, self._frequency, self._vertDiv)

                --overwrite density to 0 if outside of outline noise density
                if perlin3D(Vector3.new(x, y, z), self._noiseSeed3, self._outlineFrequency) > self._outlineMinDensity then
                    terrainDensity = 0
                else
                    --check if an inseam needs to be added
                    if math.abs(x) > actualTerrainSize then terrainDensity = 0 end
                    if math.abs(y) > actualTerrainSize then terrainDensity = 0 end
                    if math.abs(z) > actualTerrainSize then terrainDensity = 0 end

                    --otherwise adjust for falloff on terrain density
                    terrainDensity *= getFalloff(Vector3.new(0, 0, 0), position, self._mapSize * self._falloffStart, self._mapSizeStuds)
                end

                if terrainDensity > self._minDensity then --FILLED
                    local determinedMaterial = nil --determine which material to use to fill the terrain

                    --check if the special perlin noise exists
                    if perlin3D(Vector3.new(x, y, z), self._noiseSeed2, self._specialMaterialFrequency) > self._specialMaterialMinDensity then
                        determinedMaterial = self._specialMaterial --use special material in this case
                    else --use primary or secondary material based on chance(produces same results using seed)
                        if secondaryMaterialRng:NextInteger(1, self._secondaryMaterialChance) == 1 then
                            determinedMaterial = self._secondaryMaterial --use secondary material
                        else
                            determinedMaterial = self._primaryMaterial --use primary material
                        end
                    end

                    --write voxels to the terrain with the determined material
                    Terrain:WriteVoxels(
                        Region3.new(position - Vector3.new(1,1,1), position + Vector3.new(1,1,1)):ExpandToGrid(BLOCK_SIZE),
						BLOCK_SIZE,
						{{{determinedMaterial, determinedMaterial},{determinedMaterial, determinedMaterial},},{{determinedMaterial, determinedMaterial},{determinedMaterial, determinedMaterial},}},
						{{{1, 1},{1, 1}},{{1, 1},{1, 1}}}
                    )
                else --AIR
                    --determine if plant material should be placed here using density
                    if perlin3D(Vector3.new(x, y, z), self._noiseSeed4, self._plantMaterialFrequency) > self._plantMaterialMinDensity then
                        --replace material underneath with plant material(makes sure plant material can't show up on ceilings)
                        local underMaterial = Terrain:ReadVoxels(
                            Region3.new(
                                Vector3.new(position.X - BLOCK_SIZE / 2, position.Y - BLOCK_SIZE, position.Z - BLOCK_SIZE / 2),
                                Vector3.new(position.X + BLOCK_SIZE / 2, position.Y, position.Z + BLOCK_SIZE / 2)
                            ):ExpandToGrid(BLOCK_SIZE), BLOCK_SIZE
                        )[1][1][1]

                        if underMaterial ~= Enum.Material.Air then
                            Terrain:ReplaceMaterial(
                                Region3.new(position - FOUR_VECTOR, position + FOUR_VECTOR):ExpandToGrid(BLOCK_SIZE),
                                BLOCK_SIZE,
                                underMaterial,
                                self._plantMaterial
                            )
                        end
                    end

                    --determine if we should create spikes here
                    if self._spikesChance ~= 0 then --disable spikes if chance is 0
                        if spikesRng:NextInteger(1, self._spikesChance) == 1 then
                            table.insert(spikePoints, position)
                        end
                    end
                end

                --determine the current occupancy and save it to the cache
                local currentOccupancy = terrainDensity > self._minDensity and true or false
                if not occupancyCache[x] then occupancyCache[x] = {} end
                if not occupancyCache[x][y] then occupancyCache[x][y] = {} end
                occupancyCache[x][y][z] = currentOccupancy

                --determine the previous occupancies to detect changes
                if objectRng:NextInteger(1, self._objectProbeChance) == 1 then --discard a part of the probes to reduce the computational overhead in general
                    local xChange = false
                    local yChange = false
                    local zChange = false
                    if not occupancyCache[x-1] then
                        xChange = false
                    else
                        if currentOccupancy ~= occupancyCache[x-1][y][z] then
                            xChange = true
                        end
                    end
                    if not occupancyCache[x][y-1] then
                        yChange = false
                    else
                        if currentOccupancy ~= occupancyCache[x][y-1][z] then
                            yChange = true
                        end
                    end
                    if not occupancyCache[x][y][z-1] then
                        zChange = false
                    else
                        if currentOccupancy ~= occupancyCache[x][y][z-1] then
                            zChange = true
                        end
                    end

                    --if changes are detected save them into the object probes table
                    if xChange == true or yChange == true or zChange == true then
                        objectProbes[#objectProbes+1] = {
                            ["position"] = position,
                            ["xChange"] = xChange,
                            ["yChange"] = yChange,
                            ["zChange"] = zChange
                        }
                    end
                end
            end
        end
        RunService.Heartbeat:Wait()
    end

    return objectProbes, spikePoints
end

function CaveMap:_generateSpikes(spikePoints)
    local spikesRng = Random.new(self._spikesSeed)
    for _, spikePoint in ipairs(spikePoints) do
        --get random direction and try to hit terrain with it
        local direction = randomUnitVector(spikesRng:NextInteger(0, 10e6))
        local startRayResult = workspace:Raycast(spikePoint, direction * 512, SNAP_RAY_PARAMS)

        -- we hit terrain
        if startRayResult then
            --calculate if there is enough space to generate the spike
            local endRayResult = workspace:Raycast(startRayResult.Position, startRayResult.Normal * (self._spikesLengthMax + self._spikesMinGap), SNAP_RAY_PARAMS)
            if not endRayResult then --create a faux result in case we hit nothing
                endRayResult = {
                    Distance = self._spikesLengthMax + self._spikesMinGap,
                    Position = startRayResult.Position + (startRayResult.Normal * (self._spikesLengthMax + self._spikesMinGap))
                }
            end

            --if the ray exceeds the minimum distance needed to create a spike
            if endRayResult.Distance > self._spikesLengthMin + self._spikesMinGap then
                --randomize the spike length based on how much space is available
                local spikeLength = spikesRng:NextInteger(self._spikesLengthMin, endRayResult.Distance - self._spikesMinGap)

                --loop over points in the spike and create it using fill ball
                local currentDist = 0
                local currentCFrame = CFrame.new(startRayResult.Position, endRayResult.Position)
                while currentDist < spikeLength do
                    local radius = math.clamp(self._spikesWidth * (1 - (currentDist / spikeLength)), 2, self._spikesWidth)
                    Terrain:FillBall(
                        currentCFrame.Position,
                        radius,
                        self._specialMaterial
                    )

                    currentDist += 2
                    currentCFrame *= CFrame.new(0, 0, -2)
                end
            end
        end
    end
end

function CaveMap:_generateObjects(objectProbes)
    local objectPoints = {}
    local objectRng = Random.new(self._objectSeed)
    local scaleRng = objectRng:Clone()
    local rotationRng = objectRng:Clone()

    --set whitelist filter to include static objects container
    PROXIMITY_OVERLAP_PARAMS.FilterDescendantsInstances = {self._objectContainer}

    --category should be one of the following strings: ceiling, side, floor
    local function raycastDeterminePoint(position, direction, category)
        --raycast to snap to terrain and determine everything
        local rayResult = workspace:Raycast(
            position + (-direction * 16),
            direction * 16,
            SNAP_RAY_PARAMS
        )
        if rayResult then
            --make sure we only accept these three materials as a valid location for object points
            local materialString = nil
            if rayResult.Material == self._primaryMaterial then
                materialString = "primary"
            elseif rayResult.Material == self._secondaryMaterial then
                materialString = "secondary"
            elseif rayResult.Material == self._plantMaterial then
                materialString = "plant"
            else
                return
            end

            --round the vector3 to make the object point table indexable like an array
            local finalPosition = Vector3.new(
                math.round(rayResult.Position.X),
                math.round(rayResult.Position.Y),
                math.round(rayResult.Position.Z)
            )

            --insert into multidimensional dictionary of positions for proximity checking later on
            if not objectPoints[finalPosition.X] then objectPoints[finalPosition.X] = {} end
            if not objectPoints[finalPosition.X][finalPosition.Y] then objectPoints[finalPosition.X][finalPosition.Y] = {} end
            objectPoints[finalPosition.X][finalPosition.Y][finalPosition.Z] = {
                ["material"] = materialString,
                ["normal"] = rayResult.Normal,
                ["direction"] = direction,
                ["category"] = category
            }
        end
    end

    --returns all nearby points stored in object points 3d table
    local function getNearbyPoints(position, radius)
        local foundPointPositions = {}

        for x = math.floor(position.X - (radius / 2)), math.ceil(position.X + (radius / 2)) do
            for y = math.floor(position.Y - (radius / 2)), math.ceil(position.Y + (radius / 2)) do
                for z = math.floor(position.Z - (radius / 2)), math.ceil(position.Z + (radius / 2)) do
                    if not objectPoints[x] then continue end
                    if not objectPoints[x][y] then continue end
                    if not objectPoints[x][y][z] then continue end

                    if (Vector3.new(x, y, z) - position).Magnitude < radius then
                        foundPointPositions[#foundPointPositions+1] = Vector3.new(x, y, z)
                    end
                end
            end
        end

        return foundPointPositions
    end

    --turn object probes into object points with the needed data in the according format
    for _, objectProbe in ipairs(objectProbes) do
        if objectProbe["xChange"] then
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(-1, 0, 0),
                "side"
            )
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(1, 0, 0),
                "side"
            )
        end
        if objectProbe["yChange"] then
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(0, -1, 0),
                "floor"
            )
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(0, 1, 0),
                "ceiling"
            )
        end
        if objectProbe["zChange"] then
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(0, 0, -1),
                "side"
            )
            raycastDeterminePoint(
                objectProbe["position"],
                Vector3.new(0, 0, 1),
                "side"
            )
        end
    end

    --prepare prefabs
    local finalPrefabs = {}
    for prefabName, prefabConfig in pairs(self._objectPrefabs) do
        --detect if this is a cloned prefab config and add that to the stack of configs that need to be applied to get the final
        if prefabConfig["clone"] then
            prefabConfig = tableDeepCopy(prefabConfig) --deepcopy the original to prevent any overlapping changes
            local prefabCloneNameStack = {prefabName}
            local function sortPrefabConfigs()
                local cloneValue = self._objectPrefabs[prefabCloneNameStack[#prefabCloneNameStack]]["clone"]

                --if there is no more cloning end the recursive function
                if not cloneValue then return end

                prefabCloneNameStack[#prefabCloneNameStack+1] = cloneValue--add this to the stack

                sortPrefabConfigs()
            end
            sortPrefabConfigs()

            --apply the sorted prefab configs in a reverse order, i.e. each clone takes prescendence over the original cloned config
            for i = #prefabCloneNameStack, 1, -1 do
                for k, v in pairs(self._objectPrefabs[prefabCloneNameStack[i]]) do
                    prefabConfig[k] = v
                end
            end
        end

        --clone prefab from asset and name it properly
        local prefabObject = STATIC_ASSET_PARENT:FindFirstChild(prefabConfig["asset"]):Clone()
        prefabObject.Name = prefabName

        --set attributes used for destruction
        prefabObject:SetAttribute("DamageSound", prefabConfig["damageSound"])
        prefabObject:SetAttribute("BreakSound", prefabConfig["breakSound"])
        prefabObject:SetAttribute("Strength", prefabConfig["strength"])

        --set default roblox props
        for childName, rbxpropsTable in pairs(prefabConfig["rbxprops"]) do
            for k, v in pairs(rbxpropsTable) do
                if k == "Color" and typeof(v) == "string" then --inject colors from object colors table
                    v = self._objectColors[v]
                end
                prefabObject:FindFirstChild(childName)[k] = v --set prop
            end
        end

        --apply custom props that can be applied now
        if prefabConfig["customprops"]["sound"] then --apply sound custom prop
            local newSound = Instance.new("Sound")
            newSound.RollOffMode = Enum.RollOffMode.Linear
            newSound.Looped = true

            for k, v in pairs(prefabConfig["customprops"]["sound"]) do
                newSound[k] = v
            end

            newSound.Parent = prefabObject.PrimaryPart
            newSound:Play() --play automatically on loop
        end
        if prefabConfig["customprops"]["light"] then --apply light custom prop
            local newLight = Instance.new("PointLight")

            for k, v in pairs(prefabConfig["customprops"]["light"]) do
                if k == "Color" and typeof(v) == "string" then
                    newLight[k] = self._objectColors[v]
                    continue
                end
                newLight[k] = v
            end

            newLight.Parent = prefabObject.PrimaryPart
        end
        if prefabConfig["customprops"]["decal"] then
            local newDecalTemplate = Instance.new("Decal")
            for k, v in pairs(prefabConfig["customprops"]["decal"]) do
                if k == "Faces" then continue end
                if k == "Color3" and typeof(v) == "string" then
                    newDecalTemplate[k] = self._objectColors[v]
                    continue
                end
                newDecalTemplate[k] = v
            end
            for _, faceEnum in ipairs(prefabConfig["customprops"]["decal"]["Faces"]) do
                local newDecal = newDecalTemplate:Clone()
                newDecal.Face = faceEnum
                newDecal.Parent = prefabObject.PrimaryPart
            end
        end
        if prefabConfig["customprops"]["texture"] then --same as above for decal just do it for textures
            local newTextureTemplate = Instance.new("Texture")
            for k, v in pairs(prefabConfig["customprops"]["texture"]) do
                if k == "Faces" then continue end
                if k == "OtherChildren" then continue end
                if k == "Color3" and typeof(v) == "string" then
                    newTextureTemplate[k] = self._objectColors[v]
                    continue
                end
                newTextureTemplate[k] = v
            end
            local texturizedChildren = {prefabObject.PrimaryPart}
            if prefabConfig["customprops"]["texture"]["OtherChildren"] then
                for _, childName in ipairs(prefabConfig["customprops"]["texture"]["OtherChildren"]) do
                    table.insert(texturizedChildren, prefabObject:FindFirstChild(childName))
                end
            end
            for _, texturizedChild in ipairs(texturizedChildren) do
                for _, faceEnum in ipairs(prefabConfig["customprops"]["texture"]["Faces"]) do
                    local newTexture= newTextureTemplate:Clone()
                    newTexture.Face = faceEnum
                    newTexture.Parent = texturizedChild
                end
            end
        end

        finalPrefabs[prefabName] = { --save new prefab alongside it's proximity and customprops for later usage
            prefab = prefabObject,
            proximity = prefabConfig["proximity"],
            customprops = prefabConfig["customprops"]
        }
    end

    --loop over all groups and create ratio tables
    local ratioTables = {}
    for materialName, materialTable in pairs(self._objectGroups) do
        ratioTables[materialName] = {}
        for categoryName, categoryTable in pairs(materialTable) do
            ratioTables[materialName][categoryName] = {}
            for k, v in pairs(categoryTable) do
                for _ = 1, v do
                    table.insert(ratioTables[materialName][categoryName], k)
                end
            end
        end
    end

    --loop over every object point and decide where to place objects
    for x, yTable in pairs(objectPoints) do
        for y, zTable in pairs(yTable) do
            for z, objectPoint in pairs(zTable) do
                if objectPoint == nil then continue end --this point has already been discarded

                --determine which object to spawn here by name
                local newObjectName = ratioTables[objectPoint["material"]][objectPoint["category"]][objectRng:NextInteger(1, 100)]

                --check if this point is already banned from spawning certain objects
                if objectPoint["bannedObjects"] then
                    if objectPoint["bannedObjects"][newObjectName] then continue end --don't spawn the object if it's banned
                end

                --get prefab table and instance new object
                local newObjectPrefabTable = finalPrefabs[newObjectName]
                local newObject = newObjectPrefabTable["prefab"]:Clone()

                --get model size for base proximity check
                local size = newObject.PrimaryPart.Size
                local averageBoundingSize = tableAverage({size.X, size.Y, size.Z})

                --increase radius for check if specified in prefab proximity properties
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["extraRadius"] then
                        averageBoundingSize += newObjectPrefabTable["proximity"]["extraRadius"]
                    end
                end

                --look for already existing nearby objects for default proximity check
                local foundParts = workspace:GetPartBoundsInRadius(
                    Vector3.new(x, y, z),
                    averageBoundingSize,
                    PROXIMITY_OVERLAP_PARAMS
                )
                local foundOverlap = false
                for _, foundPart in ipairs(foundParts) do --destroy all existing parts found within radius
                    if not foundPart.Parent then continue end --account for already deleted objects
                    if not foundPart.Parent:IsA("Model") then continue end

                    foundOverlap = true
                    break
                end
                if foundOverlap then continue end --skip using this point completely if it's overlapping

                --same as above just for banned list
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["bannedRadius"] and newObjectPrefabTable["proximity"]["bannedList"] then
                        local foundBannedParts = workspace:GetPartBoundsInRadius(
                            Vector3.new(x, y, z),
                            newObjectPrefabTable["proximity"]["bannedRadius"],
                            PROXIMITY_OVERLAP_PARAMS
                        )
                        local foundBannedOverlap = false
                        for _, foundBannedPart in ipairs(foundBannedParts) do
                            if not foundBannedPart.Parent then continue end
                            if not foundBannedPart.Parent:IsA("Model") then continue end
                            if not newObjectPrefabTable["proximity"]["bannedList"][foundBannedPart.Parent.Name] then continue end --added name check for part against banned list

                            foundBannedOverlap = true
                            break
                        end
                        if foundBannedOverlap then continue end -- skip using this point completely if it's overlapping with banned parts
                    end
                end

                --apply scaling
                if newObjectPrefabTable["customprops"]["scale"] then
                    scaleModel(newObject, scaleRng:NextNumber(newObjectPrefabTable["customprops"]["scale"].Min, newObjectPrefabTable["customprops"]["scale"].Max))
                end

                if newObjectPrefabTable["customprops"]["stretch"] then
                    local determinedScale = scaleRng:NextNumber(newObjectPrefabTable["customprops"]["stretch"].Min, newObjectPrefabTable["customprops"]["stretch"].Max)
                    for _, child in ipairs(newObject:GetChildren()) do
                        child.Size *= Vector3.new(1, determinedScale, 1)
                    end
                end

                --calculate cframe
                local finalPosition = Vector3.new(x, y, z) + Vector3.new(0, newObject.PrimaryPart.Size.Y / 2, 0)
                local finalCFrame = CFrame.new(finalPosition, finalPosition + objectPoint["direction"])

                --use normal instead if specified
                if newObjectPrefabTable["customprops"]["useNormal"] then
                    finalCFrame = CFrame.new(finalPosition, finalPosition - objectPoint["normal"])
                end

                --rotate so the bottom is actually facing the direction
                finalCFrame *= CFrame.Angles(math.rad(90), 0, 0)

                --apply rotation offset if required
                if newObjectPrefabTable["customprops"]["randomRot"] then
                    finalCFrame *= CFrame.Angles(0, math.rad(rotationRng:NextInteger(0, 360)), 0)
                end

                --bury object if required
                if newObjectPrefabTable["customprops"]["bury"] then
                    finalCFrame -= Vector3.new(0, newObject.PrimaryPart.Size.Y * newObjectPrefabTable["customprops"]["bury"], 0)
                end

                --set primary cframe of object and parent
                newObject:SetPrimaryPartCFrame(finalCFrame)
                newObject.Parent = self._objectContainer

                --delete other nearby points due to default proxmity limits
                --this will delete any possible points nearby within the desired radius(prevents future objects using it/completely blocks object creation)
                for _, objectPointPosition in ipairs(getNearbyPoints(Vector3.new(x, y, z), averageBoundingSize)) do
                    objectPoints[objectPointPosition.X][objectPointPosition.Y][objectPointPosition.Z] = nil
                end

                --ban certain objects on nearby points due to banned proximity limits
                --same as above but doesn't delete and instead appends object names to table, the point can still spawn objects which aren't banned in the future
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["bannedRadius"] and newObjectPrefabTable["proximity"]["bannedList"] then
                        for _, objectPointPosition in ipairs(getNearbyPoints(Vector3.new(x, y, z), newObjectPrefabTable["proximity"]["bannedRadius"])) do
                            objectPoints[objectPointPosition.X][objectPointPosition.Y][objectPointPosition.Z]["bannedObjects"] = newObjectPrefabTable["proximity"]["bannedList"]
                        end
                    end
                end
            end
        end
    end

    --cleanup memory
    objectPoints = nil
    for _, finalPrefab in ipairs(finalPrefabs) do finalPrefab:Destroy() end
    finalPrefabs = nil
    ratioTables = nil
end


function CaveMap:GetMapInfo()
    return {
        generationTime = self._genTime,
        name = self._mapName,
        biome = self._biomeName,
        mapSize = self._mapSizeStuds,
        windSpeed = self._windSpeed,
        windDirection = self._windDirection,
        windPower = self._windPower,
        particlesType = self._particlesType,
        ambienceTrack = self._ambienceTrack,
        materialSounds = self._materialSounds,
        mapRegion = self._mapRegion
    }
end

function CaveMap:GetSpawnPoint()
    warn("using temporary solution for spawn points")
    return Vector3.new(0, 512, 0)
    -- local x = (self._mapSize / 2) - 100
    -- return Vector3.new(math.random(-x, x), 180, math.random(-x, x))
end


return CaveMap