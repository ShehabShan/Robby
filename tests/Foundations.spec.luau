local Tags = require("../src/shared/Tags")
local Stats = require("../src/shared/Stats")
local DamageMath = require("../src/shared/DamageMath")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, msg: string?)
	if math.abs(actual - expected) > 0.005 then
		error(`{msg or "value"}: expected ~{expected}, got {actual}`, 2)
	end
end

return {
	["tags: parent matches children"] = function()
		local s = Tags.new({ "State.Guarding", "Path.Moon" })
		eq(Tags.has(s, "State"), true)
		eq(Tags.has(s, "State.Guarding"), true)
		eq(Tags.has(s, "State.Stealthed"), false)
		eq(Tags.has(s, "Stat"), false, "no partial-word match")
	end,

	["tags: counted removal"] = function()
		local s = Tags.new({ "State.Wounded", "State.Wounded" })
		Tags.remove(s, "State.Wounded")
		eq(Tags.has(s, "State.Wounded"), true, "one source left")
		Tags.remove(s, "State.Wounded")
		eq(Tags.has(s, "State.Wounded"), false)
		Tags.remove(s, "State.Wounded") -- no error when absent
	end,

	["tags: all / any"] = function()
		local s = Tags.new({ "Path.Moon", "Role.Strike" })
		eq(Tags.hasAll(s, { "Path", "Role.Strike" }), true)
		eq(Tags.hasAll(s, { "Path", "Delivery" }), false)
		eq(Tags.hasAny(s, { "Delivery", "Role" }), true)
		eq(Tags.hasAll(s, nil), true)
	end,

	["stats: bucket order"] = function()
		local mods: { Stats.Modifier } = {
			{ attr = "Power.Moon", bucket = "Add", value = 10 },
			{ attr = "Power.Moon", bucket = "Boost", value = 0.2 },
			{ attr = "Power.Moon", bucket = "Boost", value = 0.3 },
			{ attr = "Power.Moon", bucket = "Surge", value = 1.5 },
			{ attr = "QiMax", bucket = "Add", value = 999 },
		}
		near(Stats.compute("Power.Moon", 90, mods), 100 * 1.5 * 1.5)
	end,

	["stats: surge cap, override, caps"] = function()
		local mods: { Stats.Modifier } = {
			{ attr = "X", bucket = "Surge", value = 2 },
			{ attr = "X", bucket = "Surge", value = 2 },
		}
		near(Stats.compute("X", 10, mods), 30, "surge capped at x3")
		table.insert(mods, { attr = "X", bucket = "Override", value = 5 })
		near(Stats.compute("X", 10, mods), 5, "override")
		near(Stats.compute("X", 10, mods, nil, { min = 8 }), 8, "min cap")
	end,

	["stats: requireTags gate"] = function()
		local s = Tags.new({ "Path.Moon" })
		local has = function(list: { string }): boolean
			return Tags.hasAll(s, list)
		end
		local mods: { Stats.Modifier } = {
			{ attr = "HP", bucket = "Add", value = 50, requireTags = { "Path.Moon" } },
			{ attr = "HP", bucket = "Add", value = 70, requireTags = { "Path.Flame" } },
		}
		near(Stats.compute("HP", 100, mods, has), 150)
		near(Stats.compute("HP", 100, mods), 100, "no tag source = gated off")
		local all = Stats.computeAll({ HP = 100, Qi = 40 }, mods, has)
		near(all.HP, 150)
		near(all.Qi, 40)
	end,

	["damage: potency jumps (R-022)"] = function()
		near(DamageMath.potency(1, 1), 1)
		near(DamageMath.potency(1, 4), 1.3)
		near(DamageMath.potency(2, 1) / DamageMath.potency(1, 4), 1.23, "peak -> next rank")
		near(DamageMath.potency(3, 1), 2.56)
	end,

	["damage: marks soft cap"] = function()
		near(DamageMath.marksBoost(10), 0.0857)
		near(DamageMath.marksBoost(60), 0.3)
		near(DamageMath.marksBoost(200), 0.4615)
		eq(DamageMath.marksBoost(1e9) < 0.6, true, "below +60%")
	end,

	["damage: guard (R-022 table)"] = function()
		near(DamageMath.guardFactor(50, 1), 0.5, "halves same-Rank hit")
		near(DamageMath.guardFactor(50, 3), 0.719, "+2 Rank hit")
		near(DamageMath.guardFactor(0, 1), 1)
	end,

	["damage: full pipeline + floors"] = function()
		local d = DamageMath.compute({ base = 20, rank = 1, boost = 0.5, surge = 10, guard = 50, friction = -0.9 })
		near(d, 20 * 1.5 * 3 * 0.5 * 0.8, "surge cap x3, friction floor -20%")
		near(DamageMath.compute({ base = 20, rank = 1 }), 20)
		eq(DamageMath.compute({ base = -5, rank = 1 }), 0, "never negative")
	end,

	["damage: fresh TTK same Rank is ~10 s (R-022)"] = function()
		local hp = 300 * DamageMath.potency(1, 1)
		local dps = DamageMath.compute({ base = 20, rank = 1 }) * 1.5
		near(hp / dps, 10)
	end,
}
