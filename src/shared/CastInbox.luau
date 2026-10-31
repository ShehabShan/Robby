--!strict
-- Receipt inbox only: no prediction, rendering, cancellation or gameplay authority.
local CastReceipts = require("./CastReceipts")
local CastInbox = {}
export type Disposition = { generation: string, seq: number, moveId: string, status: string, reason: string }
export type Response = { value: Disposition, expiresAt: number, order: number }
export type State = {
	acceptances: CastReceipts.State,
	responses: { [string]: Response },
	serial: number,
	retiredThrough: number,
}
function CastInbox.new(policy: CastReceipts.Policy): State
	return { acceptances = CastReceipts.new(policy), responses = {}, serial = 0, retiredThrough = -math.huge }
end
-- A retired tombstone leaves one conservative server-time watermark. Under cache
-- pressure this may suppress unrelated OLD unseen casts, never revive a known ended one.
local function retire(s: State, entry: CastReceipts.Entry?)
	if entry and entry.terminal then
		s.retiredThrough = math.max(s.retiredThrough, entry.terminal.at)
	end
end
local function oldestReceipt(s: State): (string?, CastReceipts.Entry?)
	local key, entry, order = nil, nil, math.huge
	for k, e in s.acceptances.entries do
		if e.order < order then
			key, entry, order = k, e, e.order
		end
	end
	return key, entry
end
local function afterInsert(s: State, key: string?, entry: CastReceipts.Entry?)
	if key and not s.acceptances.entries[key] then
		retire(s, entry)
	end
end
function CastInbox.prune(s: State, now: number): boolean
	if s.acceptances.closed or now ~= now or math.abs(now) == math.huge or now < s.acceptances.lastNow then
		return false
	end
	for _, entry in s.acceptances.entries do
		if entry.expiresAt <= now then
			retire(s, entry)
		end
	end
	if not CastReceipts.prune(s.acceptances, now) then
		return false
	end
	for key, response in s.responses do
		if response.expiresAt <= now then
			s.responses[key] = nil
		end
	end
	return true
end
function CastInbox.accept(
	s: State,
	value: CastReceipts.Acceptance,
	now: number,
	serverNow: number?,
	grace: number?
): string
	if not CastInbox.prune(s, now) then
		return "invalid"
	end
	local response = s.responses[value.castId]
	-- Expired is not rejection/cancellation. A late genuine acceptance can still arrive.
	if response and response.value.status == "rejected" then
		return "rejected"
	end
	if value.acceptedAt <= s.retiredThrough and not s.acceptances.entries[value.castId] then
		return "terminal"
	end
	-- Server wall time only; monotonic local time is solely for cache retention.
	if serverNow and serverNow >= value.endsAt + (grace or 0) then
		return "expired"
	end
	local key, entry = oldestReceipt(s)
	local result = CastReceipts.put(s.acceptances, value, now)
	afterInsert(s, key, entry)
	if result == "stored" or result == "duplicate" then
		s.responses[value.castId] = nil
	end
	return result
end
function CastInbox.terminal(s: State, key: string, reason: string, at: number, now: number): string
	if not CastInbox.prune(s, now) then
		return "invalid"
	end
	local oldKey, entry = oldestReceipt(s)
	local result = CastReceipts.terminate(s.acceptances, key, reason, at, now)
	afterInsert(s, oldKey, entry)
	if result == "stored" or result == "duplicate" then
		s.responses[key] = nil
	end
	return result
end
local function text(s: any, max: number): boolean
	return type(s) == "string" and #s > 0 and #s <= max
end
function CastInbox.disposition(s: State, value: Disposition, now: number): string
	if
		not text(value.generation, 64)
		or not text(value.moveId, 64)
		or not text(value.reason, 64)
		or type(value.seq) ~= "number"
		or value.seq ~= value.seq
		or value.seq < 0
		or value.seq > 65535
		or value.seq % 1 ~= 0
		or (value.status ~= "rejected" and value.status ~= "expired")
		or not CastInbox.prune(s, now)
	then
		return "invalid"
	end
	local key = value.generation .. ":" .. tostring(value.seq)
	if CastReceipts.get(s.acceptances, key, now) then
		return "accepted"
	end
	if s.responses[key] then
		return "duplicate"
	end -- never refresh TTL on repeat
	local count, oldest, order = 0, nil, math.huge
	for k, entry in s.responses do
		count += 1
		if entry.order < order then
			oldest, order = k, entry.order
		end
	end
	if count >= s.acceptances.policy.capacity and oldest then
		s.responses[oldest] = nil
	end
	s.serial += 1
	s.responses[key] = {
		value = table.freeze(table.clone(value)),
		expiresAt = now + s.acceptances.policy.responseSeconds,
		order = s.serial,
	}
	return "stored"
end
function CastInbox.destroy(s: State)
	CastReceipts.destroy(s.acceptances)
	table.clear(s.responses)
end
return CastInbox
