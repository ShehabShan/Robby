local BossTuning = require("../src/shared/BossTuning")
local DamageMath = require("../src/shared/DamageMath")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function within(v: number, lo: number, hi: number, msg: string)
	if v < lo or v > hi then
		error(`{msg}: {v} not in [{lo}, {hi}]`, 2)
	end
end

-- D-169 assumptions: 0.4 s per chain step, 60 % attack uptime, default Humanoid 100 HP.
local function player(rank: number)
	return { stepSeconds = 0.4, uptime = 0.6, potency = DamageMath.potency(rank, 1), maxHp = 100 }
end

local K = Config.Bosses.kinds["boss.mistmaw"]
local CHAIN = Config.Combat.chain

return {
	["arithmetic on a toy boss"] = function()
		local k = {
			hp = 100,
			gap = 1,
			phase2Recover = 0.5,
			attacks = { a = { telegraph = 1, recover = 2, damage = 10 } },
			pattern = { "a" },
			pattern2 = { "a" },
		}
		local e = BossTuning.estimate(
			k,
			{ steps = 1, damage = 10, recovery = 0 },
			{ stepSeconds = 1, uptime = 1, potency = 1, maxHp = 25 }
		)
		eq(e.playerDps, 10, "dps")
		eq(e.ttk, 10, "ttk")
		eq(e.cycle1, 4, "cycle1")
		eq(e.cycle2, 3, "cycle2")
		eq(e.hitsToDie, 3, "hits")
	end,
	["Mistmaw: Rank 1 kills in 60–120 s, Rank 2 in 40–80 s"] = function()
		within(BossTuning.estimate(K, CHAIN, player(1)).ttk, 60, 120, "rank 1 ttk")
		within(BossTuning.estimate(K, CHAIN, player(2)).ttk, 40, 80, "rank 2 ttk")
	end,
	["Mistmaw: a full-HP player survives 6 worst hits"] = function()
		local e = BossTuning.estimate(K, CHAIN, player(1))
		if e.hitsToDie < 7 then
			error(`hitsToDie {e.hitsToDie} < 7 (worst hit {e.worstHit})`)
		end
	end,
}
