--!strict
-- Confirmed-effect receipts only. Acceptance/terminal order never gates these records.
-- No rendering, damage or client hit authority. Overload may drop visuals, never gameplay.
local CastContacts = require("./CastContacts")
local CastContactInbox = {}
export type Policy = { capacity: number, retentionSeconds: number, futureSeconds: number }
export type Entry = { value: CastContacts.Contact, identity: string, expiresAt: number, order: number }
export type State = {
	policy: Policy,
	entries: { [string]: Entry },
	identities: { [string]: string },
	count: number,
	serial: number,
	lastNow: number,
	retiredThrough: number,
	closed: boolean,
}
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function integer(n: number, max: number): boolean
	return finite(n) and n >= 1 and n <= max and n % 1 == 0
end
local function text(s: any, max: number): boolean
	return type(s) == "string" and #s > 0 and #s <= max
end
local function vector(v: CastContacts.Vec): boolean
	return type(v) == "table" and finite(v.x) and finite(v.y) and finite(v.z)
end
local function prefix(castId: string): string
	return tostring(#castId) .. ":" .. castId .. ":"
end
function CastContactInbox.new(policy: Policy, retiredThrough: number?): State
	assert(integer(policy.capacity, 65535), "invalid contact inbox capacity")
	assert(finite(policy.retentionSeconds) and policy.retentionSeconds > 0, "invalid contact retention")
	assert(finite(policy.futureSeconds) and policy.futureSeconds >= 0, "invalid contact clock tolerance")
	assert(retiredThrough == nil or finite(retiredThrough), "invalid contact retirement watermark")
	return {
		policy = table.freeze(table.clone(policy)),
		entries = {},
		identities = {},
		count = 0,
		serial = 0,
		lastNow = -math.huge,
		retiredThrough = retiredThrough or -math.huge,
		closed = false,
	}
end
local function retire(s: State, key: string, entry: Entry)
	s.retiredThrough = math.max(s.retiredThrough, entry.value.at)
	s.identities[entry.identity] = nil
	s.entries[key] = nil
	s.count -= 1
end
function CastContactInbox.prune(s: State, now: number): boolean
	if s.closed or not finite(now) or now < s.lastNow then
		return false
	end
	s.lastNow = now
	for key, entry in s.entries do
		if now >= entry.expiresAt then
			retire(s, key, entry)
		end
	end
	return true
end
function CastContactInbox.record(s: State, value: CastContacts.Contact, now: number, serverNow: number): string
	if
		not finite(serverNow)
		or not finite(value.at)
		or not text(value.castId, 70)
		or not integer(value.ordinal, 65535)
		or not integer(value.resource, 16)
		or not integer(value.tick, 65535)
		or not text(value.targetKey, 128)
		or not finite(value.amount)
		or value.amount < 0
		or not vector(value.position)
		or not vector(value.direction)
		or not CastContactInbox.prune(s, now)
	then
		return "invalid"
	end
	local key = prefix(value.castId) .. tostring(value.ordinal)
	local identity = prefix(value.castId) .. value.resource .. ":" .. value.tick .. ":" .. value.targetKey
	local previous = s.entries[key]
	if previous then
		return if previous.identity == identity then "duplicate" else "conflict"
	end
	if s.identities[identity] then
		return "conflict"
	end
	if value.at <= s.retiredThrough or value.at <= serverNow - s.policy.retentionSeconds then
		return "expired"
	end
	if value.at > serverNow + s.policy.futureSeconds then
		return "invalid"
	end
	if s.count >= s.policy.capacity then
		local oldest, order = nil, math.huge
		for k, entry in s.entries do
			if entry.order < order then
				oldest, order = k, entry.order
			end
		end
		if oldest then
			retire(s, oldest, s.entries[oldest])
		end
		-- Eviction can advance the watermark past this delayed incoming contact.
		if value.at <= s.retiredThrough then
			return "expired"
		end
	end
	local copy = table.clone(value)
	copy.position = table.freeze(table.clone(value.position))
	copy.direction = table.freeze(table.clone(value.direction))
	s.serial += 1
	s.entries[key] = table.freeze({
		value = table.freeze(copy),
		identity = identity,
		expiresAt = now + s.policy.retentionSeconds,
		order = s.serial,
	})
	s.identities[identity] = key
	s.count += 1
	return "stored"
end
function CastContactInbox.get(s: State, castId: string, ordinal: number): Entry?
	return s.entries[prefix(castId) .. tostring(ordinal)]
end
function CastContactInbox.destroy(s: State)
	for key, entry in s.entries do
		retire(s, key, entry)
	end
	s.closed = true
end
return CastContactInbox
