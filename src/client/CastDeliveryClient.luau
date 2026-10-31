--!strict
-- Prepared engine owner. DO NOT start until truthful Burst and atomic keyed cutover.
-- Borrows receipts; stop this owner before CastReceiptClient. No gameplay authority.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Dispatch = require(ReplicatedStorage.Shared.CastDeliveryDispatch)
local Map = require(ReplicatedStorage.Shared.CastCommandMap)
local Identity = require(ReplicatedStorage.Shared.CastCharacterIdentity)
local Character = require(script.Parent.CastCharacterClient)
local Receipts = require(script.Parent.CastReceiptClient)
local Fx = require(script.Parent.CastDeliveryFx)
local Client = {}
local function release(dispose: () -> ())
	local ok, err = pcall(function(): any
		dispose()
		return nil
	end)
	if not ok then
		pcall(warn, err)
	end
end
local function burstSample(entry: any, now: number)
	local metadata = if entry and entry.accepted then entry.accepted.metadata else nil
	local a = if metadata then metadata.acceptance else nil
	if a and a.geometry and a.geometry.kind == "Burst" and now < a.releaseAt then
		return Character.burst(entry.identity, now)
	end
	return nil
end
local active: Dispatch.State? = nil
local stop: (() -> ())? = nil
local cursor: Dispatch.Cursor? = nil
local settle: ((number, number) -> ())? = nil
function Client.state(): Dispatch.State?
	return active
end
function Client.predict(key: string, identity: Identity.Value): string
	local state = active
	if not state or not Identity.valid(identity) or identity.casterUserId ~= Players.LocalPlayer.UserId then
		return "refuse"
	end
	local _, pose = Character.resolve(identity)
	if not pose then
		return "refuse"
	end
	local localNow, serverNow = os.clock(), workspace:GetServerTimeNow()
	local result = Dispatch.predict(state, key, identity, localNow, serverNow)
	if settle then
		settle(localNow, serverNow)
	end
	return result
end
function Client.start(catalog: Map.Catalog): () -> ()
	if stop then
		return stop
	end
	local inbox = Receipts.inbox()
	assert(inbox and not inbox.acceptances.closed, "start receipts first")
	local primary: Fx.State? = nil
	local reserve: Fx.State? = nil
	local state: Dispatch.State? = nil
	local seen: { [string]: boolean } = {}
	local retired: { [string]: boolean } = {}
	local heartbeat: RBXScriptConnection? = nil
	local closed = false
	local function cleanup()
		if closed then
			return
		end
		closed = true
		if heartbeat then
			release(function()
				(heartbeat :: RBXScriptConnection):Disconnect()
			end)
		end
		-- Release leases before pools; an independent cleanup error cannot skip the rest.
		if state then
			release(function()
				cursor = Dispatch.destroy(state :: Dispatch.State) or cursor
			end)
		end
		if primary then
			release(function()
				Fx.destroy(primary :: Fx.State)
			end)
		end
		if reserve then
			release(function()
				Fx.destroy(reserve :: Fx.State)
			end)
		end
		table.clear(seen)
		table.clear(retired)
		active, stop, settle = nil, nil, nil
	end
	stop = cleanup
	local ok, err = pcall(function()
		primary = Fx.new(Config.CastWarning.presentation.capacity)
		reserve = Fx.new(Config.CastWarning.warning.capacity)
		local primaryPool, reservePool = primary :: Fx.State, reserve :: Fx.State
		state = Dispatch.new(inbox, catalog, Config.CastWarning, function(frame, entry)
			local identity = if entry then entry.identity else nil
			local pose = nil
			if identity and not retired[frame.key] then
				local _, resolved = Character.resolve(identity)
				pose = resolved
				if pose then
					seen[frame.key] = true
				end
			end
			local accepted = if entry then entry.accepted else nil
			return Fx.primary(
				primaryPool,
				frame,
				if accepted then accepted.metadata else nil,
				identity,
				pose,
				burstSample(entry, frame.now)
			)
		end, function(frame, entry)
			local accepted = if entry then entry.accepted else nil
			return Fx.warning(
				reservePool,
				frame,
				if accepted then accepted.metadata else nil,
				burstSample(entry, frame.now)
			)
		end, cursor)
	end)
	if not ok then
		cleanup()
		error(err, 0)
	end
	local dispatch = state :: Dispatch.State
	active = dispatch
	local function reconcile(localNow: number, serverNow: number)
		if dispatch.closed or inbox.acceptances.closed then
			cleanup()
			return
		end
		-- Missing-before-first-observation can become available later. Once a pose
		-- has been observed, loss retires it irreversibly without cancelling world work.
		for key in seen do
			local entry = dispatch.store.entries[key]
			if not entry then
				seen[key], retired[key] = nil, nil
			elseif not retired[key] then
				local _, pose = Character.resolve(entry.identity)
				if not pose then
					retired[key] = true
					Dispatch.retirePose(dispatch, key, localNow, serverNow)
				end
			end
		end
	end
	settle, stop = reconcile, cleanup
	ok, err = pcall(function()
		heartbeat = RunService.Heartbeat:Connect(function()
			if closed then
				return
			end
			if inbox.acceptances.closed then
				cleanup()
				return
			end
			local localNow, serverNow = os.clock(), workspace:GetServerTimeNow()
			reconcile(localNow, serverNow)
			Dispatch.tick(dispatch, localNow, serverNow)
			reconcile(localNow, serverNow)
		end)
	end)
	if not ok then
		cleanup()
		error(err, 0)
	end
	return cleanup
end
return Client
