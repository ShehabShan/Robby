--!strict
-- Receipt inbox only: no prediction, rendering, cancellation or gameplay authority.
local CastReceipts = require("./CastReceipts")
local CastInbox = {}
export type Disposition = { generation: string, seq: number, moveId: string, status: string, reason: string }
export type Response = { value: Disposition, expiresAt: number, order: number }
export type State = { acceptances: CastReceipts.State, responses: { [string]: Response }, serial: number }
function CastInbox.new(policy: CastReceipts.Policy): State
	return { acceptances = CastReceipts.new(policy), responses = {}, serial = 0 }
end
function CastInbox.prune(s: State, now: number): boolean
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
function CastInbox.accept(s: State, value: CastReceipts.Acceptance, now: number): string
	if not CastInbox.prune(s, now) then
		return "invalid"
	end
	local response = s.responses[value.castId]
	-- Expired is not rejection/cancellation. A late genuine acceptance can still arrive.
	if response and response.value.status == "rejected" then
		return "rejected"
	end
	local result = CastReceipts.put(s.acceptances, value, now)
	if result == "stored" or result == "duplicate" then
		s.responses[value.castId] = nil
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
