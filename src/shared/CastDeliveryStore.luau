--!strict
-- Bounded immutable metadata pinned to ONE outer warning gate's live identities.
-- Stage before admission; prune AFTER gate operations. No clock or receipt authority.
local Map = require("./CastCommandMap")
local Plan = require("./CastDeliveryPlan")
local WarningGate = require("./CastWarningGate")
local Store = {}
export type Entry = { identity: Plan.Identity, accepted: Map.Accepted? }
export type State = { capacity: number, count: number, entries: { [string]: Entry }, closed: boolean }
local function same(a: Plan.Identity, b: Plan.Identity): boolean
	return a.generation == b.generation
		and a.characterKey == b.characterKey
		and a.casterUserId == b.casterUserId
		and a.slotRevision == b.slotRevision
end
local function identity(value: Plan.Identity): Plan.Identity
	return table.freeze({
		generation = value.generation,
		characterKey = value.characterKey,
		casterUserId = value.casterUserId,
		slotRevision = value.slotRevision,
	})
end
local function finiteInteger(n: number): boolean
	return n == n and n >= 0 and n < math.huge and n % 1 == 0
end
local function valid(key: string, value: Plan.Identity): boolean
	return #key > 0
		and #key <= 256
		and #value.generation > 0
		and #value.generation <= 64
		and #value.characterKey > 0
		and #value.characterKey <= 128
		and finiteInteger(value.slotRevision)
		and finiteInteger(value.casterUserId)
end
function Store.new(capacity: number): State
	assert(finiteInteger(capacity) and capacity >= 1, "invalid metadata capacity")
	return { capacity = capacity, count = 0, entries = {}, closed = false }
end
function Store.predict(s: State, key: string, value: Plan.Identity): string
	if s.closed or not valid(key, value) then
		return "refuse"
	end
	local old = s.entries[key]
	if old then
		return if same(old.identity, value) then "duplicate" else "conflict"
	end
	if s.count >= s.capacity then
		return "refuse"
	end
	s.entries[key] = table.freeze({ identity = identity(value), accepted = nil })
	s.count += 1
	return "stored"
end
-- Only validated CastCommandMap output crosses this boundary. Never raw packets.
function Store.accept(s: State, command: Map.Accepted): string
	local a, key = command.metadata.acceptance, command.key
	if s.closed or key ~= a.castId or not valid(key, a) then
		return "refuse"
	end
	local old = s.entries[key]
	if old then
		if not same(old.identity, a) then
			return "conflict"
		end
		if old.accepted then
			return if old.accepted.metadata.acceptance == a then "duplicate" else "conflict"
		end
	elseif s.count >= s.capacity then
		return "refuse"
	end
	if not old then
		s.count += 1
	end
	s.entries[key] = table.freeze({ identity = if old then old.identity else identity(a), accepted = command })
	return "stored"
end
function Store.get(s: State, key: string): Entry?
	return if s.closed then nil else s.entries[key]
end
local function live(gate: WarningGate.State, key: string): boolean
	if gate.closed then
		return false
	end
	if gate.gate.pending[key] then
		return true
	end
	local primary = gate.gate.bridge.presentation.entries[key]
	local reserve = gate.reserve.bridge.presentation.entries[key]
	return (primary ~= nil and primary.kind ~= "terminal") or (reserve ~= nil and reserve.kind ~= "terminal")
end
function Store.prune(s: State, gate: WarningGate.State)
	if s.closed then
		return
	end
	for key in s.entries do
		if not live(gate, key) then
			s.entries[key] = nil
			s.count -= 1
		end
	end
end
function Store.destroy(s: State)
	s.closed = true
	table.clear(s.entries)
	s.count = 0
end
return Store
