--!strict
-- Guard ring (T-057c1, D-411): Full Moon Ring reworked into a defensive ring (owner spec 2026-11-03).
-- `count` crescents circle the caster at `radius` studs for `duration` seconds and MOVE with the caster (the centre
-- is the caster's current position each tick). The first enemy that touches the ring shatters it once: tiny stun,
-- interrupt, small knockback away from the caster, damage = one Crescent Cut hit; the caster gets a short speed boost.
-- Pure: positions and touch tests only, no Roblox services. Server wiring is T-057c2.

local GuardRing = {}

export type Params = {
	count: number,
	radius: number, -- studs from the caster's centre
	duration: number, -- seconds the ring lasts if nothing touches it
	spin: number, -- radians per second the crescents orbit
	touchRadius: number, -- an enemy within radius + touchRadius (flat distance) touches the ring
	damage: number,
	stunSeconds: number,
	knockback: number, -- studs/s pushed away from the caster
	speedMult: number, -- caster WalkSpeed multiplier after a shatter
	speedSeconds: number,
}

export type State = { startedAt: number, endsAt: number, shattered: boolean, closed: boolean }

export type Target = { key: string, x: number, z: number }

export type Shatter = {
	key: string,
	damage: number,
	stunSeconds: number,
	interrupt: boolean,
	pushX: number, -- knockback velocity (flat), away from the caster
	pushZ: number,
	speedMult: number,
	speedSeconds: number,
}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function GuardRing.validParams(p: any): boolean
	if type(p) ~= "table" then
		return false
	end
	for _, k in { "radius", "duration", "spin", "touchRadius", "damage", "stunSeconds", "knockback", "speedSeconds" } do
		if not finite(p[k]) or p[k] < 0 then
			return false
		end
	end
	return finite(p.count)
		and p.count >= 2
		and p.count <= 16
		and p.count % 1 == 0
		and p.radius > 3 -- owner: a bit farther out than the old 3-stud ring
		and p.duration > 0
		and finite(p.speedMult)
		and p.speedMult >= 1
end

function GuardRing.new(p: Params, now: number): State
	return { startedAt = now, endsAt = now + p.duration, shattered = false, closed = false }
end

-- Open while not shattered and before `endsAt`; closes itself when time runs out.
function GuardRing.isOpen(s: State, now: number): boolean
	if not s.closed and now >= s.endsAt then
		s.closed = true
	end
	return not s.closed
end

-- Crescent positions round the caster's CURRENT centre (cx, cz): blade 1 starts on the aim angle and all orbit at `spin`.
-- Returns x, z and the facing angle (tangent) of each blade.
function GuardRing.blades(
	s: State,
	p: Params,
	cx: number,
	cz: number,
	aimAngle: number,
	now: number
): { { x: number, z: number, angle: number } }
	local out = {}
	local base = aimAngle + p.spin * math.max(0, now - s.startedAt)
	for i = 1, p.count do
		local a = base + (i - 1) * 2 * math.pi / p.count
		table.insert(out, { x = cx + math.cos(a) * p.radius, z = cz + math.sin(a) * p.radius, angle = a + math.pi / 2 })
	end
	return out
end

-- First touch test this tick. `targets` are enemies only (caller filters the caster and allies). The nearest target
-- within reach shatters the ring (once); returns nil if none or the ring is closed.
function GuardRing.touch(s: State, p: Params, cx: number, cz: number, targets: { Target }, now: number): Shatter?
	if not GuardRing.isOpen(s, now) then
		return nil
	end
	local reach = p.radius + p.touchRadius
	local best: Target? = nil
	local bestD = math.huge
	for _, t in targets do
		local dx, dz = t.x - cx, t.z - cz
		local d = math.sqrt(dx * dx + dz * dz)
		if d <= reach and d < bestD then
			best, bestD = t, d
		end
	end
	if best == nil then
		return nil
	end
	s.shattered, s.closed = true, true
	local dx, dz = best.x - cx, best.z - cz
	local ux, uz = 1, 0
	if bestD > 1e-6 then
		ux, uz = dx / bestD, dz / bestD
	end
	return {
		key = best.key,
		damage = p.damage,
		stunSeconds = p.stunSeconds,
		interrupt = true,
		pushX = ux * p.knockback,
		pushZ = uz * p.knockback,
		speedMult = p.speedMult,
		speedSeconds = p.speedSeconds,
	}
end

return GuardRing
