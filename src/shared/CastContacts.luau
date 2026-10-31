--!strict
-- Post-damage notification ledger only. NEVER use its result to authorize/apply damage.
-- One ledger per world lifetime; no Player/Instance references and no network side effects.
local CastContacts = {}
export type Vec = { x: number, y: number, z: number }
export type Input = {
	resource: number,
	tick: number,
	targetKey: string,
	at: number,
	position: Vec,
	direction: Vec,
	amount: number,
}
export type Contact = {
	castId: string,
	ordinal: number,
	resource: number,
	tick: number,
	targetKey: string,
	at: number,
	position: Vec,
	direction: Vec,
	amount: number,
}
export type State = {
	castId: string,
	resources: number,
	acceptedAt: number,
	lastAt: number,
	capacity: number,
	count: number,
	closed: boolean,
	entries: { [string]: Contact },
}
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function integer(n: number, max: number): boolean
	return finite(n) and n >= 1 and n <= max and n % 1 == 0
end
local function vector(v: Vec): boolean
	return finite(v.x) and finite(v.y) and finite(v.z)
end
function CastContacts.new(castId: string, resources: number, acceptedAt: number, capacity: number): State
	assert(#castId > 0 and #castId <= 70, "invalid cast identity")
	assert(integer(resources, 16) and finite(acceptedAt), "invalid cast lifetime")
	assert(integer(capacity, 65535), "invalid contact capacity")
	return {
		castId = castId,
		resources = resources,
		acceptedAt = acceptedAt,
		lastAt = acceptedAt,
		capacity = capacity,
		count = 0,
		closed = false,
		entries = {},
	}
end
-- Caller supplies a successful authoritative contact AFTER damage/effects. Zero damage is
-- valid (e.g. status-only contact). A full ledger drops notification only, never gameplay.
-- Times are paired server contact times in nondecreasing processing order, not client time.
function CastContacts.record(s: State, input: Input): (string, Contact?)
	if s.closed then
		return "closed", nil
	end
	if
		not integer(input.resource, s.resources)
		or not integer(input.tick, 65535)
		or #input.targetKey == 0
		or #input.targetKey > 128
		or not finite(input.at)
		or input.at < s.acceptedAt
		or not finite(input.amount)
		or input.amount < 0
		or not vector(input.position)
		or not vector(input.direction)
	then
		return "invalid", nil
	end
	local key = tostring(input.resource) .. ":" .. tostring(input.tick) .. ":" .. input.targetKey
	local previous = s.entries[key]
	if previous then
		return "duplicate", previous -- immutable original, even with changed payload/time
	end
	if input.at < s.lastAt then
		return "invalid", nil
	end
	if s.count >= s.capacity then
		return "full", nil -- never evict: old identities must not be re-emitted
	end
	local record: Contact = table.freeze({
		castId = s.castId,
		ordinal = s.count + 1,
		resource = input.resource,
		tick = input.tick,
		targetKey = input.targetKey,
		at = input.at,
		amount = input.amount,
		position = table.freeze(table.clone(input.position)),
		direction = table.freeze(table.clone(input.direction)),
	})
	s.entries[key], s.count, s.lastAt = record, record.ordinal, input.at
	return "stored", record
end
-- Terminal ownership closes the ledger; queued callbacks cannot allocate or emit again.
-- Existing returned records stay immutable for a network adapter's pending serialization.
function CastContacts.close(s: State)
	s.closed = true
	table.clear(s.entries)
end
return CastContacts
