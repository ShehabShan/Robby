--!strict
-- Prepared owned delivery renderer; NOT started until the atomic keyed cutover.
-- Use separate bounded pools for primary and reserve under ONE CastWarningGate.
-- Metadata/pose resolution belongs to the caller. No clocks, receipt caches or tasks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage.Shared.CastDeliveryPlan)
local Map = require(ReplicatedStorage.Shared.CastCommandMap)
local Bridge = require(ReplicatedStorage.Shared.CastBridge)
local Reserve = require(ReplicatedStorage.Shared.CastWarningReserve)
local Tree = require(script.Parent.CastWorldTree)
local Fx = {}
export type Record = { handle: Tree.Handle?, metadata: Map.Metadata }
export type State = { capacity: number, count: number, entries: { [string]: Record }, closed: boolean }
function Fx.new(capacity: number): State
	assert(capacity >= 1 and capacity < math.huge and capacity % 1 == 0, "invalid delivery pool capacity")
	return { capacity = capacity, count = 0, entries = {}, closed = false }
end
local function forget(s: State, key: string, record: Record)
	-- A delayed old disposer must never remove a newer lease with the same key.
	if s.entries[key] == record then
		s.entries[key] = nil
		s.count -= 1
	end
end
local function render(
	s: State,
	key: string,
	timeline: any,
	now: number,
	owner: Tree.Owner,
	metadata: Map.Metadata?,
	pose: Plan.Pose?,
	poseAllowed: boolean
): boolean
	if s.closed or not metadata or not timeline then
		return false
	end
	local a = metadata.acceptance
	if
		key ~= a.castId
		or timeline.acceptedAt ~= a.acceptedAt
		or timeline.releaseAt ~= a.releaseAt
		or timeline.endsAt ~= a.endsAt
	then
		return false
	end
	local plan = Plan.accepted(metadata, now, pose, poseAllowed)
	if not plan then
		-- Includes moving Burst: never report success with a fabricated static ring.
		return false
	end
	local existing = s.entries[key]
	if existing then
		if existing.metadata ~= metadata or not existing.handle then
			return false
		end
		return Tree.seek(existing.handle, plan)
	end
	if #plan.world == 0 then
		return true -- Self has no world warning; no empty Folder allocation.
	end
	if s.count >= s.capacity then
		return false
	end
	local record: Record = { handle = nil, metadata = metadata }
	s.entries[key] = record
	s.count += 1
	local wrapped: Tree.Owner = {
		bind = function(slot, dispose)
			return owner.bind(slot, function()
				forget(s, key, record)
				dispose()
			end)
		end,
		isCurrent = owner.isCurrent,
		release = owner.release,
	}
	-- Allocation may throw before Tree can bind its root. Never retain that slot.
	local ok, handle = pcall(Tree.open, wrapped, plan)
	if not ok or not handle then
		forget(s, key, record)
		return false
	end
	record.handle = handle
	return true
end
function Fx.primary(
	s: State,
	frame: Bridge.Frame,
	metadata: Map.Metadata?,
	identity: Plan.Identity?,
	pose: Plan.Pose?
): boolean
	if s.closed then
		return false
	end
	if not frame.timeline then
		-- Reversible anticipation is intentionally a no-op until pose art is authored.
		-- In particular, prediction cannot allocate speculative world/contact FX.
		return identity ~= nil and Plan.predicted(identity, pose, frame.poseAllowed).speculative
	end
	return render(s, frame.key, frame.timeline, frame.now, {
		bind = function(slot, dispose)
			return frame.bind(slot, "world", dispose)
		end,
		isCurrent = frame.isCurrent,
		release = frame.release,
	}, metadata, pose, frame.poseAllowed)
end
function Fx.warning(s: State, frame: Reserve.Frame, metadata: Map.Metadata?): boolean
	return render(s, frame.key, frame.timeline, frame.now, {
		bind = frame.bind,
		isCurrent = frame.isCurrent,
		release = frame.release,
	}, metadata, nil, false)
end
function Fx.destroy(s: State)
	if s.closed then
		return
	end
	s.closed = true
	-- Normally the outer gate destroys these first; this is safe in either order.
	local entries = table.clone(s.entries)
	for key, record in entries do
		forget(s, key, record)
		if record.handle then
			record.handle.owner.release(record.handle.ticket)
			Tree.close(record.handle)
		end
	end
end
return Fx
