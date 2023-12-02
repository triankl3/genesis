--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Genesis = require(ServerScriptService:WaitForChild("Genesis"))
local ASSET_CONTAINER = ReplicatedStorage:WaitForChild("Assets")
local STATIC_CONFIG = require(script:WaitForChild("staticConfig"))

local CreateMapEvent = Instance.new("RemoteEvent")
CreateMapEvent.Name = "CreateMap"
CreateMapEvent.Parent = ReplicatedStorage
local DebugStatsEvent = Instance.new("RemoteEvent")
DebugStatsEvent.Name = "DebugStats"
DebugStatsEvent.Parent = ReplicatedStorage

-- Create lighting effects and settings
Lighting.Ambient = Color3.fromRGB(32, 32, 32)
Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.Brightness = 0
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.GlobalShadows = false
Lighting.GeographicLatitude = 0
Lighting.ExposureCompensation = 0
Lighting.ClockTime = 0
local sky = Instance.new("Sky")
sky.SkyboxBk = "rbxassetid://7658670519"
sky.SkyboxDn = "rbxassetid://7658670519"
sky.SkyboxFt = "rbxassetid://7658670519"
sky.SkyboxLf = "rbxassetid://7658670519"
sky.SkyboxRt = "rbxassetid://7658670519"
sky.SkyboxUp = "rbxassetid://7658670519"
sky.CelestialBodiesShown = false
sky.StarCount = 0
sky.MoonAngularSize = 0
sky.SunAngularSize = 0
sky.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 1
bloom.Size = 26
bloom.Threshold = 1.9
bloom.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.4
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(0, 89, 191)
atmosphere.Decay = Color3.fromRGB(255, 255, 255)
atmosphere.Glare = 0
atmosphere.Haze = 10
atmosphere.Parent = Lighting

CreateMapEvent.OnServerEvent:Connect(function(player, size, seed, terrainConfig, spikeConfig)
    local debugStats = Genesis:CreateMap({
        generatorConfig = {
            generator = "Perlin3D",
            terrain = terrainConfig,
            material = STATIC_CONFIG.material,
            spikes = spikeConfig,
            prefabs = STATIC_CONFIG.prefabs,
            objects = STATIC_CONFIG.objects
        },
        ["size"] = size,
        ["seed"] = seed
    }, ASSET_CONTAINER)
    DebugStatsEvent:FireClient(player, debugStats)
end)