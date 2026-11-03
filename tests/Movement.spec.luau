--!strict
local Movement = require("../src/shared/Movement")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, msg: string?)
	if math.abs(actual - expected) > 1e-6 then
		error(`{msg or "value"}: expected {expected}, got {actual}`, 2)
	end
end

local T: Movement.Tuning = Config.Movement

local function input(o: { [string]: any }?): Movement.Input
	local i: Movement.Input = { sprint = false, walk = false, moving = true, grounded = true, turnAngle = 0 }
	for k, v in o or {} do
		(i :: any)[k] = v
	end
	return i
end

local function run(s: Movement.State, i: Movement.Input, seconds: number): Movement.State
	local dt = 1 / 60
	for _ = 1, math.round(seconds / dt) do
		s = Movement.step(T, s, i, dt)
	end
	return s
end

return {
	["config: R-029 targets are sane"] = function()
		eq(T.walk < T.jog and T.jog < T.sprint and T.sprint <= T.sprintMax, true, "speed order")
		eq(T.jog / T.accel <= 0.2, true, "time to jog within 200 ms")
		eq(Movement.stopDistance(T.jog, T.decel) <= 1.5, true, "crisp stop")
		eq(T.turnDecel > T.decel, true, "turn brake stronger than brake")
	end,
	["step: reaches jog fast and never overshoots"] = function()
		local s = run(Movement.new(T), input(), 0.2)
		near(s.speed, T.jog, "jog")
	end,
	["step: stops when input released"] = function()
		local s = run(Movement.new(T), input(), 0.5)
		s = run(s, input({ moving = false }), 0.2)
		near(s.speed, 0, "stopped")
	end,
	["step: walk key slows to walk"] = function()
		local s = run(Movement.new(T), input({ walk = true }), 0.5)
		near(s.speed, T.walk, "walk")
	end,
	["sprint: ramps from sprint to sprintMax"] = function()
		local s = run(Movement.new(T), input({ sprint = true }), 0.5)
		eq(s.speed >= T.sprint and s.speed < T.sprintMax, true, "early ramp")
		s = run(s, input({ sprint = true }), T.sprintRampSeconds)
		near(s.speed, T.sprintMax, "full ramp")
	end,
	["sprint: no sprint in the air"] = function()
		local s = Movement.new(T)
		eq(Movement.targetSpeed(T, s, input({ sprint = true, grounded = false })), T.jog, "air")
	end,
	["sprint: sharp reversal brakes hard and resets ramp"] = function()
		local s = run(Movement.new(T), input({ sprint = true }), T.sprintRampSeconds + 1)
		local before = s.speed
		s = Movement.step(T, s, input({ sprint = true, turnAngle = 170 }), 0.05)
		eq(s.sprintTime, 0, "ramp reset")
		near(s.speed, before - T.turnDecel * 0.05, "turn brake")
	end,
	["stamina: drains, exhausts, then regens after delay"] = function()
		local s = run(Movement.new(T), input({ sprint = true }), T.staminaMax / T.sprintDrain + 0.1)
		eq(s.exhausted, true, "exhausted")
		near(s.stamina, 0, "empty")
		eq(Movement.canSprint(T, s, input({ sprint = true })), false, "locked")
		s = run(s, input(), T.regenDelay * 0.5)
		near(s.stamina, 0, "waits before regen")
		s = run(s, input(), T.regenDelay + T.exhaustedResume / T.staminaRegen + 0.1)
		eq(s.exhausted, false, "recovered")
	end,
	["turnRate: heavier at sprint speed"] = function()
		near(Movement.turnRate(T, T.jog), T.turnRateJog, "jog")
		near(Movement.turnRate(T, T.sprintMax), T.turnRateSprint, "sprint")
		eq(Movement.turnRate(T, 0), T.turnRateJog, "clamped low")
	end,
	["step: does not mutate state and ignores negative dt"] = function()
		local s = Movement.new(T)
		local n = Movement.step(T, s, input(), -1)
		eq(s.speed, 0, "unchanged")
		eq(n.speed, 0, "no time passed")
	end,
}
