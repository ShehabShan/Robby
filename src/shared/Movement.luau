--!strict
-- Movement core (T-058a, D-426): Robby's own pure movement step. Momentum (accel / brake / turn brake),
-- walk → jog → sprint with a sprint ramp, stamina with exhaustion, and speed-dependent turn rate.
-- Numbers come from `Config.Movement` (targets: research/notes/R-029-movement.md). No game services here.
local Movement = {}

export type Tuning = {
	walk: number,
	jog: number,
	sprint: number,
	sprintMax: number,
	sprintRampSeconds: number,
	accel: number,
	decel: number,
	turnDecel: number,
	turnDecelAngle: number,
	turnRateJog: number,
	turnRateSprint: number,
	staminaMax: number,
	sprintDrain: number,
	staminaRegen: number,
	regenDelay: number,
	exhaustedResume: number,
	landMinFall: number,
	landRecoverPerSpeed: number,
	landRecoverMax: number,
	landSpeedMult: number,
	slideMinSpeed: number,
	slideStartSpeed: number,
	slideSeconds: number,
	slideCooldown: number,
	slideCost: number,
}

export type State = {
	speed: number,
	sprintTime: number,
	stamina: number,
	regenWait: number,
	exhausted: boolean,
	recover: number?, -- seconds of landing recovery left (T-058g)
	slide: number?, -- seconds of slide left (T-058e)
	slideFrom: number?, -- speed the slide started at
	slideCd: number?, -- slide cooldown left
	carry: number?, -- speed kept through a slide-jump until touchdown
}

export type Input = {
	sprint: boolean,
	walk: boolean,
	moving: boolean,
	grounded: boolean,
	turnAngle: number, -- degrees between wanted direction and current velocity (0..180)
	landedFall: number?, -- downward speed (studs/s) at touchdown this frame (T-058g)
	slide: boolean?, -- slide key pressed this frame (T-058e)
}

function Movement.new(t: Tuning): State
	return { speed = 0, sprintTime = 0, stamina = t.staminaMax, regenWait = 0, exhausted = false }
end

local function approach(current: number, target: number, rate: number, dt: number): number
	local d = rate * math.max(dt, 0)
	if current < target then
		return math.min(current + d, target)
	end
	return math.max(current - d, target)
end
Movement.approach = approach

-- Run toggle (T-060a, D-469): one press of Shift / L3 / the touch button flips run on or off; release does nothing.
-- The toggle survives exhaustion and stops: `canSprint` still gates actual sprinting on stamina and movement.
function Movement.toggleRun(on: boolean, pressed: boolean): boolean
	if pressed then
		return not on
	end
	return on
end

-- True while the player is allowed to sprint (run toggled on, moving, grounded, stamina left, not exhausted).
function Movement.canSprint(_t: Tuning, s: State, i: Input): boolean
	return i.sprint and i.moving and i.grounded and not s.exhausted and s.stamina > 0
end

-- Sprint speed after `sprintTime` seconds of sprinting: ramps sprint → sprintMax.
function Movement.sprintSpeed(t: Tuning, sprintTime: number): number
	local k = if t.sprintRampSeconds > 0 then math.clamp(sprintTime / t.sprintRampSeconds, 0, 1) else 1
	return t.sprint + (t.sprintMax - t.sprint) * k
end

function Movement.targetSpeed(t: Tuning, s: State, i: Input): number
	if not i.moving then
		return 0
	end
	if Movement.canSprint(t, s, i) then
		return Movement.sprintSpeed(t, s.sprintTime)
	end
	return if i.walk then t.walk else t.jog
end

-- Rate used to change speed: accel when speeding up, brake when slowing, turn brake on sharp reversals.
function Movement.rate(t: Tuning, current: number, target: number, i: Input): number
	if i.moving and i.turnAngle >= t.turnDecelAngle and current > 0 then
		return t.turnDecel
	end
	return if target >= current then t.accel else t.decel
end

-- Turn rate in degrees per second: heavier turns as speed rises from jog to sprintMax.
function Movement.turnRate(t: Tuning, speed: number): number
	local span = t.sprintMax - t.jog
	local k = if span > 0 then math.clamp((speed - t.jog) / span, 0, 1) else 0
	return t.turnRateJog + (t.turnRateSprint - t.turnRateJog) * k
end

-- Landing recovery (T-058g, D-430): seconds of slowed movement after touching down at `fallSpeed`.
-- Small hops give none; harder falls give more, capped at landRecoverMax.
function Movement.landRecovery(t: Tuning, fallSpeed: number): number
	if fallSpeed ~= fallSpeed or fallSpeed < t.landMinFall then
		return 0
	end
	return math.min((fallSpeed - t.landMinFall) * t.landRecoverPerSpeed + 0.1, t.landRecoverMax)
end

