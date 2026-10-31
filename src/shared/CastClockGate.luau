--!strict
-- Pure clock/future-receipt admission. No production policy or live wiring.
local Bridge = require("./CastBridge")
local Presentation = require("./CastPresentation")
local CastClockGate = {}
export type Policy = {
	pendingCapacity: number,
	futureSeconds: number,
	maxWaitSeconds: number,
	maxSampleError: number,
	correctionPerSecond: number,
}
export type Pending = { timeline: Presentation.Timeline, deadline: number }
export type State = {
	bridge: Bridge.State,
	policy: Policy,
	pending: { [string]: Pending },
	count: number,
	lastLocal: number?,
	now: number?,
	busy: boolean,
	closed: boolean,
	badSamples: number,
	expired: number,
	retiredThrough: number,
	refusals: number,
}
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
function CastClockGate.new(bridge: Bridge.State, policy: Policy): State
	assert(
		finite(policy.pendingCapacity) and policy.pendingCapacity >= 1 and policy.pendingCapacity % 1 == 0,
		"invalid queue capacity"
	)
	assert(
		finite(policy.futureSeconds)
			and policy.futureSeconds >= 0
			and policy.futureSeconds + bridge.presentation.policy.maxLifetimeSeconds
				<= bridge.presentation.policy.tombstoneSeconds,
		"terminal retention must cover future tolerance plus lifetime"
	)
	assert(finite(policy.maxWaitSeconds) and policy.maxWaitSeconds > 0, "invalid wait timeout")
	assert(finite(policy.maxSampleError) and policy.maxSampleError >= 0, "invalid sample tolerance")
	assert(
		finite(policy.correctionPerSecond) and policy.correctionPerSecond >= 0 and policy.correctionPerSecond < 1,
		"clock must progress"
	)
	assert(not bridge.closed and bridge.presentation.lastNow == -math.huge, "gate owns a fresh bridge")
	return {
		bridge = bridge,
		policy = table.freeze(table.clone(policy)),
		pending = {},
		count = 0,
		lastLocal = nil,
		now = nil,
		busy = false,
		closed = false,
		badSamples = 0,
		expired = 0,
		retiredThrough = -math.huge,
		refusals = 0,
	}
end
local function remove(s: State, key: string)
	if s.pending[key] then
		s.pending[key] = nil
		s.count -= 1
	end
end
local function valid(s: State, key: string, t: Presentation.Timeline): boolean
	return #key > 0
		and #key <= 256
		and finite(t.acceptedAt)
		and finite(t.releaseAt)
		and finite(t.endsAt)
		and finite(t.x)
		and finite(t.y)
		and finite(t.z)
		and t.acceptedAt <= t.releaseAt
		and t.releaseAt <= t.endsAt
		and t.endsAt - t.acceptedAt <= s.bridge.presentation.policy.maxLifetimeSeconds
