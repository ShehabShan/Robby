--!strict
-- Sprint (T-026b3a, D-163): pure. Target walk speed from the held key and movement, and a
-- frame-rate independent ramp toward it. Speeds come from `Config.Movement`. No game services here.
local Sprint = {}

export type Tuning = { walk: number, sprint: number, accel: number }

-- Target speed: sprint only while held, moving and on the ground.
function Sprint.target(t: Tuning, held: boolean, moving: boolean, grounded: boolean): number
	if held and moving and grounded then
		return t.sprint
	end
	return t.walk
end

-- Move `current` toward `target` by at most accel * dt (studs/s per second).
function Sprint.step(current: number, target: number, accel: number, dt: number): number
	local d = accel * math.max(dt, 0)
	if current < target then
		return math.min(current + d, target)
	end
	return math.max(current - d, target)
end

return Sprint
