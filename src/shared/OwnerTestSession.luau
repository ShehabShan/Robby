--!strict
-- Inert test-session policy. No game startup, remotes, physics or acceptance authority.
local Session = {}
Session.maxBytes = 524288
Session.pageBytes = 12000
Session.requestInterval = 0.2
Session.idleSeconds = 120
Session.runSeconds = 600
export type State = {
	owner: any,
	phase: string,
	reason: string?,
	lastNow: number,
	nextRequest: number,
	deadline: number,
	started: boolean,
	cancelled: boolean,
	generation: number,
	report: string?,
	cleanup: boolean?,
	progress: number,
}
local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Session.new(owner: any, now: number): State
	assert(owner ~= nil and finite(now), "owner and finite server clock required")
	return {
		owner = owner,
		phase = "idle",
		reason = nil,
		lastNow = now,
		nextRequest = now,
		deadline = now + Session.idleSeconds,
		started = false,
		cancelled = false,
		generation = 0,
		report = nil,
		cleanup = nil,
		progress = 0,
	}
end
function Session.cancel(state: State, reason: string): boolean
	if state.phase ~= "idle" and state.phase ~= "running" then
		return false
	end
	state.cancelled, state.reason = true, reason
	state.phase = if state.started then "cancelling" else "closed"
	return state.started
end
function Session.tick(state: State, now: number, valid: boolean): boolean
	if not finite(now) or now < state.lastNow then
		return Session.cancel(state, "invalid server clock")
	end
	state.lastNow = now
	if not valid then
		return Session.cancel(state, "test environment changed")
	end
	if now >= state.deadline then
		return Session.cancel(state, "test deadline exceeded")
	end
	return false
end
function Session.status(state: State): any
	return {
		phase = state.phase,
		reason = state.reason,
		progress = state.progress,
		cleanup = state.cleanup,
		bytes = if state.report then #state.report else 0,
		pages = if state.report then math.ceil(#state.report / Session.pageBytes) else 0,
		dynamicsAccepted = false,
	}
end
-- Caller ticks first from trusted runtime state; identity is the actual Player object.
function Session.request(state: State, actor: any, action: any, page: any): (any, number?)
	if actor ~= state.owner then
		return nil, nil
	end
	if state.lastNow < state.nextRequest then
		return nil, nil
	end
	state.nextRequest = state.lastNow + Session.requestInterval
	if action == "status" and page == nil then
		return Session.status(state), nil
	elseif action == "start" and page == nil and state.phase == "idle" then
		state.phase, state.started = "running", true
		state.generation += 1
		state.deadline = state.lastNow + Session.runSeconds
		return Session.status(state), state.generation
	elseif action == "report" and state.report and finite(page) and page % 1 == 0 then
		local pages = math.ceil(#state.report / Session.pageBytes)
		if page >= 1 and page <= pages then
			return {
				page = page,
				pages = pages,
				bytes = #state.report,
				-- Byte chunks must be concatenated before UTF-8/JSON decoding.
				data = string.sub(state.report, (page - 1) * Session.pageBytes + 1, page * Session.pageBytes),
			},
				nil
		end
	end
	return nil, nil
end
function Session.progress(state: State, token: number, value: any)
	if state.phase == "running" and token == state.generation and finite(value) and value % 1 == 0 then
		if value >= state.progress and value <= 106 then
			state.progress = value
		end
	end
end
-- Completion is not matrix/physics acceptance. Cleanup false still exports a failure report.
function Session.finish(state: State, token: number, payload: any, completed: boolean, cleanup: boolean): boolean
	if token ~= state.generation or (state.phase ~= "running" and state.phase ~= "cancelling") then
		return false
	end
	state.cleanup = cleanup == true
	if type(payload) ~= "string" or #payload == 0 or #payload > Session.maxBytes then
		state.phase, state.reason = "failed", "invalid or oversized report"
		return false
	end
	state.report = payload
	local success = completed == true and cleanup == true and not state.cancelled
	state.phase = if success then "complete" else "failed"
	if not success and not state.reason then
		state.reason = "worker or cleanup failed"
	end
	return true
end
return Session
