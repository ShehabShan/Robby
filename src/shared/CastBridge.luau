--!strict
-- Pure owned presentation executor. NOT connected to the live FX path.
-- All calls and renderer/disposal callbacks are synchronous and non-yielding.
-- One monotonic authoritative clock domain; skew admission is a separate layer.
local Presentation = require("./CastPresentation")
local Resources = require("./CastResources")
local CastBridge = {}
export type Frame = {
	key: string,
	lease: Resources.Lease,
	action: string,
	now: number,
	timeline: Presentation.Timeline?,
	phase: string,
	progress: number,
	poseAllowed: boolean,
	bind: (string, Resources.Scope, () -> ()) -> Resources.Ticket?,
	isCurrent: (Resources.Ticket) -> boolean,
	release: (Resources.Ticket) -> boolean,
}
-- Return true only if the command was handled. false/throw retires ALL resources
-- for that cast; the later essential-cue layer receives the failure outcome.
export type Renderer = (Frame) -> boolean
export type State = {
	presentation: Presentation.State,
	resources: Resources.State,
	leases: { [string]: Resources.Lease },
	render: Renderer,
	busy: boolean,
	closed: boolean,
	renderFailures: number,
	resourceRefusals: number,
	refusals: number,
}
function CastBridge.new(policy: Presentation.Policy, perCast: number, render: Renderer): State
	return {
		presentation = Presentation.new(policy),
		resources = Resources.new(policy.capacity, perCast),
		leases = {},
		render = render,
		busy = false,
		closed = false,
		renderFailures = 0,
		resourceRefusals = 0,
		refusals = 0,
	}
end
local function clear(s: State, key: string)
	local lease = s.leases[key]
	s.leases[key] = nil -- detach before invoking external disposal callbacks
	if lease then
		Resources.clear(s.resources, lease)
	end
end
local function begin(s: State, now: number): boolean
	if s.closed or s.busy then
		s.refusals += 1
		return false
	end
	s.busy = true
	local changes = Presentation.tick(s.presentation, now)
	if not changes then
		s.busy = false
		s.refusals += 1
		return false
	end
	for _, change in changes do
		clear(s, change.key)
	end
	return true
end
local function fail(s: State, key: string, now: number): string
	-- Do not replay this cast on the next tick or duplicate acceptance.
	Presentation.cancel(s.presentation, key, now)
	clear(s, key)
	s.renderFailures += 1
	return "failed"
end
local function emit(s: State, key: string, action: string, now: number, timeline: Presentation.Timeline?): string
	local lease: Resources.Lease? = s.leases[key]
	if not lease then
		lease = Resources.open(s.resources, key)
		if not lease then
			return fail(s, key, now)
		end
		s.leases[key] = lease
	end
	local activeLease = assert(lease, "render requires a resource lease")
	local owner = s.resources.owners[key]
	local phase, progress = "predicted", 0
	if timeline then
		phase, progress = Presentation.phase(timeline, now)
	end
	local frame: Frame = table.freeze({
		key = key,
		lease = activeLease,
		action = action,
		now = now,
		timeline = timeline,
		phase = phase,
		progress = progress,
		poseAllowed = owner ~= nil and not owner.poseClosed,
		bind = function(slot: string, scope: Resources.Scope, dispose: () -> ()): Resources.Ticket?
			local ticket = Resources.bind(s.resources, activeLease, slot, scope, dispose)
			if not ticket then
				s.resourceRefusals += 1
			end
			return ticket
		end,
		isCurrent = function(ticket: Resources.Ticket): boolean
			return ticket.lease == activeLease and Resources.isCurrent(s.resources, ticket)
		end,
		release = function(ticket: Resources.Ticket): boolean
			return ticket.lease == activeLease and Resources.release(s.resources, ticket)
		end,
	})
	local ok, handled = pcall(s.render, frame)
	if not ok or handled ~= true then
		return fail(s, key, now)
	end
	return action
end
local function apply(s: State, key: string, value: Presentation.Result, now: number): string
	if value.action == "clear" then
		clear(s, key)
	elseif value.action == "predict" or value.action == "start" or value.action == "adopt" then
		return emit(s, key, value.action, now, value.timeline)
	elseif value.action == "refuse" then
		s.refusals += 1
	end
	return value.action
end
function CastBridge.predict(s: State, key: string, now: number): string
	if not begin(s, now) then
		return "refuse"
	end
	local outcome = apply(s, key, Presentation.predict(s.presentation, key, now), now)
	s.busy = false
	return outcome
end
function CastBridge.accept(s: State, key: string, timeline: Presentation.Timeline, now: number): string
	if not begin(s, now) then
		return "refuse"
	end
	local outcome = apply(s, key, Presentation.accept(s.presentation, key, timeline, now), now)
	s.busy = false
	return outcome
end
-- Explicit authoritative terminal/rejection only, not local character loss.
function CastBridge.cancel(s: State, key: string, now: number): string
	if not begin(s, now) then
		return "refuse"
	end
	local outcome = apply(s, key, Presentation.cancel(s.presentation, key, now), now)
	s.busy = false
	return outcome
end
-- Local character loss permanently closes pose admission on this lease. Accepted
-- world effects remain seekable. The caller retires only its character's cast keys.
function CastBridge.retirePose(s: State, key: string, now: number): boolean
	if not begin(s, now) then
		return false
	end
	local lease = s.leases[key]
	local retired = lease ~= nil and Resources.retirePose(s.resources, lease)
	s.busy = false
	return retired
end
-- Required even with no incoming events. No impact is inferred from phase time.
-- Renderers seek existing resources rather than re-emitting bursts on each call.
function CastBridge.tick(s: State, now: number): boolean
	if not begin(s, now) then
		return false
	end
	local handled = true
	for key, entry in s.presentation.entries do
		if entry.kind == "accepted" and entry.timeline then
			if emit(s, key, "seek", now, entry.timeline) == "failed" then
				handled = false
			end
		end
	end
	s.busy = false
	return handled
end
-- Reentrant mutation is refused, not queued. Renderers/disposers must not try to
-- drive the bridge; the external owner retries teardown after the command returns.
function CastBridge.destroy(s: State): boolean
	if s.closed then
		return true
	elseif s.busy then
		s.refusals += 1
		return false
	end
	s.closed = true
	s.busy = true
	Presentation.destroy(s.presentation)
	s.leases = {}
	Resources.destroy(s.resources)
	s.busy = false
	return true
end
return CastBridge
