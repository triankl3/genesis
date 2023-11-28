--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Genesis = require(ServerScriptService:WaitForChild("Genesis"))
local ASSET_CONTAINER = ReplicatedStorage:WaitForChild("Assets")
local PREFABS_CONFIG = require(script:WaitForChild("prefabsConfig"))

local debugStats = Genesis:CreateMap({
    generatorConfig = {
        generator = "Perlin3D",
        terrain = {
            minDensity = 0.4,
            frequency = 10,
            verticalScale = 0.5,

            outlineMinDensity = 0.5,
            outlineFrequency = 80,

            falloffStart = 0.25,

            alternativeMaterialChance = 10,
            noiseMaterialMinDensity = 0.8,
            noiseMaterialFrequency = 10,
            objectMaterialMinDensity = 0.6,
            objectMaterialFrequency = 40,

            objectProbeChance = 50,
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
            chance = 8000,
            lengthMin = 32,
            lengthMax = 256,
            minGap = 48,
            width = 12,
        },
        prefabs = PREFABS_CONFIG,
        objects = {
            primaryMaterial = {
                ceiling = {
                    Biolumen = 100
                },
                wall = {
                    Crystal1 = 10,
                    Crystal2 = 10,
                    Biolumen = 80
                },
                floor = {
                    Rock1Primary = 10,
                    Rock2Primary = 10,
                    Rock3Primary = 10,
                    Rock4Primary = 10,
                    Rock5Primary = 10,
                    Crystal1 = 25,
                    Crystal2 = 25
                }
            },
            alternativeMaterial = {
                ceiling = {
                    Biolumen = 100
                },
                wall = {
                    Crystal1 = 10,
                    Crystal2 = 10,
                    Biolumen = 80
                },
                floor = {
                    Rock1Secondary = 10,
                    Rock2Secondary = 10,
                    Rock3Secondary = 10,
                    Rock4Secondary = 10,
                    Rock5Secondary = 10,
                    Crystal1 = 25,
                    Crystal2 = 25
                }
            },
            objectMaterial = {
                ceiling = {
                    Vine = 100
                },
                wall = {
                    Rock1Plant = 1,
                    Rock2Plant = 1,
                    Rock3Plant = 1,
                    Rock4Plant = 1,
                    Rock5Plant = 1,
                    Weird2 = 45,
                    Weird3 = 50
                },
                floor = {
                    Mushroom1 = 40,
                    Flowers1 = 50,
                    Bush1 = 5,
                    Bush2 = 5
                }
            }
        }
    },
    size = 512,
    seed = 222,
}, ASSET_CONTAINER)

print(debugStats)