end
-- Local elapsed time always advances the clock. A bounded slew can never reverse
-- it or freeze cleanup. Outlier/nonfinite server samples are ignored after anchoring.
local function begin(s: State, localNow: number, serverNow: number, cancelled: { [string]: boolean }?): boolean
	if s.closed or s.busy or not finite(localNow) or (s.lastLocal and localNow < s.lastLocal) then
		s.refusals += 1
		return false
	end
	local previous = s.now
	local now: number = serverNow
	if previous == nil then
		if not finite(serverNow) then
			s.refusals += 1
			return false
		end
	else
		local dt = localNow - (s.lastLocal or localNow)
		local predicted = previous + dt
		local correction = 0
		if finite(serverNow) and math.abs(serverNow - predicted) <= s.policy.maxSampleError then
			local limit = dt * s.policy.correctionPerSecond
			correction = math.clamp(serverNow - predicted, -limit, limit)
		else
			s.badSamples += 1
		end
		now = predicted + correction
	end
	if not finite(now) then
		s.refusals += 1
		return false
	end
	s.lastLocal = localNow
	s.now = now
	s.busy = true
	-- A snapshot's terminals retire together BEFORE any seek or future drain.
	if cancelled then
		for key in cancelled do
			local pending = s.pending[key]
			remove(s, key)
			if Bridge.cancel(s.bridge, key, now) == "refuse" and pending then
				s.retiredThrough = math.max(s.retiredThrough, pending.timeline.acceptedAt)
			end
		end
	end
	Bridge.tick(s.bridge, now)
	-- Detach each queued item before dispatch/disposal. Deadline wins over release
	-- after a long idle gap; we do not flash an old warning just because time caught up.
	for key, pending in s.pending do
		if pending.timeline.acceptedAt <= s.retiredThrough then
			remove(s, key)
		elseif localNow >= pending.deadline then
			remove(s, key)
			s.expired += 1
			if Bridge.cancel(s.bridge, key, now) == "refuse" then
				s.retiredThrough = math.max(s.retiredThrough, pending.timeline.acceptedAt)
			end
		elseif pending.timeline.acceptedAt <= now then
			remove(s, key)
			Bridge.accept(s.bridge, key, pending.timeline, now)
		end
	end
	return true
end
function CastClockGate.tick(s: State, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow) then
		return false
	end
	s.busy = false
	return true
end
function CastClockGate.predict(s: State, key: string, localNow: number, serverNow: number): string
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	local outcome = Bridge.predict(s.bridge, key, s.now :: number)
	s.busy = false
	return outcome
end
function CastClockGate.accept(
	s: State,
	key: string,
	timeline: Presentation.Timeline,
	localNow: number,
	serverNow: number
): string
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	local now = s.now :: number
	local outcome = "refuse"
	if valid(s, key, timeline) then
		local entry = s.bridge.presentation.entries[key]
		if
			s.pending[key]
			or (entry and entry.kind ~= "predicted")
			or timeline.acceptedAt <= math.max(s.bridge.presentation.cancelledThrough, s.retiredThrough)
		then
			outcome = "ignore"
		elseif timeline.acceptedAt <= now then
			outcome = Bridge.accept(s.bridge, key, timeline, now)
		elseif timeline.acceptedAt - now <= s.policy.futureSeconds and s.count < s.policy.pendingCapacity then
			s.pending[key] =
				{ timeline = table.freeze(table.clone(timeline)), deadline = localNow + s.policy.maxWaitSeconds }
			s.count += 1
			outcome = "queued"
		end
	end
	if outcome == "refuse" then
		s.refusals += 1
	end
	s.busy = false
	return outcome
end
function CastClockGate.cancelMany(s: State, keys: { [string]: boolean }, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow, keys) then
		return false
	end
	s.busy = false
	return true
end
function CastClockGate.cancel(s: State, key: string, localNow: number, serverNow: number): string
	-- Do not drain this key into a visible start when its cancellation arrives.
	if
		s.closed
		or s.busy
		or not finite(localNow)
		or (s.lastLocal and localNow < s.lastLocal)
		or (s.now == nil and not finite(serverNow))
	then
		s.refusals += 1
		return "refuse"
	end
	local pending = s.pending[key]
	remove(s, key)
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	local outcome = Bridge.cancel(s.bridge, key, s.now :: number)
	if outcome == "refuse" and pending then
		s.retiredThrough = math.max(s.retiredThrough, pending.timeline.acceptedAt)
	end
	s.busy = false
	return outcome
end
function CastClockGate.retirePose(s: State, key: string, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow) then
		return false
	end
	local retired = Bridge.retirePose(s.bridge, key, s.now :: number)
	s.busy = false
	return retired
end
function CastClockGate.destroy(s: State): boolean
	if s.closed then
		return true
	elseif s.busy then
		s.refusals += 1
		return false
	end
	s.closed = true
	s.pending = {}
	s.count = 0
	return Bridge.destroy(s.bridge)
end
return CastClockGate
