--!strict
-- Crescent Cut input (.ai/SPIKE.md §1): PC E / left-click, gamepad ButtonX, and an on-screen mobile button.
-- Plays the Move's cast/travel FX locally at once through the FX registry, then sends CastRequest
-- (moveId, aim, seq; SCHEMAS §9). The server decides everything that matters.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CastRequest = require(ReplicatedStorage.Shared.CastRequest)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)

local ACTION = "CrescentCut"
local CHEST = Vector3.new(0, 0.5, 0)

local AbilityInput = {}

function AbilityInput.start(castRequest: RemoteEvent, fx: FxRegistry.Registry, move: any)
	local player = Players.LocalPlayer
	local lastCast: number? = nil
	local seq = 0

	local function onAction(
		_actionName: string,
		state: Enum.UserInputState,
		_input: InputObject
	): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local character = player.Character
		local camera = workspace.CurrentCamera
		if not character or not camera then
			return Enum.ContextActionResult.Pass
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return Enum.ContextActionResult.Pass
		end
		local now = os.clock()
		if lastCast and now - lastCast < move.cooldown then
			return Enum.ContextActionResult.Sink
		end
		local qi = player:GetAttribute("Qi")
		if typeof(qi) == "number" and qi < (move.costs.qi or 0) then
			return Enum.ContextActionResult.Sink
		end
		local look = camera.CFrame.LookVector
		local x, z, ok = Projectile.flatten(look.X, look.Z)
		if not ok then
			return Enum.ContextActionResult.Sink
		end
		lastCast = now
		seq = CastRequest.nextSeq(seq)
		local dir = Vector3.new(x, 0, z)
		local ctx = {
			caster = player,
			character = character,
			pos = root.Position + dir * move.delivery.params.spawnOffset + CHEST,
			dir = dir,
		}
		FxRegistry.play(fx, move.fx.cast, ctx)
		FxRegistry.play(fx, move.fx.travel, ctx)
		castRequest:FireServer(move.id, dir, seq)
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction(
		ACTION,
		onAction,
		true,
		Enum.KeyCode.E,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:SetTitle(ACTION, "Cut")
end

return AbilityInput