-- Slide (T-058e, D-431): from a run on the ground with stamina, off cooldown, not recovering.
function Movement.canSlide(t: Tuning, s: State, i: Input): boolean
	return i.grounded
		and i.moving
		and s.speed >= t.slideMinSpeed
		and s.stamina >= t.slideCost
		and (s.slide or 0) <= 0
		and (s.slideCd or 0) <= 0
		and (s.recover or 0) <= 0
end

-- Slide speed `elapsed` seconds in: holds most of the burst early, then drops to jog (quadratic ease-in).
function Movement.slideSpeed(t: Tuning, from: number, elapsed: number): number
	local k = if t.slideSeconds > 0 then math.clamp(elapsed / t.slideSeconds, 0, 1) else 1
	return from + (t.jog - from) * k * k
end

-- Distance (studs) to stop from `speed` with brake `decel`.
function Movement.stopDistance(speed: number, decel: number): number
	if decel <= 0 then
		return math.huge
	end
	return speed * speed / (2 * decel)
end

local function slideStep(t: Tuning, s: State, i: Input, dt: number): State
	local slide, slideCd, carry = s.slide or 0, math.max((s.slideCd or 0) - dt, 0), s.carry
	local stamina = s.stamina
	local from = s.slideFrom or 0
	if i.slide and Movement.canSlide(t, s, i) then
		slide, from, slideCd = t.slideSeconds, math.max(s.speed, t.slideStartSpeed), t.slideCooldown
		stamina -= t.slideCost
	end
	if slide > 0 then
		if not i.grounded then
			carry = Movement.slideSpeed(t, from, t.slideSeconds - slide) -- slide-jump keeps momentum
			slide = 0
		else
			slide = math.max(slide - dt, 0)
			return {
				speed = Movement.slideSpeed(t, from, t.slideSeconds - slide),
				sprintTime = 0,
				stamina = stamina,
				regenWait = t.regenDelay,
				exhausted = s.exhausted,
				recover = 0,
				slide = slide,
				slideFrom = from,
				slideCd = slideCd,
				carry = nil,
			}
		end
	end
	if carry and i.grounded then
		carry = nil
	end
	return {
		speed = if carry then carry else s.speed,
		sprintTime = s.sprintTime,
		stamina = stamina,
		regenWait = s.regenWait,
		exhausted = s.exhausted,
		recover = s.recover,
		slide = 0,
		slideFrom = from,
		slideCd = slideCd,
		carry = carry,
	}
end

-- One frame. Returns a new State; never mutates `s`.
function Movement.step(t: Tuning, s0: State, i: Input, dt: number): State
	dt = math.max(dt, 0)
	local sl = slideStep(t, s0, i, dt)
	if (sl.slide or 0) > 0 then
		return sl
	end
	local s = sl
	local recover = math.max((s.recover or 0) - dt, 0)
	local landing = if i.landedFall then Movement.landRecovery(t, i.landedFall) else 0
	recover = math.max(recover, landing)
	local sprinting = Movement.canSprint(t, s, i) and recover <= 0
	local target = Movement.targetSpeed(t, s, i)
	if recover > 0 then
		target = math.min(target, t.walk * t.landSpeedMult)
	end
	-- Sharp reversal: brake through zero first (no instant flip / ice skating); the caller's velocity
	-- direction then follows the input and turnAngle drops, so speed builds again.
	if i.moving and i.turnAngle >= t.turnDecelAngle then
		target = 0
	end
	local speed = approach(s.speed, target, Movement.rate(t, s.speed, target, i), dt)
	if s.carry and not i.grounded then
		speed = s.carry -- slide-jump: keep the slide's speed until touchdown
	end
	-- A sharp reversal drops the ramp (momentum is lost); otherwise it builds while sprinting.
	local sprintTime = if sprinting and i.turnAngle < t.turnDecelAngle then s.sprintTime + dt else 0
	if landing > 0 then
		speed = math.min(speed, t.walk * t.landSpeedMult) -- a hard landing kills momentum at once
	end

	local stamina, regenWait, exhausted = s.stamina, s.regenWait, s.exhausted
	if sprinting then
		stamina = math.max(stamina - t.sprintDrain * dt, 0)
		regenWait = t.regenDelay
		if stamina <= 0 then
			exhausted = true
		end
	else
		regenWait = math.max(regenWait - dt, 0)
		if regenWait <= 0 then
			stamina = math.min(stamina + t.staminaRegen * dt, t.staminaMax)
		end
		if exhausted and stamina >= t.exhaustedResume then
			exhausted = false
		end
	end
	return {
		speed = speed,
		sprintTime = sprintTime,
		stamina = stamina,
		regenWait = regenWait,
		exhausted = exhausted,
		recover = recover,
		slide = 0,
		slideFrom = s.slideFrom,
		slideCd = s.slideCd,
		carry = if i.grounded then nil else s.carry,
	}
end

return Movement
