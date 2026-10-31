--!strict
-- All M1 Kith content (T-015a): merges each Kith's content into one table for `Registry.build`.
-- Pure: Config is passed in.

local Crescent = require("./Crescent")
local Lotus = require("./Lotus")
local Rimeshard = require("./Rimeshard")
local Wind = require("./Wind")

local All = {}

function All.content(cfg: any): any
	local out: { [string]: { any } } = { effects = {}, moves = {}, kith = {}, supports = {} }
	local parts: { any } = {
		Crescent.content(cfg),
		Wind.content(cfg),
		Lotus.content(cfg),
		Rimeshard.content(cfg), -- T-027c
	}
	for _, part in parts do
		for _, key in { "effects", "moves", "kith", "supports" } do
			local list = out[key]
			for _, rec in part[key] or {} do
				table.insert(list, rec)
			end
		end
	end
	return out
end

return All
