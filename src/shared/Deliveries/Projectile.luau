--!strict
-- Projectile delivery (SCHEMAS §5, R-021 §5): the generic, data-driven form of the spike's Crescent Cut blade.
-- Reads only Move `delivery.params` (speed, range, maxHits). Pure rules. No Roblox services.
-- The server owns the sweep (blockcasts between `from` and `to`); this module owns travel, aim and hit rules.

export type Params = { speed: number, range: number, maxHits: number }
export type State = {
	traveled: number,
	done: boolean,
	hitCount: number,
	hits: { [string]: boolean },
}

local Projectile = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- A client-sent direction must be finite and unit length (tolerance 0.01). Never trust client aim.
function Projectile.isValidDirection(x: number, y: number, z: number): boolean
	if not (finite(x) and finite(y) and finite(z)) then
		return false
	end
	return math.abs(math.sqrt(x * x + y * y + z * z) - 1) <= 0.01
end

-- Flattens an aim onto the ground plane. Returns (x, z, ok); ok is false when aiming straight up/down.
function Projectile.flatten(x: number, z: number): (number, number, boolean)
	local m = math.sqrt(x * x + z * z)
	if m < 1e-3 then
		return 0, 0, false
	end
	return x / m, z / m, true
end

-- Rejects params that would make a projectile that never ends or never hits.
function Projectile.validParams(p: any): boolean
	return type(p) == "table"
		and type(p.speed) == "number"
		and p.speed > 0
		and type(p.range) == "number"
		and p.range > 0
		and type(p.maxHits) == "number"
		and p.maxHits >= 1
end

function Projectile.new(): State
	return { traveled = 0, done = false, hitCount = 0, hits = {} }
end

-- Advances the projectile. Returns the (from, to) distances along the path covered this step.
function Projectile.step(s: State, dt: number, params: Params): (number, number)
	local from = s.traveled
	if s.done then
		return from, from
	end
	local to = math.min(params.range, from + params.speed * math.max(dt, 0))
	s.traveled = to
	if to >= params.range then
		s.done = true
	end
	return from, to
end

-- Records a hit on targetId. Each target is hit once; the projectile stops after maxHits targets.
function Projectile.registerHit(s: State, targetId: string, params: Params): boolean
	if s.hits[targetId] or s.hitCount >= params.maxHits then
		return false
	end
	s.hits[targetId] = true
	s.hitCount += 1
	if s.hitCount >= params.maxHits then
		s.done = true
	end
	return true
end

return Projectile
