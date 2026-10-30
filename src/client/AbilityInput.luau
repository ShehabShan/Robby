--!strict
-- Crescent Cut input (.ai/SPIKE.md §1): PC E / left-click, gamepad ButtonX, and an on-screen mobile button.
-- Plays the cast locally at once, then asks the server, which decides everything that matters.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)
local CrescentFx = require(script.Parent.CrescentFx)

local cfg = Config.Abilities.CrescentCut
local ACTION = "CrescentCut"
local CHEST = Vector3.new(0, 0.5, 0)

local AbilityInput = {}

function AbilityInput.start(castRequest: RemoteEvent)
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
		if lastCast and now - lastCast < cfg.cooldown then
			return Enum.ContextActionResult.Sink
		end
		local qi = player:GetAttribute("Qi")
		if typeof(qi) == "number" and qi < cfg.cost then
			return Enum.ContextActionResult.Sink
		end
		local look = camera.CFrame.LookVector
		local x, z, ok = Projectile.flatten(look.X, look.Z)
		if not ok then
			return Enum.ContextActionResult.Sink
		end
		lastCast = now
		local dir = Vector3.new(x, 0, z)
		CrescentFx.swipe(character)
		CrescentFx.crescent(root.Position + dir * cfg.spawnOffset + CHEST, dir)
		castRequest:FireServer(dir)
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
