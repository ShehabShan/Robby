--!strict
-- T-043c0b3a: pure replay boundary. Engine wiring/receipts remain b3b/b3c.
-- The adapter supplies a never-reused server scope and invokes only synchronous,
-- non-throwing authorization. This is NOT rollback for engine side effects.
local CastLedger = require("./CastLedger")

export type Vec = { x: number, y: number, z: number }
export type Request = { generation: string, seq: number, moveId: string, aim: Vec, point: Vec? }
export type Policy = { capacity: number, maxAdvance: number, responseSeconds: number, renewDistance: number }
export type State = {
	scope: string,
	epoch: number,
	ledger: CastLedger.State,
	policy: Policy,
	busy: boolean,
	closed: boolean,
}
export type Result = { kind: string, reason: string?, receipt: CastLedger.Receipt?, generation: string, renew: boolean }
local CastAdmission = {}
local MAX_EPOCH = 4294967295

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function vector(v: any): Vec?
	if type(v) ~= "table" or not finite(v.x) or not finite(v.y) or not finite(v.z) then
		return nil
	end
	return table.freeze({
		x = if v.x == 0 then 0 else v.x,
		y = if v.y == 0 then 0 else v.y,
		z = if v.z == 0 then 0 else v.z,
	})
end

-- Copy only validated intent. Numeric encoding is lossless for DECODED wire values;
-- no decimal rounding/hash collisions. Sender/receiver must use the same schema.
function CastAdmission.canonical(raw: any): (Request?, string?)
	if
		type(raw) ~= "table"
		or type(raw.generation) ~= "string"
		or #raw.generation == 0
		or #raw.generation > 64
		or type(raw.moveId) ~= "string"
		or #raw.moveId == 0
		or #raw.moveId > 64
		or not finite(raw.seq)
		or raw.seq % 1 ~= 0
		or raw.seq < 0
		or raw.seq >= 65536
	then
		return nil, nil
	end
	local aim = vector(raw.aim)
	local point = if raw.point ~= nil then vector(raw.point) else nil
	if not aim or (raw.point ~= nil and not point) then
		return nil, nil
	end
	local size = 1 + #raw.moveId + 24 + 1 + (if point then 24 else 0)
	local bytes = buffer.create(size)
	buffer.writeu8(bytes, 0, #raw.moveId)
	buffer.writestring(bytes, 1, raw.moveId)
	local offset = 1 + #raw.moveId
	local function write(v: Vec)
		buffer.writef64(bytes, offset, v.x)
		buffer.writef64(bytes, offset + 8, v.y)
		buffer.writef64(bytes, offset + 16, v.z)
		offset += 24
	end
	write(aim)
	buffer.writeu8(bytes, offset, if point then 1 else 0)
	offset += 1
	if point then
		write(point)
	end
	local request: Request =
		{ generation = raw.generation, seq = raw.seq, moveId = raw.moveId, aim = aim, point = point }
	-- generation + seq are the ledger key, not ambiguous parts of this fingerprint.
	return table.freeze(request), buffer.tostring(bytes)
end

function CastAdmission.new(scope: string, policy: Policy): State
	assert(#scope > 0 and #scope <= 40 and scope:match("^[%w_-]+$"), "invalid server scope")
	assert(
		finite(policy.renewDistance)
			and policy.renewDistance % 1 == 0
			and policy.renewDistance > policy.maxAdvance
			and policy.renewDistance + policy.maxAdvance < 32768,
		"invalid renewal distance"
	)
	return {
		scope = scope,
		epoch = 1,
		ledger = CastLedger.new(scope .. ":1", policy),
		policy = table.freeze(table.clone(policy)),
		busy = false,
		closed = false,
	}
end

-- Only server character changes or server-determined renewal call this. Never a
-- client-supplied epoch. Old traffic is rejected outright; epochs never reused.
function CastAdmission.rotate(s: State): string?
	if s.busy or s.closed or s.epoch >= MAX_EPOCH then
		return nil
	end
	s.epoch += 1
	s.ledger = CastLedger.new(s.scope .. ":" .. tostring(s.epoch), s.policy)
	return s.ledger.generation
end

function CastAdmission.dispatch(
	s: State,
	raw: any,
	now: number,
	authorize: (Request, string) -> (boolean, string?)
): Result
	local function result(kind: string, reason: string?, receipt: CastLedger.Receipt?): Result
		return {
			kind = kind,
			reason = reason,
			receipt = receipt,
			generation = s.ledger.generation,
			renew = s.ledger.distance >= s.policy.renewDistance,
		}
	end
	if s.closed then
		return result("rejected", "closed", nil)
	end
	if s.busy then
		return result("rejected", "busy", nil)
	end
	local request, fingerprint = CastAdmission.canonical(raw)
	if not request or not fingerprint then
		return result("rejected", "malformed", nil)
	end
	local admission = CastLedger.reserve(s.ledger, request.generation, request.seq, fingerprint, now)
	if admission.kind ~= "reserved" or not admission.entry then
		return result(admission.kind, admission.reason, admission.receipt)
	end
	local castId = request.generation .. ":" .. tostring(request.seq)
	s.busy = true
	-- Guard programmer errors: no coroutine may outlive its reservation. Exceptions
	-- or yields consume this ID with internal_error, never rerun partial side effects.
	local job = coroutine.create(authorize)
	local ran, accepted, reason = coroutine.resume(job, request, castId)
	local finished = coroutine.status(job) == "dead"
	if not finished then
		coroutine.close(job)
	end
	s.busy = false
	local receipt: CastLedger.Receipt
	if
		not ran
		or not finished
		or type(accepted) ~= "boolean"
		or (not accepted and (type(reason) ~= "string" or #reason == 0 or #reason > 64))
	then
		receipt = { status = "rejected", reason = "internal_error" }
	elseif accepted then
		receipt = { status = "accepted", castId = castId }
	else
		receipt = { status = "rejected", reason = reason }
	end
	-- Same admission clock: adapter may not yield between validation/payment/completion.
	assert(CastLedger.complete(s.ledger, admission.entry, receipt, now), "lost synchronous reservation")
	return result("completed", nil, admission.entry.receipt)
end

function CastAdmission.destroy(s: State)
	assert(not s.busy, "cannot destroy during authorization")
	table.clear(s.ledger.entries)
	s.closed = true
end

return CastAdmission
