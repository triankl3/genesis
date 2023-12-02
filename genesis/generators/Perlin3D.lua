local ProximityPromptService = game:GetService("ProximityPromptService")
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

local PROXIMITY_OVERLAP_PARAMS = OverlapParams.new()
PROXIMITY_OVERLAP_PARAMS.FilterType = Enum.RaycastFilterType.Include
PROXIMITY_OVERLAP_PARAMS.MaxParts = 20

-- Perform a deep copy of a table(supports nested tables using a recursive function)
function tableDeepCopy(original)
    local copy = {}

	for k, v in pairs(original) do
		if type(v) == "table" then
			v = tableDeepCopy(v)
		end
		copy[k] = v
	end

	return copy
end

-- Returns the average of all values in a table
function tableAverage(numberArrayTable)
    local sum = 0

    for _, value in ipairs(numberArrayTable) do
        sum += value
    end

    return sum / #numberArrayTable --return average
end

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

-- Change a model's scale by multiplying it
function scaleModel(model, scale)
    if not model.PrimaryPart then error("The specified model has no PrimaryPart!") end
    local primaryPartCFrame = model.PrimaryPart.CFrame

    for _, foundInstance in ipairs(model:GetDescendants()) do
        if foundInstance:IsA("BasePart") or foundInstance:IsA("MeshPart") then
            foundInstance.Size = foundInstance.Size * scale

            local distance = (foundInstance.Position - primaryPartCFrame.p)
			local rotation = (foundInstance.CFrame - foundInstance.Position)
			foundInstance.CFrame = (CFrame.new(primaryPartCFrame.p + distance * scale) * rotation)
        end
    end
end

local function findNearbyObjects(x, y, z, radius, mapContainer, bannedList)
    local foundParts = workspace:GetPartBoundsInRadius(
        Vector3.new(x, y, z),
        radius,
        PROXIMITY_OVERLAP_PARAMS
    )

    local foundOverlap = false
    for _, foundPart in ipairs(foundParts) do
        if not foundPart.Parent then continue end
        if not foundPart.Parent:IsA("Model") then continue end
        if not foundPart:IsDescendantOf(mapContainer) then continue end
        if bannedList then
            if not bannedList[foundPart.Name] then continue end
        end

        foundOverlap = true
        break
    end

    return foundOverlap
end

-- Returns all nearby points stored in object points 3d table
local function getNearbyPoints(position, radius, objectPoints)
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

function Perlin3D.new(mapConfig, assetContainer, mapContainer)
    local self = setmetatable({}, Perlin3D)

    local debugStats = { total = {}, time = {} }
    local startTime = tick()
    local savedStartTime = tick()

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

    debugStats["time"]["prepare"] = tick() - startTime

    -- Perform generation
    startTime = tick()
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
    debugStats["time"]["terrain"] = tick() - startTime

    if objectProbes then
        debugStats["total"]["objectProbes"] = #objectProbes
    end
    if spikeProbes then
        debugStats["total"]["spikeProbes"] = #spikeProbes
    end

    startTime = tick()
    local totalSpikes = self:_generateSpikes(spikeProbes)
    debugStats["time"]["spikes"] = tick() - startTime
    debugStats["total"]["spikes"] = totalSpikes

    startTime = tick()
    local objectPoints, totalObjectPoints = self:_prepareObjectPoints(objectProbes)
    debugStats["time"]["objectPoints"] = tick() - startTime
    debugStats["total"]["objectPoints"] = totalObjectPoints

    startTime = tick()
    local objectPrefabs, totalObjectPrefabs = self:_prepareObjectPrefabs(assetContainer)
    debugStats["time"]["objectPrefabs"] = tick() - startTime
    debugStats["total"]["objectPrefabs"] = totalObjectPrefabs

    startTime = tick()
    local totalObjects = self:_generateObjects(objectPoints, objectPrefabs)
    debugStats["time"]["objectGeneration"] = tick() - startTime
    debugStats["total"]["objects"] = totalObjects

    debugStats["time"]["total"] = tick() - savedStartTime

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

                    terrainDensity *= getSphereFalloff(studsPosition, (mapSizeStuds / 2) * terrainConfig.falloffStart, mapSizeStuds)
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
    local totalObjectPoints = 0

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
            ["material"] = materialName .. "Material",
            ["normal"] = rayResult.Normal,
            ["direction"] = direction,
            ["category"] = categoryName
        }
        totalObjectPoints += 1
    end

    for _, objectProbe in ipairs(objectProbes) do
        if objectProbe["xChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(1, 0, 0), "wall")
            determineObjectPoint(objectProbe["position"], Vector3.new(-1, 0, 0), "wall")
        end
        if objectProbe["yChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 1, 0), "ceiling")
            determineObjectPoint(objectProbe["position"], Vector3.new(0, -1, 0), "floor")
        end
        if objectProbe["zChange"] then
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 0, 1), "wall")
            determineObjectPoint(objectProbe["position"], Vector3.new(0, 0, -1), "wall")
        end
    end

    return objectPoints, totalObjectPoints
end

