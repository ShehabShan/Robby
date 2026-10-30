local RimeFxPlan = require("../src/shared/RimeFxPlan")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["rimefx: spread is centred and capped at 12 (T-027e)"] = function()
		local s = RimeFxPlan.spread(5, 30)
		eq(#s, 5, "count")
		eq(s[1], -15, "left edge")
		eq(s[3], 0, "centre")
		eq(s[5], 15, "right edge")
		eq(#RimeFxPlan.spread(40, 30), 12, "cap")
		eq(RimeFxPlan.spread(1, 30)[1], 0, "single")
	end,
	["rimefx: extras drop the centre shard"] = function()
		local e = RimeFxPlan.extras(5, 30)
		eq(#e, 4, "fan extras")
		for _, a in e do
			eq(a ~= 0, true, "no centre")
		end
		eq(#RimeFxPlan.extras(2, 6), 1, "finisher extra")
	end,
	["rimefx: rain points sit in the circle"] = function()
		local r = RimeFxPlan.rain(8, 7)
		eq(#r, 8, "count")
		eq(r[1].x, 0, "centre x")
		for _, p in r do
			eq(math.sqrt(p.x * p.x + p.z * p.z) <= 7, true, "inside radius")
		end
		eq(#RimeFxPlan.rain(50, 7), 12, "cap")
	end,
}
