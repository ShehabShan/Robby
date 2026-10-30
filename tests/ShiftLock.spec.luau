local ShiftLock = require("../src/shared/ShiftLock")

local function near(actual: number, expected: number, msg: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{msg}: expected {expected}, got {actual}`, 2)
	end
end

return {
	["yaw: matches Roblox LookVector (-sin, -cos)"] = function()
		for _, yaw in { 0, 0.5, math.pi / 2, -2 } do
			local got = ShiftLock.yaw(-math.sin(yaw), -math.cos(yaw))
			assert(got, "yaw nil")
			near(math.sin(got), math.sin(yaw), "sin")
			near(math.cos(got), math.cos(yaw), "cos")
		end
		assert(ShiftLock.yaw(0, 0) == nil, "vertical look gives nil")
	end,
	["flatAim: normalizes, rejects zero"] = function()
		local x, z, ok = ShiftLock.flatAim(3, 4)
		assert(ok, "ok")
		near(x, 0.6, "x")
		near(z, 0.8, "z")
		local _, _, bad = ShiftLock.flatAim(0, 0)
		assert(not bad, "zero rejected")
	end,
}
