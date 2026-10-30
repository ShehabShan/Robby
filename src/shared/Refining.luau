--!strict
-- Refine yield from equipped utility Kith (T-025, D-112). Pure: no services.
-- The best `passive.refineYield` among equipped Kith applies (no stacking), capped at `Config.Refining.maxYield`.
-- Stages.refine multiplies Shards → Stage points by the result (1 = no bonus).

local Loadout = require("./Loadout")

local Refining = {}

function Refining.yieldOf(k: any): number
	local p = if type(k) == "table" then k.passive else nil
	local y = if type(p) == "table" then p.refineYield else nil
	return if typeof(y) == "number" and y > 0 then y else 0
end

function Refining.multiplier(data: any, cfg: any, built: any): number
	if type(data) ~= "table" or type(data.loadout) ~= "table" or type(data.loadout.slots) ~= "table" then
		return 1
	end
	if type(data.kith) ~= "table" then
		return 1
	end
	local best = 0
	for _, k in Loadout.equipped(data.loadout, data.kith, built) do
		best = math.max(best, Refining.yieldOf(k))
	end
	return 1 + math.min(best, cfg.Refining.maxYield)
end

return Refining
