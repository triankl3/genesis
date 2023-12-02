local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Iris = require(ReplicatedStorage:WaitForChild("Dependencies"):WaitForChild("iris"))
local CreateMapEvent = ReplicatedStorage:WaitForChild("CreateMap")
local DebugStatsEvent = ReplicatedStorage:WaitForChild("DebugStats")
local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local CAMERA = workspace.CurrentCamera
CAMERA.CameraType = Enum.CameraType.Scriptable
CAMERA.CFrame = CFrame.new(0, 0, 0)
CAMERA.FieldOfView = 90

local cameraSpeed = Iris.State(5)
local cameraSensitivity = Iris.State(0.3)

RunService.RenderStepped:Connect(function()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local delta = UserInputService:GetMouseDelta()
		local cameraCFrame = CAMERA.CFrame
		local yAngle = cameraCFrame:ToEulerAngles(Enum.RotationOrder.YZX)
		local newAmount = math.deg(yAngle) + delta.Y
		if newAmount > 65 or newAmount < -65 then
			if not (yAngle < 0 and delta.Y < 0) and not (yAngle > 0 and delta.Y > 0) then
				delta = Vector2.new(delta.X, 0)
			end
		end
		cameraCFrame *= CFrame.Angles(-math.rad(delta.Y), 0, 0)
		cameraCFrame = CFrame.Angles(0, -math.rad(delta.X), 0) * (cameraCFrame - cameraCFrame.Position) + cameraCFrame.Position
		cameraCFrame = CFrame.lookAt(cameraCFrame.Position, cameraCFrame.Position + cameraCFrame.LookVector)
		if delta ~= Vector2.new(0, 0) then CAMERA.CFrame = CAMERA.CFrame:Lerp(cameraCFrame, cameraSensitivity.value) end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end

	local function move(keycode, vector)
		if not UserInputService:IsKeyDown(keycode) then return end
		CAMERA.CFrame *= CFrame.new(vector)
	end
	move(Enum.KeyCode.W, Vector3.new(0, 0, -cameraSpeed.value))
	move(Enum.KeyCode.A, Vector3.new(-cameraSpeed.value, 0, 0))
	move(Enum.KeyCode.S, Vector3.new(0, 0, cameraSpeed.value))
	move(Enum.KeyCode.D, Vector3.new(cameraSpeed.value, 0, 0))
	move(Enum.KeyCode.LeftControl, Vector3.new(0, -cameraSpeed.value, 0))
	move(Enum.KeyCode.Space, Vector3.new(0, cameraSpeed.value, 0))
end)

local function convertStateTable(stateTable)
	local newTable = {}
	for k, v in pairs(stateTable) do
		newTable[k] = v.value
	end
	return newTable
end

local size = Iris.State(256)
local seedEnabled = Iris.State(true)
local seed = Iris.State(math.random(1, 10e6))
local terrainConfig = {
	minDensity = Iris.State(0.4),
	frequency = Iris.State(10),
	verticalScale = Iris.State(0.5),

	outlineMinDensity = Iris.State(0.5),
	outlineFrequency = Iris.State(80),

	falloffStart = Iris.State(0.25),

	alternativeMaterialChance = Iris.State(10),
	noiseMaterialMinDensity = Iris.State(0.8),
	noiseMaterialFrequency = Iris.State(10),
	objectMaterialMinDensity = Iris.State(0.6),
	objectMaterialFrequency = Iris.State(40),

	objectProbeChance = Iris.State(50),
}
local spikesEnabled = Iris.State(true)
local spikeConfig = {
	chance = Iris.State(8000),
	lengthMin = Iris.State(32),
	lengthMax = Iris.State(256),
	minGap = Iris.State(48),
	width = Iris.State(12),
}
local debugStats = {time = {}, total = {}}
DebugStatsEvent.OnClientEvent:Connect(function(newStats)
	debugStats = newStats
end)

