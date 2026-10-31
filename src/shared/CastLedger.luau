--!strict
-- T-043c0a1: pure, bounded admission ledger. NOT wired to live CastRequest yet.
-- One server-owned generation per character/connection, shared by BOTH input senders.
-- Reserve before any yielding/payment; complete exactly once with an immutable response receipt.
-- Caller validates payload and computes a canonical fingerprint; this module never authorizes gameplay.
local CastLedger = {}
local MOD = 65536
local HALF = MOD / 2

export type Policy = { capacity: number, maxAdvance: number, responseSeconds: number }
export type Receipt = { status: "accepted" | "rejected", castId: string?, reason: string? }
export type Entry = {
	seq: number,
	fingerprint: string,
	expiresAt: number,
	receipt: Receipt?,
}
export type State = {
	generation: string,
	policy: Policy,
	lastSeq: number?,
	distance: number,
	lastNow: number,
	entries: { [number]: Entry },
}
export type Result = {
	kind: "reserved" | "duplicate" | "pending" | "rejected",
	reason: string?,
	entry: Entry?,
	receipt: Receipt?,
}

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function integer(n: number): boolean
	return finite(n) and n == math.floor(n)
end
local function text(s: string?, max: number): boolean
	return s ~= nil and #s > 0 and #s <= max
end
local function reject(reason: string): Result
	return { kind = "rejected", reason = reason }
end

function CastLedger.new(generation: string, policy: Policy): State
	assert(text(generation, 64), "invalid server generation")
	assert(integer(policy.capacity) and policy.capacity >= 1 and policy.capacity < HALF, "invalid capacity")
	assert(integer(policy.maxAdvance) and policy.maxAdvance >= 1 and policy.maxAdvance < HALF, "invalid advance")
	assert(finite(policy.responseSeconds) and policy.responseSeconds > 0, "invalid response lifetime")
	return {
		generation = generation,
		policy = table.freeze(table.clone(policy)),
		lastSeq = nil,
		distance = 0,
		lastNow = -math.huge,
		entries = {},
	}
end

-- No allocation on rejected input. Expired responses disappear; watermark survives expiry/eviction.
local function sweep(s: State, now: number): boolean
	if not finite(now) or now < s.lastNow then
		return false
	end
	s.lastNow = now
	for seq, entry in s.entries do
		if now >= entry.expiresAt then
			s.entries[seq] = nil
		end
	end
	return true
end

function CastLedger.reserve(s: State, generation: string, seq: number, fingerprint: string, now: number): Result
	if generation ~= s.generation then
		return reject("generation")
	end
	if not integer(seq) or seq < 0 or seq >= MOD or not text(fingerprint, 256) then
		return reject("malformed")
	end
	if not sweep(s, now) then
		return reject("clock")
	end
	local previous = s.entries[seq]
	if previous then
		if previous.fingerprint ~= fingerprint then
			return reject("payload_changed")
		end
		if previous.receipt then
			return { kind = "duplicate", receipt = previous.receipt }
		end
		return { kind = "pending" }
	end
	local advance = 0
	if s.lastSeq ~= nil then
		advance = (seq - s.lastSeq) % MOD
		if advance == 0 or advance >= HALF then
			return reject("stale")
		end
		if advance > s.policy.maxAdvance then
			return reject("jump")
		end
		-- Never traverse half the u16 space in one generation. Renew server generation before this
		-- boundary; otherwise an ancient pre-wrap packet could eventually look like fresh input.
		if s.distance + advance >= HALF then
			return reject("rotate_generation")
		end
	end
	local count, oldestSeq, oldestTime = 0, nil, math.huge
	for key, entry in s.entries do
		count += 1
		if
			entry.expiresAt < oldestTime or (entry.expiresAt == oldestTime and (oldestSeq == nil or key < oldestSeq))
		then
			oldestSeq, oldestTime = key, entry.expiresAt
		end
	end
	if count >= s.policy.capacity and oldestSeq ~= nil then
		s.entries[oldestSeq] = nil
	end
	local entry: Entry = { seq = seq, fingerprint = fingerprint, expiresAt = now + s.policy.responseSeconds }
	s.entries[seq] = entry
	s.lastSeq = seq
	s.distance += advance
	return { kind = "reserved", entry = entry }
end

-- The exact reservation object is a server-local capability, never something received from a client.
-- Expired/evicted/past-generation handles cannot complete. Duplicate completion cannot change a verdict.
function CastLedger.complete(s: State, entry: Entry, receipt: Receipt, now: number): boolean
	if not sweep(s, now) or s.entries[entry.seq] ~= entry or entry.receipt ~= nil then
		return false
	end
	if receipt.status == "accepted" then
		if not text(receipt.castId, 128) or receipt.reason ~= nil then
			return false
		end
	elseif receipt.status == "rejected" then
		if not text(receipt.reason, 64) or receipt.castId ~= nil then
			return false
		end
	else
		return false
	end
	entry.receipt = table.freeze(table.clone(receipt))
	return true
end

-- Explicit tick is optional: reserve/complete also prune. Returns count for bounded-resource checks.
function CastLedger.prune(s: State, now: number): number?
	if not sweep(s, now) then
		return nil
	end
	local count = 0
	for _ in s.entries do
		count += 1
	end
	return count
end

return CastLedger
