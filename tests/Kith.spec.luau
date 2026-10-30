local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local Moves = require("../src/shared/Moves")
local All = require("../src/shared/Content/All")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["kith: all M1 Kith validate together"] = function()
		local built, errors = Registry.build(All.content(Config))
		eq(#errors, 0, `errors: {table.concat(errors, "; ")}`)
		for _, id in { "kith.crescent", "kith.stone", "kith.wind" } do
			eq(built.kith[id] ~= nil, true, id)
		end
	end,
	["kith: Stone Ward and Wind Step mirror Config"] = function()
		local built = Registry.build(All.content(Config))
		local ward, step = built.moves["move.stone_ward"], built.moves["move.wind_step"]
		local s, w = Config.Abilities.StoneWard, Config.Abilities.WindStep
		eq(ward.costs.qi, s.cost)
		eq(ward.cooldown, s.cooldown)
		eq(built.effects["effect.stone.ward"].seconds, s.seconds)
		eq(step.costs.qi, w.cost)
		eq(step.cooldown, w.cooldown)
		eq(step.delivery.params.distance, w.distance)
		eq(built.effects["effect.wind.step"].seconds, w.iframes)
	end,
	["kith: Self moves cast through Moves"] = function()
		local built = Registry.build(All.content(Config))
		for _, id in { "move.stone_ward", "move.wind_step" } do
			local move = built.moves[id]
			eq(move.delivery.kind, "Self", id)
			local caster: any = { qi = Config.Qi.max, strain = 0, strainMax = 10, hp = 100, cooldowns = {} }
			eq(Moves.pay(caster, move, 0), true, id .. " pay")
			eq(Moves.pay(caster, move, 0.1), false, id .. " cooldown")
		end
	end,
}
