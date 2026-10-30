local Config = require("../src/shared/Config")
local Stages = require("../src/shared/Stages")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function rankTotal(rank: number): number
	local t = 0
	for s = 1, #Stages.NAMES do
		t += Stages.cost(Config, rank, s)
	end
	return t
end

return {
	["stages: cost grows with Stage and Rank"] = function()
		eq(Stages.cost(Config, 1, 2) > Stages.cost(Config, 1, 1), true, "stage")
		eq(Stages.cost(Config, 2, 1) > Stages.cost(Config, 1, 4), true, "rank")
	end,
	["stages: points carry over and stop at a full Peak"] = function()
		local data = { rank = 1, stage = 1 }
		eq(Stages.gain(data, Config, Stages.cost(Config, 1, 1)), Stages.cost(Config, 1, 1), "first stage")
		eq(data.stage, 2, "advanced")
		eq(data.stageProgress, 0, "fresh bar")
		local rest = rankTotal(1) - Stages.cost(Config, 1, 1)
		eq(Stages.gain(data, Config, 1e6), rest, "only what is needed")
		eq(data.stage, 4, "peak")
		eq(Stages.ready(data, Config), true, "breakthrough ready")
		eq(Stages.gain(data, Config, 10), 0, "full peak takes nothing")
	end,
	["stages: refine only at rest and never spends more Shards than owned"] = function()
		local data = { rank = 1, stage = 1, wallet = { shards = 30 } }
		eq(Stages.refine(data, Config, 10, false), 0, "not at rest")
		eq(Stages.refine(data, Config, 100, true), 30, "all owned")
		eq(data.wallet.shards, 0, "wallet empty")
		eq(data.stageProgress, 30, "progress")
		eq(Stages.refine(data, Config, 5, true), 0, "nothing left")
	end,
	["stages: bad saves are fixed and the view shows the shell"] = function()
		local data: any = { rank = 1, stage = 9, stageProgress = -3 }
		local v = Stages.view(data, Config)
		eq(v.stage, 4, "clamped")
		eq(v.name, "Peak", "name")
		eq(v.shell, "crystal", "shell")
		eq(v.progress, 0, "progress reset")
		local fresh = Stages.view({ rank = 1 }, Config)
		eq(fresh.shell, "mist", "first shell")
		eq(fresh.ready, false, "not ready")
	end,
}
