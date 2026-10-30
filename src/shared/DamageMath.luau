--!strict
-- Damage pipeline (R-022, SCHEMAS §2). Pure rules. No Roblox services.
-- dmg = Base × Potency(Rank, Stage) × (1 + ΣBoost) × min(ΠSurge, 3) × Guard factor × (1 + Friction)

export type Hit = {
	base: number,
	rank: number, -- attacker Rank (1-based)
	stage: number?, -- attacker Stage inside the Rank, 1..STAGES (default 1)
	boost: number?, -- summed additive % (e.g. 0.3 = +30%)
	surge: number?, -- product of multiplicative mods (capped)
	guard: number?, -- defender Guard
	friction: number?, -- Path Friction (negative = penalty), floored at FRICTION_FLOOR
}

local DamageMath = {}

DamageMath.RANK_POTENCY = 1.6
DamageMath.STAGES = 4
DamageMath.PEAK_STAGE_BONUS = 0.3 -- Peak Stage = ×1.3 of First Stage, so Peak → next Rank = ×1.23
DamageMath.GUARD_K = 50 -- Guard that halves a same-Rank hit at Rank 1
DamageMath.SURGE_CAP = 3
DamageMath.FRICTION_FLOOR = -0.2
DamageMath.MARKS_MAX = 0.6
DamageMath.MARKS_HALF = 60

function DamageMath.potency(rank: number, stage: number?): number
	local s = math.clamp(stage or 1, 1, DamageMath.STAGES)
	local stageMult = 1 + DamageMath.PEAK_STAGE_BONUS * (s - 1) / (DamageMath.STAGES - 1)
	return DamageMath.RANK_POTENCY ^ (math.max(rank, 1) - 1) * stageMult
end

-- Soft-capped Marks boost: 10 → +9%, 60 → +30%, 200 → +46%, always below +60%.
function DamageMath.marksBoost(marks: number): number
	local m = math.max(marks, 0)
	return DamageMath.MARKS_MAX * m / (m + DamageMath.MARKS_HALF)
end

-- Hyperbolic Guard: no immunity, diminishing returns; K grows with the attacker's Rank.
function DamageMath.guardFactor(guard: number, attackerRank: number): number
	local k = DamageMath.GUARD_K * DamageMath.RANK_POTENCY ^ (math.max(attackerRank, 1) - 1)
	return k / (k + math.max(guard, 0))
end

function DamageMath.compute(hit: Hit): number
	local surge = math.min(hit.surge or 1, DamageMath.SURGE_CAP)
	local friction = math.max(hit.friction or 0, DamageMath.FRICTION_FLOOR)
	local raw = hit.base * DamageMath.potency(hit.rank, hit.stage) * (1 + (hit.boost or 0)) * surge
	local dmg = raw * DamageMath.guardFactor(hit.guard or 0, hit.rank) * (1 + friction)
	return math.max(dmg, 0)
end

return DamageMath
