local MaterialService = game:GetService("MaterialService")

-- Validate server environment
if game:GetService("RunService"):IsServer() == false then
    error("Genesis must run on the server!")
end

local GENERATORS = {}
for _, child in ipairs(script:WaitForChild("generators"):GetChildren()) do
    if not child:IsA("ModuleScript") then continue end
    GENERATORS[child.Name] = require(child)
end

--[[
    Use this to generate a folder of material variants for the terrain. Copy & paste into the command bar.
    Currently ColorMap cannot be edited via script(only plugin), so this is a workaround.

    local ALL_TERRAIN_MATERIALS = {
        Enum.Material.Asphalt,
        Enum.Material.Basalt,
        Enum.Material.Brick,
        Enum.Material.Cobblestone,
        Enum.Material.Concrete,
        Enum.Material.CrackedLava,
        Enum.Material.Glacier,
        Enum.Material.Grass,
        Enum.Material.Ground,
        Enum.Material.Ice,
        Enum.Material.LeafyGrass,
        Enum.Material.Limestone,
        Enum.Material.Mud,
        Enum.Material.Pavement,
        Enum.Material.Rock,
        Enum.Material.Salt,
        Enum.Material.Sand,
        Enum.Material.Sandstone,
        Enum.Material.Slate,
        Enum.Material.Snow,
        Enum.Material.WoodPlanks,
    }
    local WHITE_TEXTURE_ID = "rbxassetid://7658670519"
    for _, materialEnum in ipairs(ALL_TERRAIN_MATERIALS) do
        if materialEnum == Enum.Material.Air then continue end
        local newMaterialVariant = Instance.new("MaterialVariant")
        newMaterialVariant.Name = materialEnum.Name
        newMaterialVariant.BaseMaterial = materialEnum
        newMaterialVariant.ColorMap = WHITE_TEXTURE_ID
        newMaterialVariant.Parent = workspace
    end
]]
local FLAT_MATERIALS_FOLDER = script:WaitForChild("materials") -- Load them from a folder instead

--[=[
    @interface MapConfig
    @within Genesis

    .generatorConfig Perlin3DConfig
    .size number
    .seed number | nil
]=]
export type MapConfig = {
    generatorConfig : Perlin3DConfig,
    size : number,
    seed : number | nil
}

--[=[
    @interface Perlin3DConfig
    @within Genesis

    .generator "Perlin3D"
    .terrain { minDensity : number, frequency : number, verticalScale : number, outlineMinDensity : number, outlineFrequency : number, falloffStart : number, alternativeMaterialChance : number, noiseMaterialMinDensity : number, noiseMaterialFrequency : number, objectMaterialMinDensity : number, objectMaterialFrequency : number, objectProbeChance : number }
    .material { primaryMaterial : Enum.Material, alternativeMaterial : Enum.Material, noiseMaterial : Enum.Material, objectMaterial : Enum.Material, primaryMaterialColor : Color3, alternativeMaterialColor : Color3, noiseMaterialColor : Color3, objectMaterialColor : Color3 }
    .spikes { chance : number, lengthMin : number, lengthMax : number, minGap : number, width : number } | nil
    .prefabs { [string] : PrefabConfig | nil } | nil
    .objects { primaryMaterial : { ceiling : { [string] : number }, side : { [string] : number }, floor : { [string] : number } }, alternativeMaterial : { ceiling : { [string] : number }, side : { [string] : number }, floor : { [string] : number } }, objectMaterial : { ceiling : { [string] : number }, side : { [string] : number }, floor : { [string] : number } } } | nil
]=]
export type Perlin3DConfig = {
    generator : "Perlin3D",
    terrain : {
        minDensity : number,
        frequency : number,
        verticalScale : number,

        outlineMinDensity : number,
        outlineFrequency : number,

        falloffStart : number,

        alternativeMaterialChance : number,
        noiseMaterialMinDensity : number,
        noiseMaterialFrequency : number,
        objectMaterialMinDensity : number,
        objectMaterialFrequency : number,

        objectProbeChance : number,
    },
    material : {
        primaryMaterial: Enum.Material,
        alternativeMaterial : Enum.Material,
        noiseMaterial : Enum.Material,
        objectMaterial : Enum.Material,

        primaryMaterialColor : Color3,
        alternativeMaterialColor : Color3,
        noiseMaterialColor : Color3,
        objectMaterialColor : Color3,
    },
    spikes : {
        chance : number,
        lengthMin : number,
        lengthMax : number,
        minGap : number,
        width : number,
    } | nil,
    prefabs : {
        [string] : PrefabConfig | nil
    } | nil,
    objects : {
        primaryMaterial : {
            ceiling : {
                [string] : number
            },
            side : {
                [string] : number
            },
            floor : {
                [string] : number
            },
        },
        alternativeMaterial : {
            ceiling : {
                [string] : number
            },
            side : {
                [string] : number
            },
            floor : {
                [string] : number
            },
        },
        objectMaterial : {
            ceiling : {
                [string] : number
            },
            side : {
                [string] : number
            },
            floor : {
                [string] : number
            },
        }
    } | nil
}

