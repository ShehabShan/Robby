local Config = require("../src/shared/Config")
local KithCare = require("../src/shared/KithCare")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function profile(): any
	return {
		kith = {
			a = { uid = "a", speciesId = "kith.crescent" },
			b = { uid = "b", speciesId = "kith.stone" },
		},
		loadout = { slots = { "a", "", "b" } },
		items = { ["food.stonemoss"] = 1 },
	}
end

return {
	["kith care wiring: the casting Kith is the equipped one of the move's species"] = function()
		local data = profile()
		local uid, inst = KithCare.casterOf(data, { kith = "kith.stone" })
		eq(uid, "b", "uid")
		eq(inst, data.kith.b, "inst")
		eq(KithCare.casterOf(data, { kith = "kith.wind" }), nil, "not equipped")
		eq(KithCare.casterOf({}, { kith = "kith.stone" }), nil, "no loadout")
	end,
	["kith care wiring: move Strain uses costs.strain or the default"] = function()
		eq(KithCare.moveStrain(Config, { costs = { strain = 7 } }), 7, "explicit")
		eq(KithCare.moveStrain(Config, { costs = { qi = 5 } }), Config.Upkeep.defaultStrain, "default")
		eq(KithCare.moveStrain(Config, {}), Config.Upkeep.defaultStrain, "no costs")
	end,
	["kith care wiring: casting until full Strain blocks the Kith"] = function()
		local inst = profile().kith.a
		KithCare.ensure(inst, Config)
		local casts = 0
		while KithCare.usable(inst, Config, 0) and casts < 100 do
			KithCare.addStrain(inst, Config, KithCare.moveStrain(Config, {}), 0)
			casts += 1
		end
		eq(casts, math.ceil(Config.Upkeep.strainMax / Config.Upkeep.defaultStrain), "casts to exhaust")
		eq(KithCare.state(inst, Config, 0), "Exhausted", "exhausted")
	end,
	["kith care wiring: feeding consumes the species food; rare needs a rare item"] = function()
		local data = profile()
		local inst = data.kith.b
		inst.satiety, inst.strain, inst.dormant = 0, 0, true
		eq(KithCare.feedFrom(data, inst, Config, "food.stonemoss", false), false, "dormant refuses common")
		eq(data.items["food.stonemoss"], 1, "not consumed")
		eq(KithCare.feedFrom(data, inst, Config, "food.stonemoss", true), false, "no rare item")
		data.items["food.stonemoss.rare"] = 1
		eq(KithCare.feedFrom(data, inst, Config, "food.stonemoss", true), true, "rare wakes")
		eq(data.items["food.stonemoss.rare"], 0, "rare consumed")
		eq(KithCare.feedFrom(data, inst, Config, nil, false), false, "no food id")
		eq(KithCare.feedFrom({}, inst, Config, "food.stonemoss", false), false, "no items")
		local strain, satiety, state = KithCare.view(inst, Config, 0)
		eq(strain, 0, "view strain")
		eq(satiety, 1, "view satiety")
		eq(state, "Ready", "view state")
	end,
}
