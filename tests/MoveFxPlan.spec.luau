--!strict
local MoveFxPlan = require("../src/shared/MoveFxPlan")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local T: MoveFxPlan.Tuning = Config.MoveFx

return {
	["dust: only on ground and when running"] = function()
		eq(MoveFxPlan.dustOnStep(T, T.dustMinSpeed + 1, "Concrete"), true, "run")
		eq(MoveFxPlan.dustOnStep(T, T.dustMinSpeed - 1, "Concrete"), false, "walk")
		eq(MoveFxPlan.dustOnStep(T, 30, "Air"), false, "air")
	end,
	["streaks: only sprinting fast, delay in range"] = function()
		eq(MoveFxPlan.streaksOn(T, T.streakMinSpeed, true), true, "on")
		eq(MoveFxPlan.streaksOn(T, T.streakMinSpeed, false), false, "not sprinting")
		eq(MoveFxPlan.streaksOn(T, T.streakMinSpeed - 1, true), false, "slow")
		eq(MoveFxPlan.streakDelay(T, 0), T.streakEveryMin, "min")
		eq(MoveFxPlan.streakDelay(T, 1), T.streakEveryMax, "max")
		eq(MoveFxPlan.streakDelay(T, 5), T.streakEveryMax, "clamp")
	end,
	["dash events: start, side arcs, finish"] = function()
		local s = MoveFxPlan.dashEvents(nil, "side")
		eq(#s, 2, "side count")
		eq(s[1], "start", "side start")
		eq(s[2], "arcs", "side arcs")
		local f = MoveFxPlan.dashEvents(nil, "forward")
		eq(#f, 1, "forward count")
		eq(f[1], "start", "forward start")
		local e = MoveFxPlan.dashEvents("back", nil)
		eq(#e, 1, "end count")
		eq(e[1], "finish", "finish")
		eq(#MoveFxPlan.dashEvents("side", "side"), 0, "no change")
		eq(#MoveFxPlan.dashEvents(nil, nil), 0, "idle")
	end,
}
