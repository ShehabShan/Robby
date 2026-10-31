--!strict
-- Crescent Cut input (.ai/SPIKE.md §1): PC E / left-click, gamepad ButtonX, and an on-screen mobile button.
-- Plays the Move's cast/travel FX locally at once through the FX registry, then sends CastRequest
-- (moveId, aim, seq; SCHEMAS §9). The server decides everything that matters.

local ContextActionService = game:GetService("ContextActionService")
local AimDir = require(script.Parent.AimDir)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)

-- Wind Step covers its distance in this burst (the client owns its character physics).
local BURST_SECONDS = Config.Abilities.WindStep.burstSeconds
local CHEST = Vector3.new(0, 0.5, 0)

local AbilityInput = {}

export type Binding = { name: string, title: string, keys: { Enum.KeyCode } }

function AbilityInput.start(
	send: (moveId: string, aim: Vector3, point: Vector3?) -> (),
	fx: FxRegistry.Registry,
	move: any,
	binding: Binding
)
	local player = Players.LocalPlayer
	local lastCast: number? = nil

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
		local look = AimDir.look(camera)
		local x, z, ok = Projectile.flatten(look.X, look.Z)
		if not ok then
			return Enum.ContextActionResult.Sink
		end
		lastCast = now
		local dir = Vector3.new(x, 0, z)
		local ctx = {
			caster = player,
			character = character,
			pos = root.Position + dir * (move.delivery.params.spawnOffset or 0) + CHEST,
			dir = dir,
		}
		FxRegistry.play(fx, move.fx.cast, ctx)
		if move.fx.travel then
			FxRegistry.play(fx, move.fx.travel, ctx)
		end
		local distance = move.delivery.params.distance
		if typeof(distance) == "number" then
			root.AssemblyLinearVelocity = dir * (distance / BURST_SECONDS)
				+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		send(move.id, dir, nil)
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindAction(binding.name, onAction, true, table.unpack(binding.keys))
	ContextActionService:SetTitle(binding.name, binding.title)
end

return AbilityInput
