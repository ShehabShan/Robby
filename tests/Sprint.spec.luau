local Sprint = require("../src/shared/Sprint")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local T = { walk = 16, sprint = 24, accel = 40 }

return {
	["target: only held + moving + grounded sprints"] = function()
		eq(Sprint.target(T, true, true, true), 24, "sprint")
		eq(Sprint.target(T, false, true, true), 16, "not held")
		eq(Sprint.target(T, true, false, true), 16, "standing")
		eq(Sprint.target(T, true, true, false), 16, "in air")
	end,
	["step: ramps, never overshoots, no dt"] = function()
		eq(Sprint.step(16, 24, 40, 0.1), 20, "ramp up")
		eq(Sprint.step(16, 24, 40, 1), 24, "cap up")
		eq(Sprint.step(24, 16, 40, 1), 16, "cap down")
		eq(Sprint.step(16, 24, 40, 0), 16, "no dt")
	end,
}
