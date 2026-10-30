local SpeedGuard = require("../src/shared/SpeedGuard")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

-- 4 Hz samples: sprint 24 → 6 studs/sample, limit 6 × 1.25 + 2 = 9.5.
local C = { sprint = 24, burstSpeed = 60, burstSeconds = 0.5, tolerance = 1.25, slack = 2, strikes = 3 }

return {
	["first sample and zero dt are ok"] = function()
		local s = SpeedGuard.new()
		eq(SpeedGuard.check(C, s, 5, 5, 1), "ok", "first")
		eq(SpeedGuard.check(C, s, 50, 5, 1), "ok", "same time")
	end,
	["sprinting is ok"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		for i = 1, 8 do
			eq(SpeedGuard.check(C, s, i * 6, 0, i * 0.25), "ok", `step {i}`)
		end
	end,
	["double sprint speed: flag, flag, correct to last good"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		eq(SpeedGuard.check(C, s, 12, 0, 0.25), "flag", "1")
		eq(SpeedGuard.check(C, s, 24, 0, 0.5), "flag", "2")
		local v, gx, gz = SpeedGuard.check(C, s, 36, 0, 0.75)
		eq(v, "correct", "3")
		eq(gx, 0, "good x")
		eq(gz, 0, "good z")
		eq(SpeedGuard.check(C, s, 6, 0, 1), "ok", "measured from good pos")
	end,
	["an ok sample clears strikes"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		eq(SpeedGuard.check(C, s, 12, 0, 0.25), "flag", "1")
		eq(SpeedGuard.check(C, s, 18, 0, 0.5), "ok", "back to normal")
		eq(SpeedGuard.check(C, s, 30, 0, 0.75), "flag", "strikes reset")
	end,
	["Wind Step burst allows burst speed, then expires"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		SpeedGuard.burst(C, s, 0)
		eq(SpeedGuard.check(C, s, 15, 0, 0.25), "ok", "burst 60 studs/s")
		eq(SpeedGuard.check(C, s, 30, 0, 0.5), "ok", "still in burst")
		eq(SpeedGuard.check(C, s, 45, 0, 0.75), "flag", "burst over")
	end,
	["planar only: falling is ignored"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		eq(SpeedGuard.check(C, s, 3, 4, 0.25), "ok", "5 studs diagonal")
	end,
	["reset forgets samples"] = function()
		local s = SpeedGuard.new()
		SpeedGuard.check(C, s, 0, 0, 0)
		SpeedGuard.reset(s)
		eq(SpeedGuard.check(C, s, 500, 500, 0.25), "ok", "respawn far away")
		eq(SpeedGuard.allowed(C, s, 0, 0), 2, "slack only at dt 0")
	end,
}
