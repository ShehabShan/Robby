--!strict
-- World-owned delivery identity, independent of player replay caches. No engine objects.
local CastReceipts = require("./CastReceipts")
local Geometry = require("./CastGeometry")
local CastLifetime = {}
export type Handle = {
	acceptance: CastReceipts.Acceptance,
	startedAt: number,
	deadline: number,
	remaining: number,
	resources: number,
	finished: { [number]: boolean },
	terminal: CastReceipts.Terminal?,
}
export type State = {
	capacity: number,
	active: { [string]: Handle },
	count: number,
	onTerminal: ((Handle, number) -> ())?,
}
function CastLifetime.new(capacity: number): State
	assert(capacity >= 1 and capacity % 1 == 0 and capacity < math.huge, "invalid world capacity")
	return { capacity = capacity, active = {}, count = 0 }
end
function CastLifetime.hasRoom(s: State): boolean
	return s.count < s.capacity
end
-- Trusted server acceptance. Copy geometry so neither cache eviction nor caller mutation owns it.
function CastLifetime.start(s: State, a: CastReceipts.Acceptance, now: number, resources: number, grace: number): Handle
	assert(CastLifetime.hasRoom(s) and not s.active[a.castId], "world capacity or duplicate identity")
	assert(resources >= 1 and resources <= 16 and resources % 1 == 0, "invalid resource count")
	assert(now == now and math.abs(now) < math.huge and grace >= 0 and grace < math.huge, "invalid world clock")
	local copy = table.clone(a)
	copy.geometry = if a.geometry then Geometry.copy(a.geometry) else nil
	copy.aim = table.freeze(table.clone(a.aim))
	copy.origin = table.freeze(table.clone(a.origin))
	copy.centre = if a.centre then table.freeze(table.clone(a.centre)) else nil
	local h: Handle = {
		acceptance = table.freeze(copy),
		startedAt = now,
		deadline = now + (a.endsAt - a.acceptedAt) + grace,
		remaining = resources,
		resources = resources,
		finished = {},
		terminal = nil,
	}
	s.active[a.castId] = h
	s.count += 1
	return h
end
function CastLifetime.isActive(s: State, h: Handle): boolean
	return h.terminal == nil and s.active[h.acceptance.castId] == h
end
function CastLifetime.terminate(s: State, h: Handle, reason: string, now: number): boolean
	if not CastLifetime.isActive(s, h) or now < h.startedAt or now ~= now or math.abs(now) == math.huge then
		return false
	end
	h.terminal = table.freeze({ reason = reason, at = h.acceptance.acceptedAt + now - h.startedAt })
	s.active[h.acceptance.castId] = nil
	s.count -= 1
	-- Synchronous non-yielding handoff; only the winning transition invokes it.
	if s.onTerminal then
		s.onTerminal(h, now)
	end
	return true
end
function CastLifetime.finish(s: State, h: Handle, resource: number, now: number): boolean
	if
		not CastLifetime.isActive(s, h)
		or resource < 1
		or resource > h.resources
		or resource % 1 ~= 0
		or h.finished[resource]
		or now < h.startedAt
		or now ~= now
		or math.abs(now) == math.huge
	then
		return false
	end
	h.finished[resource] = true
	h.remaining -= 1
	if h.remaining == 0 then
		return CastLifetime.terminate(s, h, "completed", now)
	end
	return false
end
-- Run AFTER due delivery work, so a stalled heartbeat still applies owed zone ticks once.
function CastLifetime.expire(s: State, now: number)
	for _, h in s.active do
		if now >= h.deadline then
			CastLifetime.terminate(s, h, "expired", now)
		end
	end
end
return CastLifetime
