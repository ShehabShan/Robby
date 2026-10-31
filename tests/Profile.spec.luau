local ProfileSchema = require("../src/shared/ProfileSchema")
local Retired = require("../src/shared/Retired")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["profile: new player gets the v1 template"] = function()
		local p, issues = ProfileSchema.load(nil)
		eq(p.schemaVersion, ProfileSchema.VERSION)
		eq(p.rank, 1)
		eq(#p.cores, 1, "one core")
		eq(p.wallet.shards, 0)
		eq(p.onboarding.done, false)
		eq(#issues, 0)
	end,
	["profile: templates are independent copies"] = function()
		local a, b = ProfileSchema.template(), ProfileSchema.template()
		a.wallet.shards = 5
		eq(b.wallet.shards, 0)
	end,
	["profile: v0 (unversioned) migrates to current"] = function()
		local p, issues = ProfileSchema.load({ rank = 3, wallet = { shards = 12 } })
		eq(p.schemaVersion, ProfileSchema.VERSION)
		eq(p.rank, 3, "kept rank")
		eq(p.wallet.shards, 12, "kept shards")
		eq(p.loadout.weaves ~= nil, true, "reconciled nested")
		eq(#issues, 0)
	end,
	["profile: v1 save without later fields gets their defaults (F-03)"] = function()
		local p, issues = ProfileSchema.load({ schemaVersion = 1, rank = 2, wallet = { shards = 7 } })
		eq(p.rank, 2, "kept rank")
		eq(p.wallet.shards, 7, "kept shards")
		eq(type(p.trials), "table", "trials default (D-168)")
		eq(type(p.loadout.slots), "table", "loadout default")
		eq(#issues, 0)
	end,
	["profile: every past version has a migration path"] = function()
		for v = 0, ProfileSchema.VERSION - 1 do
			local ok, err = ProfileSchema.migrate({ schemaVersion = v })
			eq(ok, true, `from v{v}: {tostring(err)}`)
		end
	end,
	["profile: newer or bad saves are refused untouched"] = function()
		local newer = { schemaVersion = ProfileSchema.VERSION + 1, rank = 9 }
		local p, issues = ProfileSchema.load(newer)
		eq(p, nil, "refused")
		eq(#issues, 1)
		eq(newer.rank, 9, "untouched")
		eq(newer.wallet, nil, "not reconciled")
		eq((ProfileSchema.load({ schemaVersion = 0.5 })), nil, "fractional version")
		eq((ProfileSchema.load("junk")), nil, "not a table")
	end,
	["profile: reconcile keeps values and resets wrong types"] = function()
		local p, issues = ProfileSchema.load({ schemaVersion = 1, journal = { recipes = { "r1" } }, timers = 5 })
		eq(p.journal.recipes[1], "r1", "kept recipe")
		eq(typeof(p.journal.codex), "table", "filled codex")
		eq(typeof(p.timers), "table", "reset timers")
		eq(#issues, 1)
	end,
	["profile: validate fixes unsafe values"] = function()
		local p, issues = ProfileSchema.load({
			schemaVersion = 1,
			talent = "Z",
			rank = 0,
			stage = 1.5,
			cores = {},
			wallet = { shards = -3 },
		})
		eq(p.talent, "C")
		eq(p.rank, 1)
		eq(p.stage, 1)
		eq(#p.cores, 1)
		eq(p.wallet.shards, 0)
		eq(#issues, 5)
	end,
	["profile: retired kith are remapped, never dropped"] = function()
		local map: Retired.Map = { ["kith.old"] = "kith.new", ["kith.gone"] = false }
		local p, issues = ProfileSchema.load({
			schemaVersion = 1,
			kith = {
				a = { uid = "a", speciesId = "kith.old" },
				b = { uid = "b", speciesId = "kith.gone" },
				c = { uid = "c", speciesId = "kith.crescent" },
				d = "bad",
			},
		}, function(id: string)
			return Retired.resolve(id, map)
		end)
		eq(p.kith.a.speciesId, "kith.new", "remapped")
		eq(p.kith.b.speciesId, "kith.gone", "kept")
		eq(p.kith.c.speciesId, "kith.crescent", "live")
		eq(p.kith.d, "bad", "malformed kept")
		eq(#issues, 3)
	end,
	["retired: chains resolve, loops end"] = function()
		local map: Retired.Map = { a = "b", b = "c", x = "y", y = "x", z = false }
		eq((Retired.resolve("a", map)), "c")
		eq(select(2, Retired.resolve("a", map)), true)
		eq((Retired.resolve("live", map)), "live")
		eq(select(2, Retired.resolve("live", map)), false)
		eq((Retired.resolve("x", map)), nil, "loop")
		eq((Retired.resolve("z", map)), nil, "no replacement")
	end,
	["profile: sanitize makes a save writable"] = function()
		local shared = { n = 1 }
		local p = ProfileSchema.template()
		p.wallet.shards = 0 / 0
		p.stats.earned.x = math.huge
		p.settings.name = "\xff"
		p.settings.ok = "fine"
		p.settings.fn = function() end
		p.settings.a, p.settings.b = shared, shared
		p.settings.loop = p.settings
		local issues = ProfileSchema.sanitize(p)
		eq(p.wallet.shards, 0, "NaN")
		eq(p.stats.earned.x, 0, "inf")
		eq(p.settings.name, "", "utf8")
		eq(p.settings.ok, "fine", "good string kept")
		eq(p.settings.fn, nil, "function removed")
		eq(p.settings.loop, nil, "cycle cut")
		eq(p.settings.a.n, 1, "shared kept")
		eq(p.settings.b.n, 1, "shared kept twice")
		eq(#issues, 5)
		eq(#ProfileSchema.sanitize(p), 0, "clean after one pass")
	end,
	["profile: Studio uses its own store"] = function()
		eq(ProfileSchema.storeName(true), "PlayerData_Studio")
		eq(ProfileSchema.storeName(false), "PlayerData")
	end,
}
