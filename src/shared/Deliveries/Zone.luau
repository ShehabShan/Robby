--!strict
-- Zone delivery (T-027b, D-175): an aimed ground circle that telegraphs for `delay`, then deals `ticks` pulses
-- over `duration` to everything inside `radius` (Rime Fall). Pure: the server supplies now/positions.

local Zone = {}

export type Params = { radius: number, range: number, delay: number, ticks: number, duration: number }
export type State = { startedAt: number, fired: number, done: boolean }

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Zone.validParams(p: any): boolean
	return type(p) == "table"
		and type(p.radius) == "number"
		and p.radius > 0
		and type(p.range) == "number"
		and p.range > 0
		and type(p.delay) == "number"
		and p.delay >= 0
		and type(p.ticks) == "number"
		and p.ticks >= 1
		and p.ticks == math.floor(p.ticks)
		and type(p.duration) == "number"
		and p.duration >= 0
end

-- The aimed point must be finite and within `range` of the caster (flat distance). Y is the server's raycast job.
function Zone.isValidPoint(cx: number, cz: number, px: number, pz: number, params: Params): boolean
	if not (finite(px) and finite(pz)) then
		return false
	end
	local dx, dz = px - cx, pz - cz
	return dx * dx + dz * dz <= params.range * params.range
end

function Zone.new(now: number): State
	return { startedAt = now, fired = 0, done = false }
end

-- Time at which tick i (1..ticks) fires: first at delay, last at delay + duration.
function Zone.tickAt(i: number, params: Params): number
	if params.ticks == 1 then
		return params.delay
	end
	return params.delay + params.duration * (i - 1) / (params.ticks - 1)
end

-- Returns how many ticks are due at `now` that have not fired yet (the server damages everything in zone that many times).
function Zone.step(s: State, now: number, params: Params): number
	if s.done then
		return 0
	end
	local due = 0
	local t = now - s.startedAt
	while s.fired < params.ticks and t + 1e-6 >= Zone.tickAt(s.fired + 1, params) do
		s.fired += 1
		due += 1
	end
	if s.fired >= params.ticks then
		s.done = true
	end
	return due
end

-- Telegraph progress 0..1 during the delay (drives the growing decal); 1 once the rain has started.
function Zone.telegraph(s: State, now: number, params: Params): number
	if params.delay <= 0 then
		return 1
	end
	return math.clamp((now - s.startedAt) / params.delay, 0, 1)
end

function Zone.contains(px: number, pz: number, tx: number, tz: number, params: Params): boolean
	local dx, dz = tx - px, tz - pz
	return dx * dx + dz * dz <= params.radius * params.radius
end

return Zone
