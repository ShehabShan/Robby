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
	local primary = Fx.new(Config.CastWarning.presentation.capacity)
	local reserve = Fx.new(Config.CastWarning.warning.capacity)
	-- These flags exist only while the canonical store owns the key; no second receipt cache.
	local seen: { [string]: boolean } = {}
	local retired: { [string]: boolean } = {}
	local state = Dispatch.new(inbox, catalog, Config.CastWarning, function(frame, entry)
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
		return Fx.primary(primary, frame, if accepted then accepted.metadata else nil, identity, pose)
	end, function(frame, entry)
		local accepted = if entry then entry.accepted else nil
		return Fx.warning(reserve, frame, if accepted then accepted.metadata else nil)
	end, cursor)
	active = state
	local heartbeat: RBXScriptConnection? = nil
	local closed = false
	local function cleanup()
		if closed then
			return
		end
		closed = true
		if heartbeat then
			heartbeat:Disconnect()
		end
		-- Dispatch releases lease-owned trees before pools; retain the suppression cursor.
		cursor = Dispatch.destroy(state) or cursor
		Fx.destroy(primary)
		Fx.destroy(reserve)
		table.clear(seen)
		table.clear(retired)
		active, stop, settle = nil, nil, nil
	end
	local function reconcile(localNow: number, serverNow: number)
		if state.closed or inbox.acceptances.closed then
			cleanup()
			return
		end
		-- Missing-before-first-observation can become available later. Once a pose
		-- has been observed, loss retires it irreversibly without cancelling world work.
		for key in seen do
			local entry = state.store.entries[key]
			if not entry then
				seen[key], retired[key] = nil, nil
			elseif not retired[key] then
				local _, pose = Character.resolve(entry.identity)
				if not pose then
					retired[key] = true
					Dispatch.retirePose(state, key, localNow, serverNow)
				end
			end
		end
	end
	settle, stop = reconcile, cleanup
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
		Dispatch.tick(state, localNow, serverNow)
		reconcile(localNow, serverNow)
	end)
	return cleanup
end
return Client
