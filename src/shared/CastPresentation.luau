--!strict
-- T-043c0a2: pure presentation ownership; no rendering, damage, or live wiring.
-- Adapter binds a generation-qualified request/cast key BEFORE events enter this reducer.
local CastPresentation = {}
export type Policy =
	{ capacity: number, predictionSeconds: number, tombstoneSeconds: number, maxLifetimeSeconds: number }
export type Timeline = {
	acceptedAt: number,
	releaseAt: number,
	endsAt: number,
	x: number,
	y: number,
	z: number,
}
export type Entry = { kind: "predicted" | "accepted" | "terminal", untilTime: number, timeline: Timeline? }
export type State = {
	policy: Policy,
	entries: { [string]: Entry },
	lastNow: number,
	destroyed: boolean,
	cancelledThrough: number,
}
export type Change = { key: string, action: "clear" }
export type Result = { action: "predict" | "adopt" | "start" | "clear" | "ignore" | "refuse", timeline: Timeline? }
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function validKey(key: string): boolean
	return #key > 0 and #key <= 256
end
local function result(
	action: "predict" | "adopt" | "start" | "clear" | "ignore" | "refuse",
	timeline: Timeline?
): Result
	return { action = action, timeline = timeline }
end
function CastPresentation.new(policy: Policy): State
	assert(finite(policy.capacity) and policy.capacity % 1 == 0 and policy.capacity >= 1, "invalid capacity")
	assert(finite(policy.predictionSeconds) and policy.predictionSeconds > 0, "invalid prediction timeout")
	assert(finite(policy.tombstoneSeconds) and policy.tombstoneSeconds > 0, "invalid terminal TTL")
	assert(
		finite(policy.maxLifetimeSeconds)
			and policy.maxLifetimeSeconds > 0
			and policy.maxLifetimeSeconds <= policy.tombstoneSeconds,
		"terminal TTL must cover max lifetime"
	)
	return {
		policy = table.freeze(table.clone(policy)),
		entries = {},
		lastNow = -math.huge,
		destroyed = false,
		cancelledThrough = -math.huge,
	}
end
local function clock(s: State, now: number): boolean
	if s.destroyed or not finite(now) or now < s.lastNow then
		return false
	end
	s.lastNow = now
	return true
end
local function room(s: State): boolean
	local count = 0
	for _ in s.entries do
		count += 1
	end
	return count < s.policy.capacity
end
local function valid(t: Timeline): boolean
	return finite(t.acceptedAt)
		and finite(t.releaseAt)
		and finite(t.endsAt)
		and finite(t.x)
		and finite(t.y)
		and finite(t.z)
		and t.acceptedAt <= t.releaseAt
		and t.releaseAt <= t.endsAt
end

-- Call each frame BEFORE event reduction and consume every returned clear. Explicit outbox avoids
-- losing cleanup when another event arrives. Full capacity refuses newcomers; never evicts live tells.
function CastPresentation.tick(s: State, now: number): { Change }?
	if not clock(s, now) then
		return nil
	end
	local clears: { Change } = {}
	for key, entry in s.entries do
		if now >= entry.untilTime then
			if entry.kind == "predicted" then
				s.entries[key] = nil -- late acceptance may still start remaining authoritative phase
				table.insert(clears, { key = key, action = "clear" })
			elseif entry.kind == "accepted" then
				s.entries[key] = { kind = "terminal", untilTime = now + s.policy.tombstoneSeconds }
				table.insert(clears, { key = key, action = "clear" })
			else
				s.entries[key] = nil
			end
		end
	end
	return clears
end

function CastPresentation.predict(s: State, key: string, now: number): Result
	if not validKey(key) or not clock(s, now) then
		return result("refuse")
	end
	if s.entries[key] then
		return result("ignore")
	end
	if not room(s) then
		return result("refuse")
	end
	s.entries[key] = { kind = "predicted", untilTime = now + s.policy.predictionSeconds }
	return result("predict")
end

function CastPresentation.accept(s: State, key: string, timeline: Timeline, now: number): Result
	if
		not validKey(key)
		or not valid(timeline)
		or timeline.acceptedAt > now
		or timeline.endsAt - timeline.acceptedAt > s.policy.maxLifetimeSeconds
		or not clock(s, now)
	then
		return result("refuse")
	end
	local entry = s.entries[key]
	if timeline.acceptedAt <= s.cancelledThrough then
		-- On unknown-cancellation overflow, conservatively suppress all delayed starts from that
		-- epoch; one watermark bounds memory and prevents later resurrection when capacity frees.
		if entry and entry.kind == "predicted" then
			s.entries[key] = { kind = "terminal", untilTime = now + s.policy.tombstoneSeconds }
			return result("clear")
		end
		return result("ignore")
	end
	if entry and entry.kind ~= "predicted" then
		return result("ignore") -- duplicate or terminal; must not restart pose/contacts
	end
	if not entry and not room(s) then
		return result("refuse")
	end
	if now >= timeline.endsAt then
		s.entries[key] = { kind = "terminal", untilTime = now + s.policy.tombstoneSeconds }
		return result(if entry then "clear" else "ignore")
	end
	local accepted = table.freeze(table.clone(timeline))
	s.entries[key] = { kind = "accepted", untilTime = timeline.endsAt, timeline = accepted }
	return result(if entry then "adopt" else "start", accepted)
end

-- Explicit rejection/server cancellation, NOT local caster death/slot changes for accepted X hazards.
-- Unknown cancel records a tombstone (reordered cancel-before-accept). Duplicates do not extend TTL.
function CastPresentation.cancel(s: State, key: string, now: number): Result
	if not validKey(key) or not clock(s, now) then
		return result("refuse")
	end
	local entry = s.entries[key]
	if entry and entry.kind == "terminal" then
		return result("ignore")
	end
	if not entry and not room(s) then
		s.cancelledThrough = math.max(s.cancelledThrough, now)
		return result("refuse")
	end
	s.entries[key] = { kind = "terminal", untilTime = now + s.policy.tombstoneSeconds }
	return result(if entry then "clear" else "ignore")
end

-- Remaining pose/travel phase only. Never emits old impacts or schedules damage.
function CastPresentation.phase(t: Timeline, now: number): (string, number)
	if not valid(t) or not finite(now) then
		return "invalid", 0
	elseif now < t.acceptedAt then
		return "waiting", 0
	elseif now < t.releaseAt then
		return "warning", (now - t.acceptedAt) / (t.releaseAt - t.acceptedAt)
	elseif now < t.endsAt then
		return "active", (now - t.releaseAt) / (t.endsAt - t.releaseAt)
	end
	return "expired", 1
end

function CastPresentation.destroy(s: State): { Change }
	local clears: { Change } = {}
	for key, entry in s.entries do
		if entry.kind ~= "terminal" then
			table.insert(clears, { key = key, action = "clear" })
		end
	end
	s.destroyed = true
	s.entries = {} -- discard this reducer on connection/generation disposal, never reuse its identity
	return clears
end
return CastPresentation
