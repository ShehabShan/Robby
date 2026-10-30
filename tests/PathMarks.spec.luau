local PathMarks = require("../src/shared/PathMarks")
local DamageMath = require("../src/shared/DamageMath")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local cfg = {
	Marks = { perHit = 1, max = 500 },
	Loom = { frictionFullMarks = 60, paths = { ["path.moon"] = { frictionWith = { ["path.flame"] = -0.2 } } } },
}

return {
	["marks: path from tags"] = function()
		eq(PathMarks.pathOf({ tags = { "Role.Strike", "Path.Moon" } }), "path.moon", "moon")
		eq(PathMarks.pathOf({ tags = { "Role.Strike" } }), nil, "none")
	end,
	["marks: earned per hit and capped"] = function()
		local d: any = {}
		eq(PathMarks.award(d, cfg, "path.moon", 3), 3, "three hits")
		eq(PathMarks.award(d, cfg, nil, 3), 0, "no path")
		eq(PathMarks.award(d, cfg, "path.moon", 999), 500, "cap")
	end,
	["marks: boost own path, friction from opposed"] = function()
		local b, f = PathMarks.hitMods(cfg, { ["path.moon"] = 60, ["path.flame"] = 60 }, "path.moon")
		eq(b, DamageMath.marksBoost(60), "boost")
		eq(f, -0.2, "friction")
		local b0, f0 = PathMarks.hitMods(cfg, nil, "path.moon")
		eq(b0, 0, "no marks")
		eq(f0, 0, "no friction")
	end,
}
