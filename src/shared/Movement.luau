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
}

export type State = {
	speed: number,
	sprintTime: number,
	stamina: number,
	regenWait: number,
	exhausted: boolean,
}

export type Input = {
	sprint: boolean,
	walk: boolean,
	moving: boolean,
	grounded: boolean,
	turnAngle: number, -- degrees between wanted direction and current velocity (0..180)
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

-- True while the player is allowed to sprint (holding, moving, grounded, stamina left, not exhausted).
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

-- Distance (studs) to stop from `speed` with brake `decel`.
function Movement.stopDistance(speed: number, decel: number): number
	if decel <= 0 then
		return math.huge
	end
	return speed * speed / (2 * decel)
end

-- One frame. Returns a new State; never mutates `s`.
function Movement.step(t: Tuning, s: State, i: Input, dt: number): State
	dt = math.max(dt, 0)
	local sprinting = Movement.canSprint(t, s, i)
	local target = Movement.targetSpeed(t, s, i)
	-- Sharp reversal: brake through zero first (no instant flip / ice skating); the caller's velocity
	-- direction then follows the input and turnAngle drops, so speed builds again.
	if i.moving and i.turnAngle >= t.turnDecelAngle then
		target = 0
	end
	local speed = approach(s.speed, target, Movement.rate(t, s.speed, target, i), dt)
	-- A sharp reversal drops the ramp (momentum is lost); otherwise it builds while sprinting.
	local sprintTime = if sprinting and i.turnAngle < t.turnDecelAngle then s.sprintTime + dt else 0

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
	return { speed = speed, sprintTime = sprintTime, stamina = stamina, regenWait = regenWait, exhausted = exhausted }
end

return Movement
