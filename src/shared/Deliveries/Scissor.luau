--!strict
-- Scissor path (T-053b, D-394): Twin Crescent's two blades as a `Volley` with `curve = "Scissor"`.
-- Blade `side` (-1 left, +1 right) launches `width` studs to that side of the aim line, curves inward on a quarter
-- cosine and crosses the aim line at `crossAt` studs, then keeps its crossing slope so the pair draws an X.
-- Pure: distance `d` along the aim line → sideways offset. No Roblox services.

local Scissor = {}

export type Params = { curve: string?, width: number, crossAt: number, range: number }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Scissor.isScissor(p: any): boolean
	return type(p) == "table" and p.curve == "Scissor"
end

-- Scissor params on top of the Volley ones: a positive width, and a cross point inside the range.
function Scissor.validParams(p: any): boolean
	return Scissor.isScissor(p)
		and finite(p.width)
		and p.width > 0
		and finite(p.crossAt)
		and p.crossAt > 0
		and finite(p.range)
		and p.crossAt < p.range
		and p.count == 2
end

-- Side of shard `index` in a Scissor volley: shard 1 is the left (blue) blade, shard 2 the right (gold) one.
function Scissor.side(index: number): number
	return if index == 1 then -1 else 1
end

-- Sideways offset (studs, + = caster's right) of blade `side` after `d` studs along the aim line.
function Scissor.lateral(side: number, d: number, p: Params): number
	local c = p.crossAt
	local t = math.max(d, 0)
	if t <= c then
		return side * p.width * math.cos(math.pi / 2 * t / c)
	end
	return -side * p.width * (math.pi / (2 * c)) * (t - c)
end

-- d(lateral)/d(d): the blade's sideways slope, for facing the blade along its curve.
function Scissor.slope(side: number, d: number, p: Params): number
	local c = p.crossAt
	local t = math.min(math.max(d, 0), c)
	return -side * p.width * (math.pi / (2 * c)) * math.sin(math.pi / 2 * t / c)
end

-- World-plane point (x, z) of blade `side` at distance d, given the flat aim (ax, az) and the launch origin (ox, oz).
-- The caster's right of a flat aim (ax, az) is (-az, ax) in Roblox (Y up, look -Z).
function Scissor.point(
	side: number,
	d: number,
	p: Params,
	ox: number,
	oz: number,
	ax: number,
	az: number
): (number, number)
	local l = Scissor.lateral(side, d, p)
	local rx, rz = -az, ax
	return ox + ax * d + rx * l, oz + az * d + rz * l
end

-- 3rd blade (T-056, owner 2026-11-03, D-404): only if BOTH blades reach the cross (`crossAt`) still alive, one bigger
-- blade spawns at the cross and flies straight along the aim. A blade that ends earlier (enemy hit or wall) cancels it.
-- The server sweeps each blade up to `crossAt` first, then reports `reachCross` (alive) or `bladeEnded` (done before).
export type Cross = { reached: { [number]: boolean }, blocked: boolean, spawned: boolean }

function Scissor.newCross(): Cross
	return { reached = {}, blocked = false, spawned = false }
end

-- Blade `index` passed the cross alive.
function Scissor.reachCross(c: Cross, index: number)
	if not c.blocked then
		c.reached[index] = true
	end
end

-- Blade `index` ended (hit, wall or lifetime) before reaching the cross: no 3rd blade for this cast.
function Scissor.bladeEnded(c: Cross, index: number)
	if not c.reached[index] then
		c.blocked = true
	end
end

-- True exactly once, when both blades have reached the cross and none was blocked.
function Scissor.takeThird(c: Cross): boolean
	if c.spawned or c.blocked or not (c.reached[1] and c.reached[2]) then
		return false
	end
	c.spawned = true
	return true
end

export type ThirdTuning = { sizeMult: number, rangeMult: number, damageMult: number }

-- 3rd blade Projectile params from one Scissor blade's: hit box × sizeMult, travel (from the cross) = range ×
-- rangeMult, no pierce (maxHits 1), stops on walls. Damage is the content effect (baseDamage × damageMult).
function Scissor.thirdParams(p: any, t: ThirdTuning): any
	local hb = p.hitbox or { x = 1, y = 1, z = 1 }
	return {
		speed = p.speed,
		range = p.range * t.rangeMult,
		maxHits = 1,
		stopOnWorld = true,
		hitbox = { x = hb.x * t.sizeMult, y = hb.y * t.sizeMult, z = hb.z * t.sizeMult },
	}
end

return Scissor
