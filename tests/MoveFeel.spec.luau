local MoveFeel = require("../src/shared/MoveFeel")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end
local function near(a: number, b: number, msg: string?)
	if math.abs(a - b) > 1e-6 then
		error(`{msg or "value"}: expected ~{b}, got {a}`, 2)
	end
end

local D = MoveFeel.DEFAULTS

return {
	["lean: still, forward, capped, back, strafe"] = function()
		local p, r = MoveFeel.leanTarget(0, 0)
		near(p, 0, "still pitch")
		near(r, 0, "still roll")
		near((MoveFeel.leanTarget(0, -16)), -D.leanMax, "full forward lean")
		near((MoveFeel.leanTarget(0, -100)), -D.leanMax, "lean capped")
		near((MoveFeel.leanTarget(0, 8)), D.leanMax * 0.5, "half back lean")
		local _, r2 = MoveFeel.leanTarget(16, 0)
		near(r2, -D.leanMax * D.leanSide, "strafe roll")
	end,
	["approach: no dt, converges, no overshoot"] = function()
		near(MoveFeel.approach(1, 5, 8, 0), 1, "no dt")
		near(MoveFeel.approach(1, 5, 8, 10), 5, "converges")
		local a = MoveFeel.approach(0, 1, 8, 1 / 60)
		eq(a > 0 and a < 1, true, "partial step")
	end,
	["bob: zero standing, bounded moving"] = function()
		local bx, by = MoveFeel.bob(0.3, 0)
		eq(bx, 0, "still bob x")
		eq(by, 0, "still bob y")
		for i = 0, 40 do
			local x, y = MoveFeel.bob(i / 40, 30)
			eq(math.abs(x) <= D.bobSide + 1e-9, true, "bob x bound")
			eq(y <= 0 and y >= -D.bobUp - 1e-9, true, "bob y bound")
		end
		eq(MoveFeel.bobPhase(0, 0, 1) > 0, true, "phase advances")
	end,
	["landDip: small none, real fall dips, capped"] = function()
		eq(MoveFeel.landDip(10), 0, "small fall")
		eq(MoveFeel.landDip(30) > 0, true, "dip on real fall")
		eq(MoveFeel.landDip(1000), D.dipMax, "dip cap")
	end,
}
