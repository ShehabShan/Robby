--!strict
-- Pure once-only confirmed-contact commands. No acceptance/terminal dependency,
-- damage, prediction or engine instances. Calls/renderers/disposers must not yield.
local Inbox = require("./CastContactInbox")
local Contacts = require("./CastContacts")
local Resources = require("./CastResources")
local CastContactDispatch = {}
export type Policy = { capacity: number, perContact: number, effectSeconds: number }
export type Frame = {
	key: string,
	action: string,
	contact: Contacts.Contact,
	lease: Resources.Lease,
	now: number,
	expiresAt: number,
	bind: (string, () -> ()) -> Resources.Ticket?,
	isCurrent: (Resources.Ticket) -> boolean,
	release: (Resources.Ticket) -> boolean,
}
export type Renderer = (Frame) -> boolean
export type Active = { lease: Resources.Lease, expiresAt: number }
export type State = {
	inbox: Inbox.State,
	policy: Policy,
	resources: Resources.State,
	active: { [string]: Active },
	render: Renderer,
	lastNow: number,
	busy: boolean,
	closed: boolean,
	consumed: number,
	rendered: number,
	overflow: number,
	stale: number,
	renderFailures: number,
	resourceRefusals: number,
	refusals: number,
}
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
function CastContactDispatch.new(inbox: Inbox.State, policy: Policy, render: Renderer): State
	assert(not inbox.closed, "closed contact inbox")
	assert(finite(policy.effectSeconds) and policy.effectSeconds > 0, "invalid contact lifetime")
	assert(policy.effectSeconds <= inbox.policy.retentionSeconds, "contact lifetime exceeds receipt retention")
	return {
		inbox = inbox,
		policy = table.freeze(table.clone(policy)),
		resources = Resources.new(policy.capacity, policy.perContact),
		active = {},
		render = render,
		lastNow = -math.huge,
		busy = false,
		closed = false,
		consumed = 0,
		rendered = 0,
		overflow = 0,
		stale = 0,
		renderFailures = 0,
		resourceRefusals = 0,
		refusals = 0,
	}
end
local function clear(s: State, key: string, active: Active)
	s.active[key] = nil
	Resources.clear(s.resources, active.lease)
end
local function emit(s: State, key: string, entry: Inbox.Entry, now: number)
	local lease = Resources.open(s.resources, key)
	if not lease then
		s.overflow += 1
		return
	end
	local active = { lease = lease, expiresAt = now + s.policy.effectSeconds }
	s.active[key] = active
	local frame: Frame = table.freeze({
		key = key,
		action = "contact",
		contact = entry.value,
		lease = lease,
		now = now,
		expiresAt = active.expiresAt,
		bind = function(slot: string, dispose: () -> ()): Resources.Ticket?
			local ticket = Resources.bind(s.resources, lease, slot, "world", dispose)
			if not ticket then
				s.resourceRefusals += 1
			end
			return ticket
		end,
		isCurrent = function(ticket: Resources.Ticket): boolean
			return ticket.lease == lease and Resources.isCurrent(s.resources, ticket)
		end,
		release = function(ticket: Resources.Ticket): boolean
			return ticket.lease == lease and Resources.release(s.resources, ticket)
		end,
	})
	local ok, handled = pcall(s.render, frame)
	if not ok or handled ~= true then
		s.renderFailures += 1
		clear(s, key, active)
	else
		s.rendered += 1
	end
end
-- Drive even when no messages arrive. Inbox is borrowed and never destroyed here;
-- its consumed flags survive replacing this dispatcher, so reset cannot replay FX.
function CastContactDispatch.destroy(s: State): boolean
	if s.closed or s.busy then
		return false
	end
	s.closed = true
	s.active = {}
	Resources.destroy(s.resources)
	return true
end
function CastContactDispatch.tick(s: State, now: number, serverNow: number): boolean
	if s.closed or s.busy or not finite(now) or now < s.lastNow or not finite(serverNow) then
		s.refusals += 1
		return false
	end
	if s.inbox.closed then
		CastContactDispatch.destroy(s)
		return false
	end
	if not Inbox.prune(s.inbox, now) then
		s.refusals += 1
		return false
	end
	s.busy = true
	s.lastNow = now
	for key, active in s.active do
		if now >= active.expiresAt then
			clear(s, key, active)
		end
	end
	-- Stable arrival order matters under pressure; never sort by ordinal or use a
	-- high-ordinal watermark which would discard a reordered lower ordinal.
	local pending: { { key: string, order: number } } = {}
	for key, entry in s.inbox.entries do
		if not s.inbox.consumed[key] and entry.value.at <= serverNow then
			table.insert(pending, { key = key, order = entry.order })
		end
	end
	table.sort(pending, function(a, b)
		return a.order < b.order
	end)
	for _, item in pending do
		local entry = Inbox.take(s.inbox, item.key, now)
		if entry then
			s.consumed += 1 -- claim before invoking any renderer; no retries on failure
			if entry.value.at <= serverNow - s.inbox.policy.retentionSeconds then
				s.stale += 1
			else
				emit(s, item.key, entry, now)
			end
		end
	end
	s.busy = false
	return true
end
return CastContactDispatch