Iris.Init()
Iris:Connect(function()
    Iris.Window({"Genesis Demo", false, false, true, true}, {size = Iris.State(Vector2.new(480, 720)), position = Iris.State(Vector2.new(0, 0))})
		Iris.CollapsingHeader({"Camera"}, {isUncollapsed = Iris.State(true)})
			Iris.Text({"Look: Right Click"})
			Iris.Text({"Move: WASD/Space/CTRL"})
			Iris.SliderNum({"Speed", 0.5, 0.5, 20}, {number = cameraSpeed})
			Iris.SliderNum({"Sensitivity", 0.1, 0.1, 2}, {number = cameraSensitivity})
		Iris.End()

		Iris.CollapsingHeader({"Map Config"}, {isUncollapsed = Iris.State(true)})
			Iris.SliderNum({"Size", 64, 64, 1024}, {number = size})
			Iris.Checkbox({"Use Manual Seed"}, {isChecked = seedEnabled})
			Iris.InputNum({"Manual Seed", 1, 1, 10e6}, {number = seed})
		Iris.End()
		Iris.CollapsingHeader({"Generator Config"})
			Iris.Tree({"Terrain"})
				Iris.SliderNum({"Minimum Density", 0.01, 0, 1}, {number = terrainConfig.minDensity})
				Iris.SliderNum({"Frequency", 1, 1, 1000}, {number = terrainConfig.frequency})
				Iris.SliderNum({"Vertical Scale", 0.1, 0, 1}, {number = terrainConfig.verticalScale})
				Iris.SliderNum({"Outline Minimum Density", 0.01, 0, 1}, {number = terrainConfig.outlineMinDensity})
				Iris.SliderNum({"Outline Frequency", 1, 1, 1000}, {number = terrainConfig.outlineFrequency})
				Iris.SliderNum({"Falloff Start", 0.1, 0, 1}, {number = terrainConfig.falloffStart})
				Iris.SliderNum({"Alternative Material Chance", 1, 0, 1000}, {number = terrainConfig.alternativeMaterialChance})
				Iris.SliderNum({"Noise Material Minimum Density", 0.01, 0, 1}, {number = terrainConfig.noiseMaterialMinDensity})
				Iris.SliderNum({"Noise Material Frequency", 1, 1, 1000}, {number = terrainConfig.noiseMaterialFrequency})
				Iris.SliderNum({"Object Material Minimum Density", 0.01, 0, 1}, {number = terrainConfig.objectMaterialMinDensity})
				Iris.SliderNum({"Object Material Frequency", 1, 1, 1000}, {number = terrainConfig.objectMaterialFrequency})
				Iris.SliderNum({"Object Probe Chance", 1, 0, 1000}, {number = terrainConfig.objectProbeChance})
			Iris.End()
			Iris.Tree({"Spikes"})
				Iris.Checkbox({"Generate spikes"}, {isChecked = spikesEnabled})
				Iris.SliderNum({"Chance", 1, 0, 20000}, {number = spikeConfig.chance})
				Iris.SliderNum({"Length Minimum", 4, 16, 256}, {number = spikeConfig.lengthMin})
				Iris.SliderNum({"Length Maximum", 4, 16, 256}, {number = spikeConfig.lengthMax})
				Iris.SliderNum({"Minimum Gap", 4, 16, 256}, {number = spikeConfig.minGap})
				Iris.SliderNum({"Width", 4, 16, 256}, {number = spikeConfig.width})
			Iris.End()
		Iris.End()
		Iris.CollapsingHeader({"Debug Stats"})
			Iris.Tree({"Time"})
				local function formatTimeStat(x)
					return math.round((x or 0) * 1000) .. "ms"
				end

				Iris.Text({"Prepare: " .. formatTimeStat(debugStats.time.prepare)})
				Iris.Text({"Terrain: " .. formatTimeStat(debugStats.time.terrain)})
				Iris.Text({"Spikes: " .. formatTimeStat(debugStats.time.spikes)})
				Iris.Text({"Object Points: " .. formatTimeStat(debugStats.time.objectPoints)})
				Iris.Text({"Object Prefabs: " .. formatTimeStat(debugStats.time.objectPrefabs)})
				Iris.Text({"Object Generation: " .. formatTimeStat(debugStats.time.objects)})
				Iris.Text({"Total: " .. formatTimeStat(debugStats.time.total)})
			Iris.End()
			Iris.Tree({"Total"})
				Iris.Text({"Object Probes: " .. (debugStats.total.objectProbes or 0)})
				Iris.Text({"Spike Probes: " .. (debugStats.total.spikeProbes or 0)})
				Iris.Text({"Spikes: " .. (debugStats.total.spikes or 0)})
				Iris.Text({"Object Points: " .. (debugStats.total.objectPoints or 0)})
				Iris.Text({"Object Prefabs: " .. (debugStats.total.objectPrefabs or 0)})
				Iris.Text({"Objects: " .. (debugStats.total.objects or 0)})
			Iris.End()
		Iris.End()

		if Iris.Button({"Create Map"}).clicked() then
			CreateMapEvent:FireServer(
				size.value,
				seed.value,
				convertStateTable(terrainConfig),
				spikesEnabled.value and convertStateTable(spikeConfig) or nil
			)
		end
    Iris.End()
end)