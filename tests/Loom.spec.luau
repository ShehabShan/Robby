local Loom = require("../src/shared/Loom")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local cfg = {
	Loom = {
		maxSupports = 1,
		frictionFullMarks = 60,
		paths = { ["path.moon"] = { frictionWith = { ["path.flame"] = -0.2 } } },
	},
}

local function crescent(): any
	return {
		id = "move.crescent_cut",
		delivery = { kind = "Projectile", params = { range = 40, maxHits = 1, speed = 90.5 } },
		costs = { qi = 15 },
		effects = { onHit = { "effect.crescent.hit" } },
		tags = { "Path.Moon", "Role.Strike", "Delivery.Proj" },
	}
end

local pierce = {
	id = "support.pierce",
	requireTags = { "Delivery.Proj" },
	excludeTags = {},
	deliveryMods = { maxHits = 3, range = 1.25 },
	addEffects = { onHit = { "effect.slow" } },
	costMult = 1.4,
}
local guardOnly = { id = "support.wall", requireTags = { "Role.Guard" }, excludeTags = {}, costMult = 1 }

return {
	["loom: check fits, limits and duplicates"] = function()
		eq(Loom.check(cfg, crescent(), { pierce }), true, "pierce fits a projectile")
		local ok, why = Loom.check(cfg, crescent(), { guardOnly })
		eq(ok, false, "guard support on a strike")
		eq(why, "needs Role.Guard", "reason")
		eq((Loom.check(cfg, crescent(), {})), false, "no supports")
		eq((Loom.check(cfg, crescent(), { pierce, pierce })), false, "too many")
		eq((Loom.check(cfg, nil, { pierce })), false, "no core")
	end,
	["loom: woven move applies mods and keeps the core"] = function()
		local core = crescent()
		local w = Loom.weave(core, { pierce }, "weave.piercing_crescent")
		eq(w.id, "weave.piercing_crescent", "id")
		eq(w.baseMove, "move.crescent_cut", "base move")
		eq(w.delivery.params.maxHits, 3, "pierce")
		eq(w.delivery.params.range, 50, "range rounded")
		eq(w.costs.qi, 21, "cost ×1.4 rounded up")
		eq(#w.effects.onHit, 2, "extra on-hit")
		eq(w.tags[#w.tags], "Weave", "weave tag")
		eq(core.costs.qi, 15, "core untouched")
		eq(#core.effects.onHit, 1, "core effects untouched")
	end,
	["loom: friction scales with opposed marks and is floored"] = function()
		eq(Loom.friction(cfg, "path.moon", {}), 0, "no opposed marks")
		eq(Loom.friction(cfg, "path.moon", { ["path.flame"] = 30 }), -0.1, "half")
		eq(Loom.friction(cfg, "path.moon", { ["path.flame"] = 600 }), -0.2, "floor")
		eq(Loom.friction(cfg, "path.void", { ["path.flame"] = 60 }), 0, "unknown path")
	end,
	["loom: record saves loadout + journal, first time only"] = function()
		local data: any = { loadout = { slots = {} } }
		local w = { id = "weave.piercing_crescent", core = "move.crescent_cut", supports = { "support.pierce" } }
		eq(Loom.record(data, w, 100), true, "first")
		eq(Loom.record(data, w, 200), false, "again")
		eq(#data.loadout.weaves, 1, "replaced, not duplicated")
		eq(data.journal.weaves["weave.piercing_crescent"], 100, "journal time")
	end,
}
