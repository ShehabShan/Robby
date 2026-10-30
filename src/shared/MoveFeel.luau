--!strict
-- Movement feel (T-026b1, D-161): pure math for body lean, camera bob and the landing dip.
-- Inspired by the owner's R15 kit (D-160), rewritten for Robby. The client applies the numbers:
-- lean → LowerTorso.Root C0, bob + dip → Humanoid.CameraOffset. No game services here.
local MoveFeel = {}

export type Params = {
	leanMax: number, -- max lean angle (radians) at full speed
	leanForward: number, -- forward/back share of leanMax
	leanSide: number, -- strafe share of leanMax
	leanRate: number, -- smoothing rate (1/s); higher = snappier
	refSpeed: number, -- speed (studs/s) that gives full lean/bob
	bobFreq: number, -- steps per second at refSpeed
	bobUp: number, -- vertical bob (studs) at refSpeed
	bobSide: number, -- side sway (studs) at refSpeed
	dipPerSpeed: number, -- landing dip (studs) per stud/s of fall speed
	dipMax: number, -- dip cap (studs)
	dipMinFall: number, -- falls slower than this give no dip
	dipRecover: number, -- dip recovery rate (1/s)
}

MoveFeel.DEFAULTS = table.freeze({
	leanMax = math.rad(7),
	leanForward = 1,
	leanSide = 0.8,
	leanRate = 8,
	refSpeed = 16,
	bobFreq = 1.8,
	bobUp = 0.12,
	bobSide = 0.06,
	dipPerSpeed = 0.02,
	dipMax = 0.8,
	dipMinFall = 20,
	dipRecover = 6,
} :: Params)

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-- Frame-rate independent smoothing toward `target`.
function MoveFeel.approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * math.max(dt, 0)))
end

-- Target lean from velocity in the root's local space (forward = -Z, right = +X).
-- Returns pitch (forward tilt, negative = lean forward) and roll (side tilt).
function MoveFeel.leanTarget(localX: number, localZ: number, p: Params?): (number, number)
	local q = p or MoveFeel.DEFAULTS
	local f = math.clamp(-localZ / q.refSpeed, -1, 1)
	local s = math.clamp(localX / q.refSpeed, -1, 1)
	return -f * q.leanMax * q.leanForward, -s * q.leanMax * q.leanSide
end

-- Camera bob offset (x, y) at phase time `t` for a planar speed. Zero when standing still.
function MoveFeel.bob(t: number, speed: number, p: Params?): (number, number)
	local q = p or MoveFeel.DEFAULTS
	local k = clamp01(speed / q.refSpeed)
	if k < 0.05 then
		return 0, 0
	end
	local w = 2 * math.pi * q.bobFreq * t
	return math.sin(w) * q.bobSide * k, -math.abs(math.sin(w)) * q.bobUp * k
end

-- Phase advance per frame: bob runs faster at higher speed (at least half rate while moving).
function MoveFeel.bobPhase(t: number, speed: number, dt: number, p: Params?): number
	local q = p or MoveFeel.DEFAULTS
	return t + dt * math.max(0.5, math.min(speed / q.refSpeed, 1.5))
end

-- Landing dip (studs, ≥ 0) from the downward speed at touchdown.
function MoveFeel.landDip(fallSpeed: number, p: Params?): number
	local q = p or MoveFeel.DEFAULTS
	if fallSpeed < q.dipMinFall then
		return 0
	end
	return math.min((fallSpeed - q.dipMinFall) * q.dipPerSpeed + 0.15, q.dipMax)
end

return MoveFeel
