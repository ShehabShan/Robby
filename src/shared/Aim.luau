--!strict
-- Free 3D aim (T-053a1, D-383; owner D-380 pitch clamp ±70°). Pure rules. No Roblox services.
-- A move opts in with `delivery.params.aim = "Free"`; every other move keeps flat aim (Projectile.flatten).
-- The client aims at a world point; the server re-clamps the pitch and never trusts the client.

local Aim = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- True when the Move's delivery params opt in to free 3D aim.
function Aim.isFree(params: any): boolean
	return type(params) == "table" and params.aim == "Free"
end

-- Keeps the yaw of (x, y, z) and clamps its elevation to ±maxPitchDeg (0..89).
-- Returns a unit (x, y, z, ok); ok is false for non-finite, zero-length or vertical input (no yaw).
function Aim.clampPitch(x: number, y: number, z: number, maxPitchDeg: number): (number, number, number, boolean)
	if not (finite(x) and finite(y) and finite(z) and finite(maxPitchDeg)) then
		return 0, 0, 0, false
	end
	local h = math.sqrt(x * x + z * z)
	if h < 1e-6 then
		return 0, 0, 0, false
	end
	local maxP = math.rad(math.clamp(maxPitchDeg, 0, 89))
	local pitch = math.clamp(math.atan2(y, h), -maxP, maxP)
	local c = math.cos(pitch)
	return x / h * c, math.sin(pitch), z / h * c, true
end

-- Unit direction from the blade origin (o) to an aim point (p). ok is false (use flat aim) when the point
-- is closer than minDist, not finite, or not in front of the flat forward (fx, fz).
function Aim.toPoint(
	ox: number,
	oy: number,
	oz: number,
	px: number,
	py: number,
	pz: number,
	fx: number,
	fz: number,
	minDist: number
): (number, number, number, boolean)
	local dx, dy, dz = px - ox, py - oy, pz - oz
	if not (finite(dx) and finite(dy) and finite(dz)) then
		return 0, 0, 0, false
	end
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	if d < minDist or d < 1e-6 then
		return 0, 0, 0, false
	end
	if dx * fx + dz * fz <= 0 then
		return 0, 0, 0, false
	end
	return dx / d, dy / d, dz / d, true
end

return Aim
