--!strict
-- Combat input (T-013b, GDD §5 controls): light chain (LMB / RT), dash (Q / B, D-165), parry+guard
-- (F / LB: press parries and raises the guard, release lowers it). Sends intent only; the server decides.
-- The dash moves the local character (it owns its physics); the server only grants the i-frames.

local ContextActionService = game:GetService("ContextActionService")
local AimDir = require(script.Parent.AimDir)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)

export type Send = (kind: string, dir: Vector3?, seq: number) -> ()

local C = Config.Combat

local CombatInput = {}

function CombatInput.start(send: Send)
	local player = Players.LocalPlayer
	local seq = 0
	local dash = Combat.newDash()

	local function nextSeq(): number
		seq = (seq + 1) % 65536
		return seq
	end

	local function aim(): Vector3?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local look = AimDir.look(camera)
		local flat = Vector3.new(look.X, 0, look.Z)
		return if flat.Magnitude > 0.01 then flat.Unit else nil
	end

	ContextActionService:BindAction("CombatAttack", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		send("Attack", aim(), nextSeq())
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("CombatDash", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
			return Enum.ContextActionResult.Pass
		end
		if not Combat.dash(dash, os.clock(), C.dash) then
			return Enum.ContextActionResult.Sink
		end
		local move = humanoid.MoveDirection
		local dir = if move.Magnitude > 0.1 then move.Unit else (aim() or root.CFrame.LookVector)
		root.AssemblyLinearVelocity = dir * C.dash.speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		send("Dash", dir, nextSeq())
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	ContextActionService:BindAction("CombatParry", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			send("Parry", nil, nextSeq())
			return Enum.ContextActionResult.Sink
		elseif state == Enum.UserInputState.End then
			send("Guard", nil, nextSeq())
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
end

return CombatInput
