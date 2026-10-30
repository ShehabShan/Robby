local Qi = require("../src/shared/Qi")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["new pool starts full"] = function()
		local p = Qi.new(100, 5)
		eq(p.current, 100)
		eq(p.max, 100)
	end,

	["spend reduces and refuses when short"] = function()
		local p = Qi.new(100, 5)
		eq(Qi.spend(p, 30), true)
		eq(p.current, 70)
		eq(Qi.spend(p, 80), false, "overspend")
		eq(p.current, 70, "unchanged")
	end,

	["negative spend is refused"] = function()
		eq(Qi.canSpend(Qi.new(100, 5), -1), false)
	end,

	["regen refills and caps at max"] = function()
		local p = Qi.new(100, 5)
		Qi.spend(p, 50)
		Qi.regen(p, 2)
		eq(p.current, 60)
		Qi.regen(p, 100)
		eq(p.current, 100, "capped")
	end,

	["negative dt does not drain"] = function()
		local p = Qi.new(100, 5)
		Qi.spend(p, 10)
		Qi.regen(p, -5)
		eq(p.current, 90)
	end,
}
