--!strict
-- Crescent Cut (Crescent Kith, rank 1, Moon path): pure rules. No Roblox services.
-- The server composes this with Qi and simulates the projectile itself (.ai/SPIKE.md §3).

export type Config = {
	cost: number,
	cooldown: number,
	baseDamage: number,
	rankBonus: number,
	speed: number,
	range: number,
	maxHits: number,
	hitboxSize: { x: number, y: number, z: number },
	spawnOffset: number,
}

export type Projectile = {
	traveled: number,
	done: boolean,
	hitCount: number,
	hits: { [string]: boolean },
}

local CrescentCut = {}

CrescentCut.MAX_RANK = 9

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Damage for a caster rank (clamped to 1..9): base * (1 + bonus * (rank - 1)).
function CrescentCut.damageFor(rank: number, cfg: Config): number
	local r = math.clamp(math.floor(rank), 1, CrescentCut.MAX_RANK)
	return cfg.baseDamage * (1 + cfg.rankBonus * (r - 1))
end

-- Whether a cast is allowed now. Returns (ok, reason) with reason "dead" | "cooldown" | "qi".
function CrescentCut.tryCast(
	now: number,
	lastCast: number?,
	qi: number,
	alive: boolean,
	cfg: Config
): (boolean, string?)
	if not alive then
		return false, "dead"
	end
	if lastCast ~= nil and now - lastCast < cfg.cooldown then
		return false, "cooldown"
	end
	if qi < cfg.cost then
		return false, "qi"
	end
	return true, nil
end

-- A client-sent direction must be finite and unit length (tolerance 0.01).
function CrescentCut.isValidDirection(x: number, y: number, z: number): boolean
	if not (finite(x) and finite(y) and finite(z)) then
		return false
	end
	return math.abs(math.sqrt(x * x + y * y + z * z) - 1) <= 0.01
end

-- Flattens an aim direction onto the ground plane. Returns (x, z, ok); ok is false when looking straight up/down.
function CrescentCut.flatten(x: number, z: number): (number, number, boolean)
	local m = math.sqrt(x * x + z * z)
	if m < 1e-3 then
		return 0, 0, false
	end
	return x / m, z / m, true
end

function CrescentCut.newProjectile(): Projectile
	return { traveled = 0, done = false, hitCount = 0, hits = {} }
end

-- Advances the projectile. Returns the (from, to) distances along the path covered this step.
function CrescentCut.stepProjectile(p: Projectile, dt: number, cfg: Config): (number, number)
	local from = p.traveled
	if p.done then
		return from, from
	end
	local to = math.min(cfg.range, from + cfg.speed * math.max(dt, 0))
	p.traveled = to
	if to >= cfg.range then
		p.done = true
	end
	return from, to
end

-- Records a hit on targetId. Each target is hit once; the blade stops after maxHits targets.
function CrescentCut.registerHit(p: Projectile, targetId: string, cfg: Config): boolean
	if p.hits[targetId] or p.hitCount >= cfg.maxHits then
		return false
	end
	p.hits[targetId] = true
	p.hitCount += 1
	if p.hitCount >= cfg.maxHits then
		p.done = true
	end
	return true
end

return CrescentCut
