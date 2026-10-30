--!strict
-- Client entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md): input, effects, Qi readout.
-- FX are played by id through the FX registry (T-002c4); CastFx/HitFx carry the fx id first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Crescent = require(ReplicatedStorage.Shared.Content.Crescent)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Registry = require(ReplicatedStorage.Shared.Registry)
local AbilityInput = require(script.AbilityInput)
local CrescentFx = require(script.CrescentFx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest") :: RemoteEvent
local castFx = remotes:WaitForChild("CastFx") :: RemoteEvent
local hitFx = remotes:WaitForChild("HitFx") :: RemoteEvent

local built: any = Registry.build(Crescent.content(Config))
local fx = FxRegistry.new()
CrescentFx.register(fx)
for _, id in FxRegistry.missingFor(fx, built) do
	warn("No FX handler for " .. id)
end

AbilityInput.start(castRequest, fx, built.moves["move.crescent_cut"])

castFx.OnClientEvent:Connect(function(fxId: unknown, caster: Player, pos: Vector3, dir: Vector3)
	if caster == player then
		return -- the caster already played it locally
	end
	FxRegistry.play(fx, fxId, { caster = caster, character = caster.Character, pos = pos, dir = dir })
end)

hitFx.OnClientEvent:Connect(
	function(fxId: unknown, caster: Player, pos: Vector3, dir: Vector3, target: Model?, amount: number)
		FxRegistry.play(fx, fxId, { caster = caster, pos = pos, dir = dir, target = target, amount = amount })
	end
)

local gui = Instance.new("ScreenGui")
gui.Name = "QiHud"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -90)
label.Size = UDim2.fromOffset(180, 28)
label.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
label.BackgroundTransparency = 0.4
label.TextColor3 = Color3.fromRGB(150, 205, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.Parent = gui

local function refresh()
	label.Text = string.format(
		"Qi %s / %s",
		tostring(player:GetAttribute("Qi") or "-"),
		tostring(player:GetAttribute("QiMax") or "-")
	)
end
player:GetAttributeChangedSignal("Qi"):Connect(refresh)
player:GetAttributeChangedSignal("QiMax"):Connect(refresh)
refresh()
gui.Parent = player:WaitForChild("PlayerGui")
