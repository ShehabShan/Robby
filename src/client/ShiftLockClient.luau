--!strict
-- Client shift lock (T-026e, D-164): LeftControl toggles. While on: mouse locked to centre, character turns to
-- the camera yaw every frame, and the `ShiftLock` player attribute tells AimDir to aim where the character faces.
-- The over-shoulder offset is added by MoveFeelClient (it owns Humanoid.CameraOffset).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShiftLock = require(ReplicatedStorage.Shared.ShiftLock)

local ShiftLockClient = {}

function ShiftLockClient.start()
	local player = Players.LocalPlayer
	local locked = false
	local applied = false

	ContextActionService:BindAction("ShiftLock", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			locked = not locked
			player:SetAttribute("ShiftLock", locked)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.LeftControl)

	RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local active = locked and hum ~= nil and hum.Health > 0
		if active and hum and root and root:IsA("BasePart") and camera then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			hum.AutoRotate = false
			local look = camera.CFrame.LookVector
			local yaw = ShiftLock.yaw(look.X, look.Z)
			if yaw then
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
			end
			applied = true
		elseif applied then
			applied = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			if hum then
				hum.AutoRotate = true
			end
		end
	end)
end

return ShiftLockClient
