local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local Moves = require("../src/shared/Moves")
local Loom = require("../src/shared/Loom")
local Frost = require("../src/shared/Frost")
local Volley = require("../src/shared/Deliveries/Volley")
local Zone = require("../src/shared/Deliveries/Zone")
local Burst = require("../src/shared/Deliveries/Burst")
local Rimeshard = require("../src/shared/Content/Rimeshard")
local All = require("../src/shared/Content/All")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local R = Config.Abilities.Rimeshard

return {
	["rimeshard: content validates in the Registry, alone and merged (T-027c)"] = function()
		local _, errors = Registry.build(Rimeshard.content(Config))
		eq(#errors, 0, `errors: {table.concat(errors, "; ")}`)
		local built, allErrors = Registry.build(All.content(Config))
		eq(#allErrors, 0, `all errors: {table.concat(allErrors, "; ")}`)
		eq(built.kith["kith.rimeshard"].rank, 1, "rank 1 Kith")
		eq(#built.kith["kith.rimeshard"].moves, 5, "R1 + finisher + Z/X/C")
	end,

	["rimeshard: moves mirror Config (one source of tunables)"] = function()
		local built = Registry.build(Rimeshard.content(Config))
		local fan = built.moves["move.rime.shard_fan"]
		eq(fan.costs.qi, R.shardFan.cost)
		eq(fan.cooldown, R.shardFan.cooldown)
		eq(fan.delivery.params.count, R.shardFan.count)
		eq(fan.delivery.params.perTargetCap, R.shardFan.perTargetCap)
		local fall = built.moves["move.rime.fall"]
		eq(fall.delivery.params.ticks, R.rimeFall.ticks)
		eq(fall.telegraph, R.rimeFall.delay)
		eq(built.effects["effect.rime.fall.tick"].ops[1].params.base, R.rimeFall.damagePerTick)
		local shatter = built.moves["move.rime.shatter"]
		eq(shatter.delivery.params.radius, R.shatter.radius)
		eq(built.effects["effect.rime.shatter"].ops[1].params.perStack, R.shatter.perStack)
		eq(built.effects["effect.rime.needle.hit"].ops[1].params.base, R.needle.damage)
		eq(built.moves["move.rime.needle"].costs.qi, 0, "Needle shots 1–2 are free")
		eq(built.moves["move.rime.needle_finisher"].costs.qi, R.needle.finisher.cost)
	end,

	["rimeshard: every hitting move applies Chill; Chill effect matches Frost"] = function()
		local built = Registry.build(Rimeshard.content(Config))
		for _, id in { "move.rime.needle", "move.rime.needle_finisher", "move.rime.shard_fan", "move.rime.fall" } do
			local found = false
			for _, e in built.moves[id].effects.onHit do
				found = found or e == Frost.CHILL_ID
			end
			eq(found, true, `{id} applies Chill`)
		end
		local chill = built.effects[Frost.CHILL_ID]
		eq(chill.stack.cap, R.chill.maxStacks)
		eq(chill.seconds, R.chill.seconds)
		eq(chill.modifiers[1].value, -R.chill.slowPerStack)
		-- Shatter only hits Chilled targets and reads/consumes their stacks.
		local shatter = built.effects["effect.rime.shatter"]
		eq(shatter.requireTags[1], Frost.CHILLED_TAG)
		eq(shatter.ops[1].params.status, Frost.CHILL_ID)
		eq(shatter.ops[1].params.consume, true)
	end,

	["rimeshard: delivery params satisfy the T-027b delivery validators"] = function()
		local built = Registry.build(Rimeshard.content(Config))
		eq(Volley.validParams(built.moves["move.rime.shard_fan"].delivery.params), true, "fan")
		eq(Volley.validParams(built.moves["move.rime.needle_finisher"].delivery.params), true, "finisher")
		eq(Zone.validParams(built.moves["move.rime.fall"].delivery.params), true, "fall")
		eq(Burst.validParams(built.moves["move.rime.shatter"].delivery.params), true, "shatter")
		-- Rime Fall telegraph honours the enemy-readability floor (note §2 X: ≥ 0.4 s).
		eq(R.rimeFall.delay >= 0.4, true, "telegraph >= 0.4 s")
	end,

	["rimeshard: Loom Piercing fits Needle and Shard Fan, not Fall or Shatter (T-027c AC)"] = function()
		local built = Registry.build(All.content(Config))
		local pierce = built.supports["support.piercing"]
		eq(Loom.fits(built.moves["move.rime.needle"], pierce), true, "needle")
		eq(Loom.fits(built.moves["move.rime.shard_fan"], pierce), true, "fan")
		eq(Loom.fits(built.moves["move.rime.fall"], pierce), false, "fall")
		eq(Loom.fits(built.moves["move.rime.shatter"], pierce), false, "shatter")
		local woven = Loom.weave(built.moves["move.rime.shard_fan"], { pierce }, "weave.test")
		eq(woven.delivery.params.maxHits, R.shardFan.maxHits * Config.Loom.supports.Piercing.maxHitsMult, "pierce")
	end,

	["rimeshard: specials pay Qi and respect cooldown through Moves"] = function()
		local built = Registry.build(Rimeshard.content(Config))
		local move = built.moves["move.rime.shatter"]
		local caster: any = { qi = Config.Qi.max, strain = 0, strainMax = 10, hp = 100, cooldowns = {} }
		eq(Moves.pay(caster, move, 0), true)
		eq(caster.qi, Config.Qi.max - R.shatter.cost)
		eq(Moves.pay(caster, move, 0.1), false, "cooldown")
		-- Full loop from note §2: Z + R1 + C = 28 Qi, within one full pool.
		eq(R.shardFan.cost + R.needle.finisher.cost + R.shatter.cost <= Config.Qi.max, true, "loop fits Qi pool")
	end,

	["rimeshard: Frost is an opposed Path to Flame in the Loom (D-181)"] = function()
		eq(Config.Loom.paths["path.frost"].frictionWith["path.flame"], -0.2)
		eq(Config.Loom.paths["path.flame"].frictionWith["path.frost"], -0.2)
	end,
}
