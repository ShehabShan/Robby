--!strict
-- Borrows validated receipts; owns one outer clock/gate and its pinned metadata.
-- No engine services, listeners or gameplay authority. Engine owner is not started yet.
local Inbox = require("./CastInbox")
local Map = require("./CastCommandMap")
local Store = require("./CastDeliveryStore")
local Gate = require("./CastWarningGate")
local Plan = require("./CastDeliveryPlan")
local Bridge = require("./CastBridge")
local Reserve = require("./CastWarningReserve")
local Dispatch = {}
export type Cursor = { inbox: Inbox.State, receipts: number, responses: number, retiredThrough: number }
export type State = {
	inbox: Inbox.State,
	catalog: Map.Catalog,
	store: Store.State,
	gate: Gate.State,
	receipts: number,
	responses: number,
	retiredThrough: number,
	closed: boolean,
	busy: boolean,
	refusals: number,
}
export type Renderer = (Bridge.Frame, Store.Entry?) -> boolean
export type Warning = (Reserve.Frame, Store.Entry?) -> boolean
function Dispatch.new(
	inbox: Inbox.State,
	catalog: Map.Catalog,
	policy: Gate.Policy,
	render: Renderer,
	warning: Warning,
	cursor: Cursor?
): State
	assert(not inbox.acceptances.closed, "start receipts first")
	local store = Store.new(policy.presentation.capacity + policy.warning.capacity + policy.clock.pendingCapacity)
	local gate = Gate.new(policy, function(frame)
		return render(frame, Store.get(store, frame.key))
	end, function(frame)
		return warning(frame, Store.get(store, frame.key))
	end)
	local sameInbox = cursor ~= nil and cursor.inbox == inbox
	return {
		inbox = inbox,
		catalog = catalog,
		store = store,
		gate = gate,
		receipts = if sameInbox then (cursor :: Cursor).receipts else 0,
		responses = if sameInbox then (cursor :: Cursor).responses else 0,
		retiredThrough = if cursor then cursor.retiredThrough else -math.huge,
		closed = false,
		busy = false,
		refusals = 0,
	}
end
function Dispatch.destroy(s: State): Cursor?
	if s.busy then
		return nil
	end
	if not s.closed then
		s.closed = true
		s.retiredThrough = math.max(s.retiredThrough, s.gate.gate.now or -math.huge, s.inbox.retiredThrough)
		-- Future admissions and unpolled receipts can be ahead of the gate clock.
		-- Retire their timestamps too; a fresh inbox must not replay them on restart.
		for _, entry in s.store.entries do
			if entry.accepted then
				s.retiredThrough = math.max(s.retiredThrough, entry.accepted.metadata.acceptance.acceptedAt)
			end
		end
		for _, entry in s.inbox.acceptances.entries do
			if entry.acceptance then
				s.retiredThrough = math.max(s.retiredThrough, entry.acceptance.acceptedAt)
			end
			if entry.terminal then
				s.retiredThrough = math.max(s.retiredThrough, entry.terminal.at)
			end
		end
		Gate.destroy(s.gate)
		Store.destroy(s.store)
	end
	-- Skip even unpolled retained receipts on same-inbox restart. Across a fresh
	-- inbox the conservative server-time watermark prevents old effects replaying.
	return {
		inbox = s.inbox,
		receipts = s.inbox.acceptances.serial,
		responses = s.inbox.serial,
		retiredThrough = s.retiredThrough,
	}
end
local function begin(s: State, localNow: number): boolean
	if s.closed or s.busy then
		return false
	end
	if s.inbox.acceptances.closed then
		Dispatch.destroy(s)
		return false
	end
	if not Inbox.prune(s.inbox, localNow) then
		s.refusals += 1
		return false
	end
	s.busy = true
	return true
end
local function finish(s: State)
	Store.prune(s.store, s.gate)
	s.busy = false
end
-- Always run before prediction or pose retirement as well as the heartbeat.
-- Snapshot size is bounded by the borrowed inbox; observation is two scalars,
-- not an ever-growing seen-key set or a second immutable-receipt cache.
function Dispatch.tick(s: State, localNow: number, serverNow: number): boolean
	if not begin(s, localNow) then
		return false
	end
	local cancelled: { [string]: boolean } = {}
	local accepted = {}
	for key, entry in s.inbox.acceptances.entries do
		if entry.order > s.receipts then
			if entry.terminal then
				cancelled[key] = true
			elseif entry.acceptance then
				table.insert(accepted, entry)
			end
		end
	end
	for key, response in s.inbox.responses do
		if response.order > s.responses and response.value.status == "rejected" then
			cancelled[key] = true
		end -- expired is NOT a refusal; genuine late acceptance can still render
	end
	local retired = math.max(s.retiredThrough, s.inbox.retiredThrough)
	s.retiredThrough = retired
	for key, entry in s.store.entries do
		if entry.accepted and entry.accepted.metadata.acceptance.acceptedAt <= retired then
			cancelled[key] = true
		end
	end
	if not Gate.cancelMany(s.gate, cancelled, localNow, serverNow) then
		s.refusals += 1
		finish(s)
		return false
	end
	Store.prune(s.store, s.gate)
	s.receipts, s.responses = s.inbox.acceptances.serial, s.inbox.serial
	table.sort(accepted, function(a, b)
		return a.order < b.order
	end)
	for _, entry in accepted do
		local command = Map.accepted(s.catalog, entry)
		if command and not cancelled[command.key] and command.metadata.acceptance.acceptedAt > retired then
			local result = Store.accept(s.store, command)
			if result == "stored" or result == "duplicate" then
				local canonical = (Store.get(s.store, command.key) :: Store.Entry).accepted :: Map.Accepted
				Gate.accept(s.gate, canonical.key, canonical.timeline, localNow, serverNow)
			else
				s.refusals += 1
			end
			Store.prune(s.store, s.gate)
		end
	end
	finish(s)
	return true -- clock processed, NOT a guarantee that either renderer succeeded
end
function Dispatch.predict(s: State, key: string, identity: Plan.Identity, localNow: number, serverNow: number): string
	if not Dispatch.tick(s, localNow, serverNow) then
		return "refuse"
	end
	s.busy = true
	local outcome = Store.predict(s.store, key, identity)
	if outcome == "stored" or outcome == "duplicate" then
		outcome = Gate.predict(s.gate, key, localNow, serverNow)
	end
	finish(s)
	return outcome
end
function Dispatch.retirePose(s: State, key: string, localNow: number, serverNow: number): boolean
	if not Dispatch.tick(s, localNow, serverNow) then
		return false
	end
	s.busy = true
	local result = Gate.retirePose(s.gate, key, localNow, serverNow)
	finish(s)
	return result
end
return Dispatch
