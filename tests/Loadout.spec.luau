local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Loadout = require("../src/shared/Loadout")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local built = Registry.build(All.content(Config))

local function owned(): any
	return {
		u1 = { speciesId = "kith.crescent" },
		u2 = { speciesId = "kith.wind" },
		u3 = { speciesId = "kith.wind" },
		u4 = { speciesId = "kith.gone" },
	}
end

local function fresh(): any
	return { slots = {}, weaves = {} }
end

return {
	["loadout: activeKith is the first equipped Kith with a chain move"] = function()
		local own = owned()
		own.u5 = { speciesId = "kith.rimeshard" }
		local lo = fresh()
		eq(Loadout.activeKith(lo, own, built), nil, "nothing equipped")
		Loadout.equip(lo, Config, 1, own, built, 1, "u1")
		eq(Loadout.activeKith(lo, own, built), nil, "Crescent has no chain move")
		Loadout.equip(lo, Config, 1, own, built, 2, "u5")
		eq(Loadout.activeKith(lo, own, built), "kith.rimeshard", "Rimeshard drives the stance")
		Loadout.unequip(lo, 2)
		eq(Loadout.activeKith(lo, own, built), nil, "unequipped again")
	end,
	["loadout: 3 slots at Rank 1, +1 per Rank, max 7"] = function()
		eq(Loadout.slotCount(Config, 1), 3, "rank 1")
		eq(Loadout.slotCount(Config, 2), 4, "rank 2")
		eq(Loadout.slotCount(Config, 5), 7, "rank 5")
		eq(Loadout.slotCount(Config, 9), 7, "cap")
		eq(Loadout.slotCount(Config, 0), 3, "floor")
	end,
	["loadout: equip checks slot range and ownership"] = function()
		local lo, own = fresh(), owned()
		eq(Loadout.equip(lo, Config, 1, own, built, 1, "u1"), true, "ok")
		eq(Loadout.equip(lo, Config, 1, own, built, 4, "u2"), false, "slot 4 at rank 1")
		eq(Loadout.equip(lo, Config, 2, own, built, 4, "u2"), true, "slot 4 at rank 2")
		eq(Loadout.equip(lo, Config, 1, own, built, 0, "u2"), false, "slot 0")
		eq(Loadout.equip(lo, Config, 1, own, built, 1.5, "u2"), false, "fraction")
		eq(Loadout.equip(lo, Config, 1, own, built, 0 / 0, "u2"), false, "nan")
		eq(Loadout.equip(lo, Config, 1, own, built, 2, "u4"), false, "unknown species")
		eq(Loadout.equip(lo, Config, 1, own, built, 2, "u9"), false, "not owned")
		eq(lo.slots[2], "", "filled gap")
		eq(lo.slots[4], "u2", "slot 4")
	end,
	["loadout: moving a Kith frees its old slot; unequip clears"] = function()
		local lo, own = fresh(), owned()
		Loadout.equip(lo, Config, 1, own, built, 1, "u1")
		Loadout.equip(lo, Config, 1, own, built, 2, "u1")
		eq(lo.slots[1], "", "old slot")
		eq(lo.slots[2], "u1", "new slot")
		eq(Loadout.unequip(lo, 2), true, "unequip")
		eq(lo.slots[2], "", "cleared")
		eq(Loadout.unequip(lo, 6), false, "missing slot")
	end,
	["loadout: sanitize trims to rank and drops bad entries"] = function()
		local lo = { slots = { "u1", "u1", "u9", "u2" }, weaves = {} }
		local issues = Loadout.sanitize(lo, Config, 1, owned(), built)
		eq(#issues, 3, `issues: {table.concat(issues, "; ")}`)
		eq(#lo.slots, 3, "length")
		eq(lo.slots[1], "u1", "kept")
		eq(lo.slots[2], "", "duplicate cleared")
		eq(lo.slots[3], "", "unknown cleared")
		local empty: any = {}
		Loadout.sanitize(empty, Config, 2, owned(), built)
		eq(#empty.slots, 4, "reset to rank size")
	end,
	["loadout: role counts and gap warning"] = function()
		local lo, own = fresh(), owned()
		eq(#Loadout.gaps(lo, own, built, Config), #Config.Loadout.warnRoles, "empty warns all")
		Loadout.equip(lo, Config, 1, own, built, 1, "u1")
		eq(Loadout.roleCounts(lo, own, built).Strike, 1, "strike count")
		eq(#Loadout.gaps(lo, own, built, Config), 0, "no gaps")
	end,
	["loadout: only equipped Kith moves are allowed"] = function()
		local lo, own = fresh(), owned()
		Loadout.equip(lo, Config, 1, own, built, 3, "u2")
		local allowed = Loadout.allowedMoves(lo, own, built)
		eq(allowed["move.wind_step"], true, "equipped move")
		eq(allowed["move.crescent_cut"], nil, "unequipped move")
	end,
	["loadout: six GDD roles; every M1 Kith has one"] = function()
		eq(#Loadout.ROLES, 6, "roles")
		eq(Loadout.isRole("Mobility"), false, "old role")
		for id, k in built.kith do
			eq(Loadout.isRole(k.role), true, id)
		end
	end,
	["loadout: prepare grants starter Kith and fills the slots"] = function()
		local data: any = { rank = 1, kith = {}, loadout = { slots = {}, weaves = {} } }
		eq(#Loadout.prepare(data, Config, built), 0, "no issues")
		eq(data.loadout.slots[1], "starter.rimeshard", "slot 1")
		eq(data.loadout.slots[2], "starter.crescent", "slot 2")
		eq(data.loadout.slots[3], "starter.wind", "slot 3")
		eq(data.kith["starter.wind"] ~= nil, true, "wind owned")
		eq(data.kith["gift.rimeshard"], nil, "no duplicate gift")
		eq(Loadout.activeKith(data.loadout, data.kith, built), "kith.rimeshard", "Rimeshard stance reachable")
		for _, id in { "move.crescent_cut", "move.wind_step" } do
			eq(Loadout.canCast(data.loadout, data.kith, built, id), true, id)
		end
	end,
	["loadout: existing profile gets the Rimeshard gift once (D-195)"] = function()
		local data: any = { rank = 1, kith = owned(), loadout = { slots = { "u1", "u2", "u3" }, weaves = {} } }
		Loadout.prepare(data, Config, built)
		eq(data.kith["gift.rimeshard"].speciesId, "kith.rimeshard", "gift granted")
		eq(data.gifts["kith.rimeshard"], true, "gift recorded")
		eq(data.loadout.slots[1], "gift.rimeshard", "gift auto-equipped in slot 1 (D-211)")
		eq(Loadout.activeKith(data.loadout, data.kith, built), "kith.rimeshard", "stance reachable without the menu")
		Loadout.unequip(data.loadout, 1)
		Loadout.prepare(data, Config, built)
		eq(data.loadout.slots[1], "", "a later unequip is respected")
		eq(Loadout.equip(data.loadout, Config, 1, data.kith, built, 1, "gift.rimeshard"), true, "equippable")
		eq(Loadout.activeKith(data.loadout, data.kith, built), "kith.rimeshard", "stance after equip")
		data.kith["gift.rimeshard"] = nil
		Loadout.prepare(data, Config, built)
		eq(data.kith["gift.rimeshard"], nil, "not granted twice")
	end,
	["loadout: prepare keeps a valid loadout and refuses unequipped moves"] = function()
		local data: any = {
			rank = 1,
			kith = owned(),
			loadout = { slots = { "", "u2", "" }, weaves = {} },
			giftsEquipped = { ["kith.rimeshard"] = true }, -- auto-equip already done (D-211)
		}
		Loadout.prepare(data, Config, built)
		eq(data.kith.starter, nil, "no starter grant")
		eq(data.loadout.slots[1], "", "kept empty")
		eq(Loadout.canCast(data.loadout, data.kith, built, "move.wind_step"), true, "equipped")
		eq(Loadout.canCast(data.loadout, data.kith, built, "move.crescent_cut"), false, "unequipped refused")
		local bare: any = { rank = 1, kith = owned() }
		Loadout.prepare(bare, Config, built)
		eq(bare.loadout.slots[1], "gift.rimeshard", "filled from owned (gift sorts first)")
		eq(bare.loadout.slots[2], "u1", "uid order")
	end,
	["registry: unknown Kith role is an error"] = function()
		local _, errors =
			Registry.build({ effects = {}, moves = {}, kith = { { id = "kith.k", role = "Tank", moves = {} } } })
		eq(#errors, 1, `errors: {table.concat(errors, "; ")}`)
		eq(string.find(errors[1], "unknown role", 1, true) ~= nil, true, errors[1])
	end,
}
