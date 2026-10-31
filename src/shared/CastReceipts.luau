--!strict
-- Pure bounded authoritative acceptance/terminal records. NOT admission: cache
-- misses/eviction NEVER grant permission to pay or execute a cast again.
local CastReceipts = {}
export type Vec = { x: number, y: number, z: number }
export type Acceptance = {
	castId: string,
	generation: string,
	seq: number,
	moveId: string,
	casterUserId: number,
	characterKey: string,
	slotRevision: number,
	acceptedAt: number,
	releaseAt: number,
	endsAt: number,
	aim: Vec,
	origin: Vec,
	centre: Vec?,
}
export type Terminal = { reason: string, at: number }
export type Entry = { acceptance: Acceptance?, terminal: Terminal?, expiresAt: number, order: number }
export type Policy = { capacity: number, responseSeconds: number, tombstoneSeconds: number, maxLifetimeSeconds: number }
export type State = { policy: Policy, entries: { [string]: Entry }, lastNow: number, serial: number, closed: boolean }
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function integer(n: any, max: number): boolean
	return finite(n) and n >= 0 and n % 1 == 0 and n <= max
end
local function text(s: any, max: number): boolean
	return type(s) == "string" and #s > 0 and #s <= max
end
local function vector(v: any): boolean
	return type(v) == "table" and finite(v.x) and finite(v.y) and finite(v.z)
end
local function copyVector(v: Vec): Vec
	return table.freeze({ x = v.x, y = v.y, z = v.z })
end
local function valid(a: Acceptance, policy: Policy): boolean
	return text(a.generation, 64)
		and integer(a.seq, 65535)
		and a.castId == a.generation .. ":" .. tostring(a.seq)
		and text(a.moveId, 64)
		and integer(a.casterUserId, 9007199254740991)
		and text(a.characterKey, 64)
		and integer(a.slotRevision, 4294967295)
		and finite(a.acceptedAt)
		and finite(a.releaseAt)
		and finite(a.endsAt)
		and a.acceptedAt <= a.releaseAt
		and a.releaseAt <= a.endsAt
		and a.endsAt - a.acceptedAt <= policy.maxLifetimeSeconds
		and vector(a.aim)
		and vector(a.origin)
		and (a.centre == nil or vector(a.centre))
end
local function copy(a: Acceptance): Acceptance
	return table.freeze({
		castId = a.castId,
		generation = a.generation,
		seq = a.seq,
		moveId = a.moveId,
		casterUserId = a.casterUserId,
		characterKey = a.characterKey,
		slotRevision = a.slotRevision,
		acceptedAt = a.acceptedAt,
		releaseAt = a.releaseAt,
		endsAt = a.endsAt,
		aim = copyVector(a.aim),
		origin = copyVector(a.origin),
		centre = if a.centre then copyVector(a.centre) else nil,
	})
end
local function sameVector(a: Vec?, b: Vec?): boolean
	if not a or not b then
		return a == b
	end
	return a.x == b.x and a.y == b.y and a.z == b.z
end
local function same(a: Acceptance, b: Acceptance): boolean
	return a.castId == b.castId
		and a.generation == b.generation
		and a.seq == b.seq
		and a.moveId == b.moveId
		and a.casterUserId == b.casterUserId
		and a.characterKey == b.characterKey
		and a.slotRevision == b.slotRevision
		and a.acceptedAt == b.acceptedAt
		and a.releaseAt == b.releaseAt
		and a.endsAt == b.endsAt
		and sameVector(a.aim, b.aim)
		and sameVector(a.origin, b.origin)
		and sameVector(a.centre, b.centre)
end
function CastReceipts.new(policy: Policy): State
	assert(integer(policy.capacity, 32767) and policy.capacity > 0, "invalid capacity")
	assert(finite(policy.responseSeconds) and policy.responseSeconds > 0, "invalid response TTL")
	assert(finite(policy.maxLifetimeSeconds) and policy.maxLifetimeSeconds > 0, "invalid max lifetime")
	assert(
		finite(policy.tombstoneSeconds)
			and policy.tombstoneSeconds >= math.max(policy.maxLifetimeSeconds, policy.responseSeconds),
		"short tombstone TTL"
	)
	return { policy = table.freeze(table.clone(policy)), entries = {}, lastNow = -math.huge, serial = 0, closed = false }
end
-- Monotonic cache time is independent of server wall-clock presentation times.
function CastReceipts.prune(s: State, now: number): boolean
	if s.closed or not finite(now) or now < s.lastNow then
		return false
	end
	s.lastNow = now
	for key, entry in s.entries do
		if entry.expiresAt <= now then
			s.entries[key] = nil
		end
	end
	return true
end
local function room(s: State)
	local count, oldestKey, oldestOrder = 0, nil, math.huge
	for key, entry in s.entries do
		count += 1
		if entry.order < oldestOrder then
			oldestKey, oldestOrder = key, entry.order
		end
	end
	if count >= s.policy.capacity and oldestKey then
		s.entries[oldestKey] = nil
	end
end
function CastReceipts.put(s: State, acceptance: Acceptance, now: number): string
	if not valid(acceptance, s.policy) or not CastReceipts.prune(s, now) then
		return "invalid"
	end
	local key = acceptance.castId
	local previous = s.entries[key]
	if previous then
		if previous.terminal then
			return "terminal"
		end
		return if previous.acceptance and same(previous.acceptance, acceptance) then "duplicate" else "conflict"
	end
	room(s)
	s.serial += 1
	s.entries[key] = table.freeze({
		acceptance = copy(acceptance),
		terminal = nil,
		expiresAt = now + math.max(s.policy.responseSeconds, acceptance.endsAt - acceptance.acceptedAt),
		order = s.serial,
	})
	return "stored"
end
function CastReceipts.get(s: State, key: string, now: number): Entry?
	if not CastReceipts.prune(s, now) then
		return nil
	end
	return s.entries[key]
end
-- First terminal wins; duplicates cannot extend TTL or replace the original cause/time.
function CastReceipts.terminate(s: State, key: string, reason: string, at: number, now: number): string
	if not text(key, 70) or not text(reason, 64) or not finite(at) or not CastReceipts.prune(s, now) then
		return "invalid"
	end
	local previous = s.entries[key]
	if previous and previous.terminal then
		return "duplicate"
	end
	if previous and previous.acceptance and at < previous.acceptance.acceptedAt then
		return "invalid"
	end
	if not previous then
		room(s)
	end
	s.serial += 1
	s.entries[key] = table.freeze({
		acceptance = if previous then previous.acceptance else nil,
		terminal = table.freeze({ reason = reason, at = at }),
		expiresAt = now + s.policy.tombstoneSeconds,
		order = s.serial,
	})
	return "stored"
end
function CastReceipts.destroy(s: State)
	table.clear(s.entries)
	s.closed = true
end
return CastReceipts
