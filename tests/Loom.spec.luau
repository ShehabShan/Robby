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
	["loom: set / wovenFor / clear on real content (T-020c)"] = function()
		local Config = require("../src/shared/Config")
		local All = require("../src/shared/Content/All")
		local Registry = require("../src/shared/Registry")
		local built, errors = Registry.build(All.content(Config))
		eq(#errors, 0, "registry errors")
		local core = "move.crescent_cut"
		local data: any = { loadout = { slots = {}, weaves = {} } }
		local ok, why, first = Loom.set(data, Config, built, {}, core, { "support.piercing" }, 1)
		eq(ok, false, "not equipped")
		local allowed = { [core] = true }
		ok, why = Loom.set(data, Config, built, allowed, core, { "support.nope" }, 1)
		eq(why, "unknown support", "unknown")
		ok, why, first = Loom.set(data, Config, built, allowed, core, { "support.piercing" }, 1)
		eq(ok, true, "set")
		eq(first, true, "resonance hint")
		ok, why, first = Loom.set(data, Config, built, allowed, core, { "support.piercing" }, 2)
		eq(first, false, "hint once")
		eq(#data.loadout.weaves, 1, "one weave per core")
		local c, p = Config.Abilities.CrescentCut, Config.Loom.supports.Piercing
		local m = Loom.wovenFor(Config, built, data.loadout.weaves, core)
		eq(m.id, core, "keeps core id")
		eq(m.weaveId, "weave.crescent_cut", "weave id")
		eq(m.delivery.params.maxHits, math.floor(c.maxHits * p.maxHitsMult + 0.5), "pierce")
		eq(m.costs.qi, math.ceil(c.cost * p.costMult), "cost")
		eq(built.moves[core].costs.qi, c.cost, "core untouched")
		eq(Loom.wovenFor(Config, built, data.loadout.weaves, "move.twin_crescent"), nil, "other move")
		eq(Loom.clear(data, core), true, "clear")
		eq(Loom.wovenFor(Config, built, data.loadout.weaves, core), nil, "cleared")
		eq(data.journal.weaves["weave.crescent_cut"], 1, "journal keeps it")
	end,
	["loom: registry rejects bad supports"] = function()
		local Registry = require("../src/shared/Registry")
		local bad = { id = "support.bad", requireTags = {}, costMult = 0, addEffects = { onHit = { "effect.x" } } }
		local _, errors = Registry.build({ effects = {}, moves = {}, supports = { bad } })
		eq(#errors, 3, "three errors")
	end,
}
