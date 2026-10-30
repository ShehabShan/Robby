local Config = require("../src/shared/Config")
local Stages = require("../src/shared/Stages")
local Breakthrough = require("../src/shared/Breakthrough")

local B = Config.Breakthrough

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function peak(rank: number): any
	local data = { rank = rank, stage = 1 }
	Stages.gain(data, Config, 1e7)
	return data
end

return {
	["breakthrough: needs a full Peak and stops at max Rank"] = function()
		eq(Breakthrough.start({ rank = 1, stage = 1 }, Config, 0), nil, "not ready")
		eq(Breakthrough.start(peak(B.maxRank), Config, 0), nil, "max rank")
		eq(Breakthrough.start(peak(1), Config, 0) ~= nil, true, "ready")
	end,
	["breakthrough: cracking every wave ranks up"] = function()
		local data = peak(1)
		local t = Breakthrough.start(data, Config, 0) :: any
		Breakthrough.step(t, B.waveSeconds - 1)
		Breakthrough.hit(t, Config, B.crackPerWave)
		eq(t.wave, 2, "next wave")
		eq(t.waveLeft, B.waveSeconds, "fresh timer")
		Breakthrough.hit(t, Config, B.crackPerWave * B.waves)
		eq(t.result, "cracked", "cracked")
		eq(Breakthrough.finish(data, t, 0), true, "rank up")
		eq(data.rank, 2, "rank 2")
		eq(data.stage, 1, "first stage")
		eq(data.stageProgress, 0, "empty bar")
	end,
	["breakthrough: failing keeps the Peak and cracks that heal slowly"] = function()
		local data = peak(1)
		local t = Breakthrough.start(data, Config, 0) :: any
		Breakthrough.hit(t, Config, B.crackPerWave * 1.5)
		Breakthrough.step(t, B.waveSeconds)
		eq(t.result, "failed", "failed")
		eq(Breakthrough.finish(data, t, 100), false, "no rank up")
		eq(data.rank, 1, "rank kept")
		eq(Stages.ready(data, Config), true, "peak kept")
		eq(Breakthrough.carried(data, Config, 100), B.crackPerWave * 1.5, "cracks kept")
		local later = 100 + (B.crackPerWave * 0.5) / B.healPerSecond
		eq(Breakthrough.carried(data, Config, later), B.crackPerWave, "cracks heal")
		local retry = Breakthrough.start(data, Config, later) :: any
		eq(retry.crack, B.crackPerWave, "retry keeps some")
		eq(retry.wave, 2, "retry wave")
		eq(Breakthrough.carried(data, Config, 1e9), 0, "fully healed")
	end,
}
