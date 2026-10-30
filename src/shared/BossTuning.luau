--!strict
-- Boss tuning estimate (T-023d, D-169). Pure arithmetic: player DPS from the light chain, time-to-kill,
-- boss pattern cycle length and DPS per phase, and how many worst-case hits a full-HP player survives.
-- Used by tests/BossTuning.spec.luau to keep a boss inside the Rank 1–2 band. No Roblox services.
local BossTuning = {}

export type Player = { stepSeconds: number, uptime: number, potency: number, maxHp: number }
export type Estimate = {
	playerDps: number,
	ttk: number,
	cycle1: number,
	cycle2: number,
	bossDps1: number,
	bossDps2: number,
	worstHit: number,
	hitsToDie: number,
}

local function cycle(kind: any, pattern: { string }, recoverMult: number): (number, number)
	local seconds, damage = 0, 0
	for _, id in pattern do
		local a = kind.attacks[id]
		seconds += a.telegraph + a.recover * recoverMult + kind.gap
		damage += a.damage
	end
	return seconds, damage
end

function BossTuning.estimate(kind: any, chain: any, p: Player): Estimate
	local chainSeconds = chain.steps * p.stepSeconds + chain.recovery
	local chainDamage = chain.steps * chain.damage * p.potency
	local dps = chainDamage / chainSeconds * p.uptime
	local c1, d1 = cycle(kind, kind.pattern, 1)
	local c2, d2 = cycle(kind, kind.pattern2 or kind.pattern, kind.phase2Recover or 1)
	local worst = 0
	for _, a in kind.attacks do
		worst = math.max(worst, a.damage)
	end
	return {
		playerDps = dps,
		ttk = kind.hp / dps,
		cycle1 = c1,
		cycle2 = c2,
		bossDps1 = d1 / c1,
		bossDps2 = d2 / c2,
		worstHit = worst,
		hitsToDie = if worst > 0 then math.ceil(p.maxHp / worst) else math.huge,
	}
end

return BossTuning
