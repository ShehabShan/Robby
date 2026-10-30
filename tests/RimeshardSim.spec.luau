local Config = require("../src/shared/Config")
local Sim = require("../src/shared/RimeshardSim")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["sim: both kits kill a Mistfang and stop at the kill (T-027g)"] = function()
		local c = Sim.crescent(Config, Sim.targets(60, 1))
		local r = Sim.rimeshard(Config, Sim.targets(60, 1))
		eq(c.ttk ~= nil and r.ttk ~= nil, true, "both finish")
		eq(c.damage, 60, "crescent overkill is clipped")
		eq(r.damage, 60, "rimeshard overkill is clipped")
	end,
	["sim: Rimeshard does not out-DPS Crescent by more than 2x on the Rank-test boss (R-028 §3 guard)"] = function()
		local c = Sim.crescent(Config, Sim.targets(800, 1))
		local r = Sim.rimeshard(Config, Sim.targets(800, 1))
		eq((r.ttk :: number) * 2 > (c.ttk :: number), true, `rime {r.ttk} vs crescent {c.ttk}`)
		eq((r.casts.shatter or 0) >= 1, true, "Shatter fires once stacks are built")
	end,
}
