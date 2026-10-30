--!strict
-- Client sprint (T-026b3a, D-163): hold LeftShift / gamepad L3 to run (D-164). Q is Dash, LeftControl is shift lock, C is Crucible.
-- Ramps the local Humanoid.WalkSpeed via pure `Shared.Sprint`. Server speed guard is T-026b3b.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sprint = require(ReplicatedStorage.Shared.Sprint)

local tune: Sprint.Tuning = Config.Movement
local SprintClient = {}
local held = false

function SprintClient.start()
	ContextActionService:BindAction("Sprint", function(_, state: Enum.UserInputState, _)
		held = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	RunService.Heartbeat:Connect(function(dt: number)
		local character = Players.LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		local moving = hum.MoveDirection.Magnitude > 0.1
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local target = Sprint.target(tune, held, moving, grounded)
		hum.WalkSpeed = Sprint.step(hum.WalkSpeed, target, tune.accel, dt)
	end)
end

return SprintClient