--[=[
    @interface PrefabConfig
    @within Genesis

    .clone string | nil
    .asset string
    .rbxProperties { [string] : { [string] : any } | nil } | nil
    .proximity { extraRadius : number | nil, banned : { bannedRadius : number, bannedList : { string } } | nil } | nil
    .scale NumberRange
    .randomRotation boolean | nil
    .bury boolean | nil
    .useNormal boolean | nil
    .sound { [string] : any } | nil
    .decal { faces : { Enum.NormalId }, [string] : any } | nil
    .stretch NumberRange | nil
    .texture { otherChildren : { string } | nil, faces : { Enum.NormalId }, [string] : any } | nil
]=]
export type PrefabConfig = {
    clone : string | nil,
    asset : string,

    rbxProperties : {
        [string] : {
            [string] : any
        } | nil
    } | nil,

    proximity : {
        extraRadius : number | nil,
        banned : {
            radius : number,
            list : { string }
        } | nil,
    } | nil,

    scale : NumberRange,
    stretch : NumberRange | nil,
    randomRotation : boolean | nil,
    bury : boolean | nil,
    useNormal : boolean | nil,
    sound : {
        [string] : any
    } | nil,
    decal : {
        faces : { Enum.NormalId },
        [string] : any
    } | nil,
    texture : {
        otherChildren : { string } | nil,
        faces : { Enum.NormalId },
        [string] : any
    } | nil
}

--[=[
    @interface DebugStats
    @within Genesis

    .time { prepare : number, terrain : number, spikes : number, objectPoints : number, objectPrefabs : number, objectGeneration : number, total : number }
    .total { objectProbes : number, spikeProbes : number, spikes : number, objectPoints : number, objectPrefabs : number, objects : number }
]=]
export type DebugStats = {
    time : {
        prepare : number,
        terrain : number,
        spikes : number,
        objectPoints : number,
        objectPrefabs : number,
        objectGeneration : number,
        total : number,
    },
    total : {
        objectProbes : number,
        spikeProbes : number,
        spikes : number,
        objectPoints : number,
        objectPrefabs : number,
        objects : number,
    }
}

--[=[
    @class Genesis
    @server
]=]
--[=[
    @prop UseFlatMaterials boolean
    @within Genesis

    **True** by default, if set to **false** you can apply your own material variants to the terrain.
]=]
local Genesis = {
    _version = "0.0.1",
    _currentMap = nil,
    _creatingMap = false,
    _mapContainer = nil,
    _mountedMaterialVariants = {},
    UseFlatMaterials = true
}

--[=[
    @function CreateMap
    @within Genesis
    @yields

    @param mapConfig : MapConfig
    @param assetContainer : Folder

    @return DebugStats

    :::danger
        Only one map can be can exist at a time, calling this function will destroy the current map if it exists.
    :::

    Creates a new map based on the map config specified, also requires a folder instance that stores the prefabs used for object generation.
]=]
function Genesis:CreateMap(mapConfig : MapConfig, assetContainer : Folder)
    assert(mapConfig, "MapConfig is required to create a map")
    assert(assetContainer, "AssetContainer is required to create a map")
    if self._creatingMap then warn("Genesis:CreateMap() cannot be called while another map is being created") return end
    self._creatingMap = true

    if self._currentMap then self:DestroyMap() end

    -- Prepare flat materials if enabled
    if self.UseFlatMaterials then
        for _, materialVariant in pairs(FLAT_MATERIALS_FOLDER:GetChildren()) do
            materialVariant = materialVariant:Clone()
            materialVariant.Parent = MaterialService
            table.insert(self._mountedMaterialVariants, materialVariant)
        end
    end

    self._mapContainer = Instance.new("Folder")
    self._mapContainer.Name = "GenesisMap"
    self._mapContainer.Parent = workspace

    local currentMap, debugStats : DebugStats = GENERATORS[mapConfig.generatorConfig.generator].new(mapConfig, assetContainer, self._mapContainer)
    self._currentMap = currentMap

    self._creatingMap = false

    return debugStats
end

--[=[
    @function DestroyMap
    @within Genesis
    @yields

    Destroys the current map.
]=]
function Genesis:DestroyMap()
    self._currentMap:Destroy()
    self._mapContainer:Destroy()
    workspace.Terrain:Clear()

    -- Also clear any custom materials if they exist
    for _, materialVariant in ipairs(self._mountedMaterialVariants) do
        materialVariant:Destroy()
    end
    self._mountedMaterialVariants = {}
end

return Genesis