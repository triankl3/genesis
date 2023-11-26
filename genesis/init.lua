-- Validate server environment
if game:GetService("RunService"):IsServer() == false then
    error("Genesis must run on the server!")
end

-- Requires
local generators = {}
for _, child in ipairs(script:WaitForChild("generators"):GetChildren()) do
    if not child:IsA("ModuleScript") then continue end
    generators[child.Name] = require(child)
end

-- Types
--[=[
    @interface PrefabConfig
    @within Genesis

    .prefabName string
    .clone string
    .asset string

    .rbxProperties { string : { string : any } }

    .proximity { extraRadius : number, bannedRadius : number, bannedList : { string } }

    .scale NumberRange
    .randomRotation boolean | nil
    .bury boolean | nil
    .useNormal boolean | nil
    .sound { string : any }
    .decal { faces : { Enum.NormalId }, string : any }
    .stretch NumberRange
    .texture { otherChildren : { string }, faces : { Enum.NormalId }, string : any }
]=]
export type PrefabConfig = {
    prefabName : string,
    clone : string,
    asset : string,

    rbxProperties : {
        [string] : {
            [string] : any
        }
    },

    proximity : {
        extraRadius : number,
        bannedRadius : number,
        bannedList : { string }
    },

    scale : NumberRange,
    randomRotation : boolean | nil,
    bury : boolean | nil,
    useNormal : boolean | nil,
    sound : {
        [string] : any
    },
    decal : {
        faces : { Enum.NormalId },
        [string] : any
    },
    stretch : NumberRange,
    texture : {
        otherChildren : { string },
        faces : { Enum.NormalId },
        [string] : any
    }
}

--[=[
    @interface Perlin3DConfig
    @within Genesis

    .generator "Perlin3D"
    .terrain TerrainConfig
    .material MaterialConfig
    .object ObjectConfig
]=]
--[=[
    @interface TerrainConfig
    @within Genesis

    .minDensity number
    .frequency number
    .verticalScale number

    .outlineMinDensity number
    .outlineFrequency number

    .falloffStart number

    .alternativeMaterialChance number
    .noiseMaterialMinDensity number
    .noiseMaterialFrequency number
    .objectMaterialMinDensity number
    .objectMaterialFrequency number

    .generateSpikes boolean | nil
    .spikeChance number
    .spikeLengthMin number
    .spikeLengthMax number
    .spikeMinGap number
    .spikeWidth number
]=]
--[=[
    @interface MaterialConfig
    @within Genesis

    .primaryMaterial Enum.Material
    .alternativeMaterial Enum.Material
    .noiseMaterial Enum.Material
    .objectMaterial Enum.Material

    .primaryMaterialColor Color3
    .alternativeMaterialColor Color3
    .noiseMaterialColor Color3
    .objectMaterialColor Color3
]=]
--[=[
    @interface ObjectConfig
    @within Genesis

    .probeChance number
    .prefabs { string : PrefabConfig }
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

        generateSpikes : boolean | nil,
        spikeChance : number,
        spikeLengthMin : number,
        spikeLengthMax : number,
        spikeMinGap : number,
        spikeWidth : number
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
    object : {
        probeChance : number,
        prefabs : {
            [string] : PrefabConfig
        }
    }
}

--[=[
    @interface MapConfig
    @within Genesis

    .generatorConfig : Perlin3DConfig
    .size : number
    .seed : number | nil
    .debugObjectProbes : boolean | nil
]=]
export type MapConfig = {
    generatorConfig : Perlin3DConfig,
    size : number,
    seed : number | nil,
    debugObjectProbes : boolean | nil,
}

--[=[
    @class Genesis
    @server
]=]
-- Properties
local Genesis = {
    _version = "0.0.1",
    _currentMap = nil,
    _mapContainer = nil,
    PrintDebug = false
}

-- Functions
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

    if self._currentMap then self:DestroyMap() end

    self._mapContainer = Instance.new("Folder")
    self._mapContainer.Name = "GenesisMap"
    self._mapContainer.Parent = workspace

    self._currentMap = generators[mapConfig.generatorConfig.generator].new(mapConfig, assetContainer, self._mapContainer)
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
end

return Genesis