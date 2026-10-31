--!strict
-- Pure cosmetic cleanup ownership; callbacks supplied by a later engine adapter.
-- Callbacks must not yield. They may reenter; ownership is detached before disposal.
local CastResources = {}
export type Scope = "pose" | "world"
export type Lease = { key: string, serial: number }
export type Ticket = { lease: Lease, slot: string, serial: number }
export type Resource = { ticket: Ticket, scope: Scope, dispose: () -> () }
export type Owner = { lease: Lease, resources: { [string]: Resource }, count: number, poseClosed: boolean }
export type State = {
	capacity: number,
	perCast: number,
	owners: { [string]: Owner },
	count: number,
	serial: number,
	closed: boolean,
	cleanupFailures: number,
}
local function integer(n: number): boolean
	return n >= 1 and n < math.huge and n % 1 == 0
end
local function name(s: string): boolean
	return #s > 0 and #s <= 256
end
local function dispose(s: State, callback: () -> ())
	local ok = pcall(callback)
	if not ok then
		s.cleanupFailures += 1
	end
end
local function owner(s: State, lease: Lease): Owner?
	local current = s.owners[lease.key]
	return if not s.closed and current and current.lease == lease then current else nil
end
function CastResources.new(capacity: number, perCast: number): State
	assert(integer(capacity) and integer(perCast), "invalid cosmetic resource capacity")
	return {
		capacity = capacity,
		perCast = perCast,
		owners = {},
		count = 0,
		serial = 0,
		closed = false,
		cleanupFailures = 0,
	}
end
-- A key cannot acquire a second owner. Adoption keeps the original lease.
function CastResources.open(s: State, key: string): Lease?
	if s.closed or not name(key) or s.owners[key] or s.count >= s.capacity then
		return nil
	end
	s.serial += 1
	local lease = table.freeze({ key = key, serial = s.serial })
	s.owners[key] = { lease = lease, resources = {}, count = 0, poseClosed = false }
	s.count += 1
	return lease
end
function CastResources.isActive(s: State, lease: Lease): boolean
	return owner(s, lease) ~= nil
end
-- bind takes disposal responsibility even on refusal: no unowned failed allocation.
-- Replacement is explicit release(oldTicket), then bind; reentrant occupation refuses the latter.
function CastResources.bind(s: State, lease: Lease, slot: string, scope: Scope, callback: () -> ()): Ticket?
	local current = owner(s, lease)
	if
		not current
		or not name(slot)
		or (scope ~= "pose" and scope ~= "world")
		or current.resources[slot]
		or current.count >= s.perCast
		or (scope == "pose" and current.poseClosed)
	then
		dispose(s, callback)
		return nil
	end
	s.serial += 1
	local ticket = table.freeze({ lease = lease, slot = slot, serial = s.serial })
	current.resources[slot] = { ticket = ticket, scope = scope, dispose = callback }
	current.count += 1
	return ticket
end
-- Timers and signal callbacks check their own ticket, not just the cast ID.
function CastResources.isCurrent(s: State, ticket: Ticket): boolean
	local current = owner(s, ticket.lease)
	local resource = if current then current.resources[ticket.slot] else nil
	return resource ~= nil and resource.ticket == ticket
end
function CastResources.release(s: State, ticket: Ticket): boolean
	local current = owner(s, ticket.lease)
	local resource = if current then current.resources[ticket.slot] else nil
	if not current or not resource or resource.ticket ~= ticket then
		return false
	end
	current.resources[ticket.slot] = nil
	current.count -= 1
	dispose(s, resource.dispose)
	return true
end
-- Local death/slot/character loss retires poses only, never accepted world hazards.
function CastResources.retirePose(s: State, lease: Lease): boolean
	local current = owner(s, lease)
	if not current or current.poseClosed then
		return false
	end
	current.poseClosed = true
	local retired: { Resource } = {}
	for slot, resource in current.resources do
		if resource.scope == "pose" then
			current.resources[slot] = nil
			current.count -= 1
			table.insert(retired, resource)
		end
	end
	for _, resource in retired do
		dispose(s, resource.dispose)
	end
	return true
end
-- A terminal/timeout clears its exact lease. Reopening the same key during disposal
-- creates a new owner which stale callbacks/old clear operations cannot affect.
function CastResources.clear(s: State, lease: Lease): boolean
	local current = owner(s, lease)
	if not current then
		return false
	end
	s.owners[lease.key] = nil
	s.count -= 1
	local resources = current.resources
	current.resources = {}
	current.count = 0
	for _, resource in resources do
		dispose(s, resource.dispose)
	end
	return true
end
function CastResources.destroy(s: State)
	if s.closed then
		return
	end
	s.closed = true
	local owners = s.owners
	s.owners = {}
	s.count = 0
	for _, current in owners do
		local resources = current.resources
		current.resources = {}
		current.count = 0
		for _, resource in resources do
			dispose(s, resource.dispose)
		end
	end
end
return CastResources
