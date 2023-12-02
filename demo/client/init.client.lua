local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Iris = require(ReplicatedStorage:WaitForChild("Dependencies"):WaitForChild("iris"))

if not game:IsLoaded() then game.Loaded:Wait() end

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

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(0, 0, -cameraSpeed.value))
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(-cameraSpeed.value, 0, 0))
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(0, 0, cameraSpeed.value))
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(cameraSpeed.value, 0, 0))
	end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(0, -cameraSpeed.value, 0))
	end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		CAMERA.CFrame *= CFrame.new(Vector3.new(0, cameraSpeed.value, 0))
	end
end)

Iris.Init()
Iris:Connect(function()
    Iris.Window({"Genesis Demo"}, {size = Iris.State(Vector2.new(480, 720)), position = Iris.State(Vector2.new(0, 0))})
		Iris.CollapsingHeader({"Camera"}, {isUncollapsed = Iris.State(true)})
			Iris.Text({"Look: Right click"})
			Iris.Text({"Move: WASD/Space/CTRL"})
			Iris.SliderNum({"Speed", 0.5, 0.5, 20}, {number = cameraSpeed})
			Iris.SliderNum({"Sensitivity", 0.1, 0.1, 2}, {number = cameraSensitivity})
		Iris.End()
    Iris.End()
end)