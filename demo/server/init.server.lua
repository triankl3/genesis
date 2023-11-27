--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Genesis = require(ServerScriptService:WaitForChild("Genesis"))
local ASSET_CONTAINER = ReplicatedStorage:WaitForChild("Assets")

local debugStats = Genesis:CreateMap({
    generatorConfig = {
        generator = "Perlin3D",
        terrain = {
            minDensity = 0.4,
            frequency = 10,
            verticalScale = 0.5,

            outlineMinDensity = 0.6,
            outlineFrequency = 100,

            falloffStart = 128,

            alternativeMaterialChance = 20,
            noiseMaterialMinDensity = 0.6,
            noiseMaterialFrequency = 8,
            objectMaterialMinDensity = 0.7,
            objectMaterialFrequency = 100,

            objectProbeChance = 4,
        },
        material = {
            primaryMaterial = Enum.Material.Rock,
            alternativeMaterial = Enum.Material.Slate,
            noiseMaterial = Enum.Material.Ice,
            objectMaterial = Enum.Material.Grass,

            primaryMaterialColor = Color3.fromRGB(50, 77, 85),
            alternativeMaterialColor = Color3.fromRGB(98, 206, 254),
            noiseMaterialColor = Color3.fromRGB(229, 253, 248),
            objectMaterialColor = Color3.fromRGB(101, 198, 33),
        },
        spikes = {
            chance = 3500,
            lengthMin = 32,
            lengthMax = 128,
            minGap = 48,
            width = 8,
        },
    },
    size = 256,
    seed = 222,
}, ASSET_CONTAINER)

print(debugStats)