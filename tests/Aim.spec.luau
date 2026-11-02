--!strict
-- Free 3D aim rules (T-053a1, D-383).
local Aim = require("../src/shared/Aim")

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

return {
	["aim: opt-in only via params.aim = Free"] = function()
		eq(Aim.isFree({ aim = "Free" }), true)
		eq(Aim.isFree({ aim = "Flat" }), false)
		eq(Aim.isFree({}), false)
		eq(Aim.isFree(nil), false)
	end,
	["aim: pitch inside the clamp is kept"] = function()
		local s = math.sin(math.rad(30))
		local c = math.cos(math.rad(30))
		local x, y, z, ok = Aim.clampPitch(0, -s, c, 70)
		eq(ok, true)
		near(x, 0)
		near(y, -s)
		near(z, c)
	end,
	["aim: steep pitch clamps to 70 and keeps yaw"] = function()
		local x, y, z, ok = Aim.clampPitch(0.1, -0.99, 0.1, 70)
		eq(ok, true)
		near(y, -math.sin(math.rad(70)), "y")
		near(x, z, "yaw kept (45 deg)")
		near(math.sqrt(x * x + y * y + z * z), 1, "unit")
		local _, uy = Aim.clampPitch(1, 50, 0, 70)
		near(uy, math.sin(math.rad(70)), "up clamp")
	end,
	["aim: flat input stays flat"] = function()
		local x, y, z, ok = Aim.clampPitch(3, 0, 4, 70)
		eq(ok, true)
		near(x, 0.6)
		near(y, 0)
		near(z, 0.8)
	end,
	["aim: degenerate and non-finite input rejected"] = function()
		eq(select(4, Aim.clampPitch(0, 1, 0, 70)), false, "vertical")
		eq(select(4, Aim.clampPitch(0, 0, 0, 70)), false, "zero")
		eq(select(4, Aim.clampPitch(0 / 0, 0, 1, 70)), false, "nan")
		eq(select(4, Aim.clampPitch(math.huge, 0, 1, 70)), false, "inf")
		eq(select(4, Aim.clampPitch(1, 0, 0, 0 / 0)), false, "nan clamp")
	end,
	["aim: direction to a point ahead"] = function()
		local x, y, z, ok = Aim.toPoint(0, 3, 0, 0, 0, 10, 0, 1, 4)
		eq(ok, true)
		local d = math.sqrt(9 + 100)
		near(x, 0)
		near(y, -3 / d)
		near(z, 10 / d)
	end,
	["aim: too close or behind falls back"] = function()
		eq(select(4, Aim.toPoint(0, 0, 0, 0, 0, 2, 0, 1, 4)), false, "too close")
		eq(select(4, Aim.toPoint(0, 0, 0, 0, 0, -20, 0, 1, 4)), false, "behind")
		eq(select(4, Aim.toPoint(0, 0, 0, 0 / 0, 0, 20, 0, 1, 4)), false, "nan")
	end,
}
