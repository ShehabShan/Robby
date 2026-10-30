local Config = require("../src/shared/Config")
local Crucible = require("../src/shared/Crucible")

local C = Config.Crucible
local R = C.recipes["recipe.twin_crescent"]

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function profile(shards: number): any
	return {
		kith = {
			a = { uid = "a", speciesId = "kith.crescent" },
			b = { uid = "b", speciesId = "kith.crescent" },
			w = { uid = "w", speciesId = "kith.stone_ward" },
		},
		heartKith = "a",
		loadout = { slots = { "a", "b" } },
		journal = { recipes = {} },
		wallet = { shards = shards },
	}
end

return {
	["crucible: refuses bad picks, missing recipe and too few Shards"] = function()
		local d = profile(R.catalystShards)
		eq((Crucible.recipe(d, Config, "a", "a", 0)), nil, "same kith")
		eq((Crucible.recipe(d, Config, "a", "w", 0)), nil, "no recipe")
		eq((Crucible.recipe(profile(R.catalystShards - 1), Config, "a", "b", 0)), nil, "shards")
		eq((Crucible.recipe(d, Config, "a", "b", 0)), "recipe.twin_crescent", "recipe found")
	end,
	["crucible: experimental odds rise with focus and cap; known recipe is safe"] = function()
		local d = profile(0)
		eq(Crucible.odds(d, Config, "recipe.twin_crescent", 0), R.baseChance, "base")
		eq(
			Crucible.odds(d, Config, "recipe.twin_crescent", 1),
			math.min(R.baseChance + C.focusBonus, C.maxChance),
			"focus"
		)
		d.journal.recipes["recipe.twin_crescent"] = true
		eq(Crucible.odds(d, Config, "recipe.twin_crescent", 0), 1, "known")
	end,
	["crucible: success merges, keeps Heart and slot, records recipe"] = function()
		local d = profile(R.catalystShards + 5)
		local res = Crucible.fuse(d, Config, "a", "b", 1, 0, 0) :: any
		eq(res.success, true, "success")
		eq(d.wallet.shards, 5, "catalyst paid")
		eq(d.kith.a == nil and d.kith.b == nil, true, "inputs merged")
		eq(d.kith[res.outputUid].speciesId, R.output, "output species")
		eq(d.heartKith, res.outputUid, "heart moves")
		eq(d.loadout.slots[1], res.outputUid, "slot keeps output")
		eq(d.journal.recipes["recipe.twin_crescent"], true, "journal")
	end,
	["crucible: fail loses catalyst and Wounds one Kith, never destroys"] = function()
		local d = profile(R.catalystShards)
		local res = Crucible.fuse(d, Config, "a", "b", 0, 0.999, 100) :: any
		eq(res.success, false, "fail")
		eq(d.wallet.shards, 0, "catalyst lost")
		eq(d.kith.a ~= nil and d.kith.b ~= nil, true, "nothing destroyed")
		eq(Crucible.wounded(d.kith[res.woundedUid], 101), true, "wounded")
		eq(Crucible.powerFactor(d.kith[res.woundedUid], Config, 101), C.woundedPower, "weaker")
		eq(Crucible.wounded(d.kith[res.woundedUid], 100 + C.woundedSeconds), false, "heals after a day")
		eq((Crucible.recipe(d, Config, "a", "b", 101)), nil, "wounded cannot fuse")
	end,
	["crucible: Recoil drains Qi and halves regen for a while"] = function()
		local pool = { current = 80, max = 100, regenRate = 5 }
		local untilT = Crucible.applyRecoil(pool, Config, 1000)
		eq(pool.current, 0, "drained")
		eq(Crucible.regenRate(5, Config, untilT, 1001), 5 * C.recoilRegen, "halved")
		eq(Crucible.regenRate(5, Config, untilT, untilT), 5, "back to normal")
		eq(Crucible.regenRate(5, Config, nil, 0), 5, "no recoil")
	end,
	["crucible: Wounded lowers Kith power until it heals"] = function()
		local KithCare = require("../src/shared/KithCare")
		local inst: any = { uid = "a", speciesId = "kith.crescent" }
		KithCare.ensure(inst, Config)
		inst.woundedUntil = 100
		eq(KithCare.power(inst, Config, 50), C.woundedPower, "wounded power")
		eq(KithCare.power(inst, Config, 100), 1, "healed")
	end,
}