function Perlin3D:_prepareObjectPrefabs(assetContainer)
    local objectPrefabs = {}
    local totalObjectPrefabs = 0
    local prefabsConfig = self._mapConfig.generatorConfig.prefabs
    if not prefabsConfig then return end

    for prefabName, prefabConfig in pairs(prefabsConfig) do
        -- Detect if this is a cloned prefab config and add that to the stack of configs that need to be applied
        if prefabConfig["clone"] then
            prefabConfig = tableDeepCopy(prefabConfig) -- Copy to prevent overriden values
            local prefabCloneNameStack = {prefabName}
            local function sortPrefabConfigs()
                local cloneValue = prefabsConfig[prefabCloneNameStack[#prefabCloneNameStack]]["clone"]

                -- If there are no more clones, we can end the recursive function
                if not cloneValue then return end

                -- Otherwise keep adding the configs to the stack
                prefabCloneNameStack[#prefabCloneNameStack + 1] = cloneValue

                sortPrefabConfigs() -- Go another level deeper recursively
            end
            sortPrefabConfigs()

            -- Apply all the sorted prefab configs in reverse order, so each clone takes precedence over the previous
            for i = #prefabCloneNameStack, 1, -1 do
                for k, v in pairs(prefabsConfig[prefabCloneNameStack[i]]) do
                    prefabConfig[k] = v
                end
            end
        end

        -- Clone prefab from asset and name it properly
        local newPrefabObject = assetContainer:FindFirstChild(prefabConfig["asset"]):Clone()
        newPrefabObject.Name = prefabName

        -- Apply default roblox properties to any specified children
        if prefabConfig["rbxProperties"] then
            for childName, rbxPropertiesTable in pairs(prefabConfig["rbxProperties"]) do
                for k, v in pairs(rbxPropertiesTable) do
                    newPrefabObject:FindFirstChild(childName)[k] = v
                end
            end
        end

        -- Create sound if set
        if prefabConfig["sound"] then
            local newSound = Instance.new("Sound")
            newSound.Looped = true

            for k, v in pairs(prefabConfig["sound"]) do
                newSound[k] = v
            end

            newSound.Parent = newPrefabObject.PrimaryPart
            newSound:Play()
        end

        -- Create light if set
        if prefabConfig["light"] then
            local newLight = Instance.new("PointLight")

            for k, v in pairs(prefabConfig["light"]) do
                newLight[k] = v
            end

            newLight.Parent = newPrefabObject.PrimaryPart
        end

        -- Create decal(s) if set
        if prefabConfig["decal"] then
            local newDecalTemplate = Instance.new("Decal")
            for k, v in pairs(prefabConfig["decal"]) do
                if k == "faces" then continue end
                newDecalTemplate[k] = v
            end

            for _, faceEnum in ipairs(prefabConfig["decal"]["faces"]) do
                local newDecal = newDecalTemplate:Clone()
                newDecal.Face = faceEnum
                newDecal.Parent = newPrefabObject.PrimaryPart
            end
        end

        -- Create texture if set
        if prefabConfig["texture"] then --same as above for decal just do it for textures
            local newTextureTemplate = Instance.new("Texture")
            for k, v in pairs(prefabConfig["texture"]) do
                if k == "faces" then continue end
                if k == "otherChildren" then continue end
                newTextureTemplate[k] = v
            end

            local texturizedChildren = {newPrefabObject.PrimaryPart}
            if prefabConfig["texture"]["otherChildren"] then
                for _, childName in ipairs(prefabConfig["texture"]["otherChildren"]) do
                    table.insert(texturizedChildren, newPrefabObject:FindFirstChild(childName))
                end
            end

            for _, texturizedChild in ipairs(texturizedChildren) do
                for _, faceEnum in ipairs(prefabConfig["texture"]["faces"]) do
                    local newTexture = newTextureTemplate:Clone()
                    newTexture.Face = faceEnum
                    newTexture.Parent = texturizedChild
                end
            end
        end

        -- The rest of the properties are applied per object placed, save them alongside the prefab
        objectPrefabs[prefabName] = {
            prefabObject = newPrefabObject,
            proximity = prefabConfig["proximity"],
            scale = prefabConfig["scale"],
            randomRotation = prefabConfig["randomRotation"],
            bury = prefabConfig["bury"],
            useNormal = prefabConfig["useNormal"],
            stretch = prefabConfig["stretch"]
        }
        totalObjectPrefabs += 1
    end

    return objectPrefabs, totalObjectPrefabs
end

function Perlin3D:_generateObjects(objectPoints, objectPrefabs)
    if not objectPoints then return end
    if not objectPrefabs then return end
    local objectsConfig = self._mapConfig.generatorConfig.objects
    if not objectsConfig then return end

    -- Loop over all groups and create ratio tables
    local ratioTables = {}
    for materialName, materialTable in pairs(objectsConfig) do
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

    local objectRng = Random.new(self._objectSeed)
    local scaleRng = objectRng:Clone()
    local rotationRng = objectRng:Clone()
    local totalObjects = 0
    -- Loop over every object point and place objects
    for x, yTable in pairs(objectPoints) do
        for y, zTable in pairs(yTable) do
            for z, objectPoint in pairs(zTable) do
                if objectPoint == nil then continue end -- This point has already been discarded

                -- Recursively look for an object to place incase some are banned at this point
                local newObjectName = nil
                local currentAttempts = 0
                while currentAttempts < 10 do
                    currentAttempts += 1

                    local randomObjectName = ratioTables[objectPoint["material"]][objectPoint["category"]][objectRng:NextInteger(1, 100)]
                    if objectPoint["bannedObjects"] then
                        if objectPoint["bannedObjects"][randomObjectName] then continue end
                    end

                    newObjectName = randomObjectName
                    break
                end
                if not newObjectName then continue end -- No object could be placed here or we reached maximum attempts to find one

                -- Get prefab table and instance new object
                local newObjectPrefabTable = objectPrefabs[newObjectName]
                local newObject = newObjectPrefabTable["prefabObject"]:Clone()

                -- Get model size for base proximity check
                local size = newObject.PrimaryPart.Size
                local averageBoundingSize = tableAverage({size.X, size.Y, size.Z})

                -- Increase radius for check if specified in prefab proximity properties
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["extraRadius"] then
                        averageBoundingSize += newObjectPrefabTable["proximity"]["extraRadius"]
                    end
                end

                -- Look for already existing nearby objects and skip these points if overlaps are found
                local foundOverlap = findNearbyObjects(
                    x, y, z,
                    averageBoundingSize,
                    self._mapContainer
                )
                if foundOverlap then continue end
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["banned"] then
                        local foundBannedOverlap = findNearbyObjects(
                            x, y, z,
                            newObjectPrefabTable["proximity"]["banned"]["radius"],
                            self._mapContainer,
                            newObjectPrefabTable["proximity"]["banned"]["list"]
                        )
                        if foundBannedOverlap then continue end
                    end
                end

                -- Apply scaling if specified
                if newObjectPrefabTable["scale"] then
                    scaleModel(newObject, scaleRng:NextNumber(newObjectPrefabTable["scale"].Min, newObjectPrefabTable["scale"].Max))
                end

                -- Apply stretch if specified
                if newObjectPrefabTable["stretch"] then
                    local determinedScale = scaleRng:NextNumber(newObjectPrefabTable["stretch"].Min, newObjectPrefabTable["stretch"].Max)
                    for _, child in ipairs(newObject:GetChildren()) do
                        child.Size *= Vector3.new(1, determinedScale, 1)
                    end
                end

                -- Calculate CFrame
                local finalPosition = Vector3.new(x, y, z) + Vector3.new(0, newObject.PrimaryPart.Size.Y / 2, 0)
                local finalCFrame = CFrame.new(finalPosition, finalPosition + objectPoint["direction"])

                -- Use normal instead if specified
                if newObjectPrefabTable["useNormal"] then
                    finalCFrame = CFrame.new(finalPosition, finalPosition - objectPoint["normal"])
                end

                -- Rotate mdoel so the bottom is actually facing the direction
                finalCFrame *= CFrame.Angles(math.rad(90), 0, 0)

                -- Apply random rotation if specified
                if newObjectPrefabTable["randomRot"] then
                    finalCFrame *= CFrame.Angles(0, math.rad(rotationRng:NextInteger(0, 360)), 0)
                end

                -- Bury object if specified
                if newObjectPrefabTable["bury"] then
                    finalCFrame -= Vector3.new(0, newObject.PrimaryPart.Size.Y * newObjectPrefabTable["bury"], 0)
                end

                -- Set PrimaryPart CFrame and and parent to map contianer
                newObject:SetPrimaryPartCFrame(finalCFrame)
                newObject.Parent = self._mapContainer

                -- Delete other nearby points due to proximity limits, this speeds up the process of placing objects
                for _, objectPointPosition in ipairs(getNearbyPoints(Vector3.new(x, y, z), averageBoundingSize, objectPoints)) do
                    objectPoints[objectPointPosition.X][objectPointPosition.Y][objectPointPosition.Z] = nil
                end

                -- Ban objects on other nearby points due to banned proximity limits
                if newObjectPrefabTable["proximity"] then
                    if newObjectPrefabTable["proximity"]["banned"]["radius"] and newObjectPrefabTable["proximity"]["banned"]["list"] then
                        for _, objectPointPosition in ipairs(getNearbyPoints(Vector3.new(x, y, z), newObjectPrefabTable["proximity"]["banned"]["radius"], objectPoints)) do
                            objectPoints[objectPointPosition.X][objectPointPosition.Y][objectPointPosition.Z]["bannedObjects"] = newObjectPrefabTable["proximity"]["banned"]["list"]
                        end
                    end
                end

                totalObjects += 1
            end
        end
    end

    -- Cleanup memory
    objectPoints = nil
    for _, objectPrefab in ipairs(objectPrefabs) do objectPrefab:Destroy() end
    objectPrefabs = nil
    ratioTables = nil

    return totalObjects
end

return Perlin3D