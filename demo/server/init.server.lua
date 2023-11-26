--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Genesis = require(ServerScriptService:WaitForChild("Genesis"))

local assetContainer = Instance.new("Folder")
assetContainer.Name = "GenesisAssets"
assetContainer.Parent = workspace

Genesis:CreateMap(
    {
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

                generateSpikes = true,
                spikeChance = 3500,
                spikeLengthMin = 32,
                spikeLengthMax = 128,
                spikeMinGap = 48,
                spikeWidth = 8,
            },
            material = {
                primaryMaterial = Enum.Material.Rock,
                alternativeMaterial = Enum.Material.Slate,
                noiseMaterial = Enum.Material.Ice,
                objectMaterial = Enum.Material.Grass,

                primaryMaterialColor = Color3.fromRGB(50, 77, 85),
                secondaryMaterialColor = Color3.fromRGB(98, 206, 254),
                noiseMaterialColor = Color3.fromRGB(229, 253, 248),
                objectMaterialColor = Color3.fromRGB(101, 198, 33),
            },
            object = {
                probeChance = 4
            }
        },
        size = 256,
        seed = 222,
    },
    assetContainer
)