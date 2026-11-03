local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local AdminRules = require("../src/shared/AdminRules")

local built = Registry.build(All.content(Config))

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function profile(): any
	return {
		kith = { ["starter.crescent"] = { uid = "starter.crescent", speciesId = "kith.crescent" } },
		heartKith = "starter.crescent",
		loadout = { slots = { "starter.crescent" }, weaves = {} },
		wallet = { shards = 2 },
		items = {},
	}
end

return {
	["admin: only allowlisted user ids are admins"] = function()
		eq(AdminRules.isAdmin(Config, 7738981129), true, "owner")
		eq(AdminRules.isAdmin(Config, 1), false, "stranger")
		eq(AdminRules.isAdmin(Config, "7738981129"), false, "string id")
		eq(AdminRules.isAdmin(Config, nil), false, "nil")
	end,
	["admin: validate refuses unknown or malformed requests"] = function()
		eq(select(2, AdminRules.validate(Config, built, nil)), "unknown action", "nil")
		eq(select(2, AdminRules.validate(Config, built, { action = "deleteWorld" })), "unknown action", "action")
		eq(
			select(2, AdminRules.validate(Config, built, { action = "giveKith", speciesId = "kith.nope" })),
			"unknown Kith"
		)
		eq(select(2, AdminRules.validate(Config, built, { action = "addShards", amount = 1.5 })), "bad amount", "frac")
		eq(select(2, AdminRules.validate(Config, built, { action = "addShards", amount = 1e9 })), "bad amount", "huge")
		eq(select(2, AdminRules.validate(Config, built, { action = "addShards", amount = 0 / 0 })), "bad amount", "nan")
		eq(
			select(2, AdminRules.validate(Config, built, { action = "addFood", foodId = "food.x", amount = 1 })),
			"unknown food"
		)
		eq(
			select(
				2,
				AdminRules.validate(Config, built, { action = "spawnBeast", kind = "beast.dragon", distance = 9 })
			),
			"unknown beast"
		)
		local r =
			AdminRules.validate(Config, built, { action = "spawnBeast", kind = "beast.mistfang", distance = 1e6 }) :: any
		eq(r.distance, Config.Admin.spawnDistance.max, "distance clamped")
	end,
	["admin: any species at any rank can be given, marked test-only"] = function()
		local data = profile()
		local list = AdminRules.species(built)
		eq(#list > 1, true, "species listed")
		local req = AdminRules.validate(
			Config,
			built,
			{ action = "giveKith", speciesId = "kith.twin_crescent", extra = 1 }
		) :: any
		eq(req.extra, nil, "unknown fields dropped")
		local ok, uid = AdminRules.apply(data, req)
		eq(ok, true, "ok")
		eq(data.kith[uid].speciesId, "kith.twin_crescent", "owned")
		eq(data.kith[uid].testOnly, true, "test only")
		eq(built.kith[data.kith[uid].speciesId].rank, 2, "rank 2")
	end,
	["admin: remove clears heart and loadout slot"] = function()
		local data = profile()
		local req = AdminRules.validate(Config, built, { action = "removeKith", uid = "starter.crescent" }) :: any
		eq((AdminRules.apply(data, req)), true, "removed")
		eq(data.kith["starter.crescent"], nil, "gone")
		eq(data.heartKith, nil, "heart cleared")
		eq(data.loadout.slots[1], "", "slot cleared")
		eq((AdminRules.apply(data, req)), false, "second remove fails")
	end,
	["admin: cleanup removes only admin grants"] = function()
		local data = profile()
		AdminRules.apply(
			data,
			AdminRules.validate(Config, built, { action = "giveKith", speciesId = "kith.crescent" }) :: any
		)
		AdminRules.apply(data, AdminRules.validate(Config, built, { action = "addShards", amount = 10 }) :: any)
		AdminRules.apply(
			data,
			AdminRules.validate(
				Config,
				built,
				{ action = "addFood", foodId = "food.moonleaf", amount = 3, rare = true }
			) :: any
		)
		eq(data.wallet.shards, 12, "shards added")
		eq(data.items["food.moonleaf.rare"], 3, "rare food added")
		data.items["food.moonleaf.rare"] -= 1 -- player ate one
		AdminRules.apply(data, { action = "cleanup" })
		eq(data.wallet.shards, 2, "shards back")
		eq(data.items["food.moonleaf.rare"], 0, "food never negative")
		eq(data.kith["starter.crescent"] ~= nil, true, "own Kith kept")
		local n = 0
		for _ in data.kith do
			n += 1
		end
		eq(n, 1, "admin Kith removed")
	end,
	["admin: log keeps the newest entries"] = function()
		local data = profile()
		for i = 1, Config.Admin.logCap + 5 do
			AdminRules.log(Config, data, 7738981129, { action = "refill" }, true, "server", i)
		end
		eq(#data.adminLog, Config.Admin.logCap, "capped")
		eq(data.adminLog[#data.adminLog].at, Config.Admin.logCap + 5, "newest kept")
		eq(AdminRules.log(Config, data, 1, nil, false, "x", 0).action, "?", "bad req logged")
	end,
}
