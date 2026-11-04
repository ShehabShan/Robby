local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local Moves = require("../src/shared/Moves")
local Crescent = require("../src/shared/Content/Crescent")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["content: Crescent validates in the Registry"] = function()
		local _, errors = Registry.build(Crescent.content(Config))
		eq(#errors, 0, `errors: {table.concat(errors, "; ")}`)
	end,

	["content: Crescent mirrors Config (one source of tunables)"] = function()
		local built = Registry.build(Crescent.content(Config))
		local move = built.moves["move.crescent_cut"]
		local c = Config.Abilities.CrescentCut
		eq(move.costs.qi, c.cost)
		eq(move.cooldown, c.cooldown)
		eq(move.delivery.params.speed, c.speed)
		eq(move.delivery.params.range, c.range)
		eq(built.effects["effect.crescent.hit"].ops[1].params.base, c.baseDamage)
	end,

	["content: Crescent casts through Moves"] = function()
		local built = Registry.build(Crescent.content(Config))
		local move = built.moves["move.crescent_cut"]
		local caster: any = { qi = Config.Qi.max, strain = 0, strainMax = 10, hp = 100, cooldowns = {} }
		eq(Moves.pay(caster, move, 0), true)
		eq(caster.qi, Config.Qi.max - Config.Abilities.CrescentCut.cost)
		local ok = Moves.pay(caster, move, 0.1)
		eq(ok, false, "cooldown")
	end,
	["content: Twin Crescent aims up/down with Crescent Cut's pitch range (T-060b)"] = function()
		local Aim = require("../src/shared/Aim")
		local built = Registry.build(Crescent.content(Config))
		local cut = built.moves["move.crescent_cut"].delivery.params
		local twin = built.moves["move.twin_crescent"].delivery.params
		eq(Aim.isFree(twin), true, "twin free aim")
		eq(twin.maxPitch, cut.maxPitch, "same pitch clamp")
		local _, y, _, ok = Aim.clampPitch(1, 1, 0, twin.maxPitch)
		eq(ok and y > 0.5, true, "upward aim kept")
	end,
	["content: every Crucible recipe outputs a known higher-rank Kith (T-019d)"] = function()
		local All = require("../src/shared/Content/All")
		local built, errors = Registry.build(All.content(Config))
		eq(#errors, 0, `errors: {table.concat(errors, "; ")}`)
		for id, r in Config.Crucible.recipes do
			local out = built.kith[r.output]
			eq(out ~= nil, true, `{id} output exists`)
			for _, input in r.inputs do
				eq(out.rank > built.kith[input].rank, true, `{id} output outranks {input}`)
			end
		end
		eq(built.moves["move.twin_crescent"].kith, "kith.twin_crescent", "twin move")
	end,
}
