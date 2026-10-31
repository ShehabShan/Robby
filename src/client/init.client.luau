--!strict
-- Client entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md): input, effects, Qi readout.
-- FX are played by id through the FX registry (T-002c4); remotes are Blink-generated (T-011).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CastRequest = require(ReplicatedStorage.Shared.CastRequest)
local All = require(ReplicatedStorage.Shared.Content.All)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local HitFeel = require(script.HitFeel)
local Registry = require(ReplicatedStorage.Shared.Registry)
local AbilityInput = require(script.AbilityInput)
local CrescentFx = require(script.CrescentFx)
local KithFx = require(script.KithFx)
local RimeFx = require(script.RimeFx)
local MoveFeelClient = require(script.MoveFeelClient)
local MoveAnimClient = require(script.MoveAnimClient)
local FootstepClient = require(script.FootstepClient)
local SprintClient = require(script.SprintClient)
local ShiftLockClient = require(script.ShiftLockClient)
local CombatInput = require(script.CombatInput)
local KithInput = require(script.KithInput)
local Hud = require(script.Hud)
local BindingHud = require(script.BindingHud)
local ShellHud = require(script.ShellHud)
local CrucibleHud = require(script.CrucibleHud)
local LoomHud = require(script.LoomHud)
local LoadoutUi = require(script.LoadoutScreen)
local Net = require(script.Net) -- Blink-generated (net/remotes.blink)

local player = Players.LocalPlayer
local built: any = Registry.build(All.content(Config))
local fx = FxRegistry.new()
CrescentFx.register(fx)
HitFeel.register(fx)
KithFx.register(fx)
RimeFx.register(fx) -- Rimeshard visuals (T-027e, D-197)
require(script.BeastFx).register(fx) -- beast telegraph ring + sound (T-022c)
for _, id in FxRegistry.missingFor(fx, built) do
	warn("No FX handler for " .. id)
end

local nextCastSeq = CastRequest.allocator()
local function cast(moveId: string, aim: Vector3, point: Vector3?)
	Net.CastRequest.Fire({ moveId = moveId, aim = aim, point = point, seq = nextCastSeq() })
end
-- Wind Step stays on R/L2 (owner, D-217). Crescent Cut left E: it is a slot move now (KithInput, T-036a, D-216).
AbilityInput.start(cast, fx, built.moves["move.wind_step"], {
	name = "WindStep",
	title = "Step",
	keys = { Enum.KeyCode.R, Enum.KeyCode.ButtonL2 },
})

local function action(kind: string, dir: Vector3?, seq: number)
	Net.Action.Fire({ kind = kind :: any, dir = dir, seq = seq })
end
CombatInput.start(action)
-- Slot-selected abilities (T-036a, D-216): keys 1–7 select a core slot; the selected Kith's chain takes left click,
-- Z / X / C are its specials (or its moves, for a Kith without a chain). `ActiveKith` comes from the loadout.
KithInput.start(cast, function(slot: number)
	Hud.select(slot) -- predicted highlight before the server round trip (T-038c, D-223)
	Net.SelectSlot.Fire({ slot = slot })
end, fx, built)

Net.CastFx.On(function(v)
	if v.caster == player then
		return -- the caster already played it locally
	end
	FxRegistry.play(fx, v.fxId, { caster = v.caster, character = v.caster.Character, pos = v.pos, dir = v.dir })
end)

Net.HitFx.On(function(v)
	FxRegistry.play(fx, v.fxId, { caster = v.caster, pos = v.pos, dir = v.dir, target = v.target, amount = v.amount })
end)

Hud.start(
	built,
	function(slot: number) -- HP/Qi bars, slot bar, gap warning (T-016c, D-068); tap a slot = select it (T-036b)
		Net.SelectSlot.Fire({ slot = slot })
	end
)
LoadoutUi.start(built, Net) -- equip/unequip screen (T-016d, D-069)
MoveFeelClient.start() -- body lean, camera bob, landing dip (T-026b1, D-161)
MoveAnimClient.start() -- kit idle/walk/run/jump/land animations (T-026c)
FootstepClient.start() -- surface footsteps (T-026b2, D-162)
SprintClient.start() -- hold LeftShift / L3 to run (T-026b3a, D-164)
ShiftLockClient.start() -- LeftControl toggles shift lock (T-026e, D-164)
BindingHud.start(built, Net) -- Binding tug-of-war UI (T-017c, D-072)
ShellHud.start(Net) -- Core Shell + Refine (T-018d, D-076)
CrucibleHud.start(Net) -- Crucible confirm / focus / result (T-019e, D-085)
LoomHud.start(Net) -- Weave Loom panel (T-020e, D-111)

require(script.BeastHud).start(fx) -- beast labels + telegraph "!" and ground warning (T-022c)
require(script.BossHud).start() -- boss HP bar + phase cue (T-023c)
