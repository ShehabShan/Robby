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
}
