--!strict
-- Client entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md): input, effects, Qi readout.
-- FX are played by id through the FX registry (T-002c4); remotes are Blink-generated (T-011).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local All = require(ReplicatedStorage.Shared.Content.All)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local HitFeel = require(script.HitFeel)
local Registry = require(ReplicatedStorage.Shared.Registry)
local AbilityInput = require(script.AbilityInput)
local CrescentFx = require(script.CrescentFx)
local KithFx = require(script.KithFx)
local CombatInput = require(script.CombatInput)
local Hud = require(script.Hud)
local Net = require(script.Net) -- Blink-generated (net/remotes.blink)

local player = Players.LocalPlayer
local built: any = Registry.build(All.content(Config))
local fx = FxRegistry.new()
CrescentFx.register(fx)
HitFeel.register(fx)
KithFx.register(fx)
for _, id in FxRegistry.missingFor(fx, built) do
	warn("No FX handler for " .. id)
end

local function cast(moveId: string, aim: Vector3, seq: number)
	Net.CastRequest.Fire({ moveId = moveId, aim = aim, seq = seq })
end
-- Provisional keys (D-062): E/X Crescent Cut, Q/Y Stone Ward, R/L2 Wind Step.
AbilityInput.start(cast, fx, built.moves["move.crescent_cut"], {
	name = "CrescentCut",
	title = "Cut",
	keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonX },
})
AbilityInput.start(cast, fx, built.moves["move.stone_ward"], {
	name = "StoneWard",
	title = "Ward",
	keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY },
})
AbilityInput.start(cast, fx, built.moves["move.wind_step"], {
	name = "WindStep",
	title = "Step",
	keys = { Enum.KeyCode.R, Enum.KeyCode.ButtonL2 },
})

CombatInput.start(function(kind: string, dir: Vector3?, seq: number)
	Net.Action.Fire({ kind = kind :: any, dir = dir, seq = seq })
end)

Net.CastFx.On(function(v)
	if v.caster == player then
		return -- the caster already played it locally
	end
	FxRegistry.play(fx, v.fxId, { caster = v.caster, character = v.caster.Character, pos = v.pos, dir = v.dir })
end)

Net.HitFx.On(function(v)
	FxRegistry.play(fx, v.fxId, { caster = v.caster, pos = v.pos, dir = v.dir, target = v.target, amount = v.amount })
end)

Hud.start(built) -- HP/Qi bars, slot bar, gap warning (T-016c, D-068)
