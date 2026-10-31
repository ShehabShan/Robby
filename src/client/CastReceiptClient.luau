--!strict
-- Reliable receipt adapter. Renderer adoption belongs to T-043c0b4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local CastInbox = require(ReplicatedStorage.Shared.CastInbox)
local CastContactInbox = require(ReplicatedStorage.Shared.CastContactInbox)
local Net = require(script.Parent.Net)
local CastReceiptClient = {}
local active: CastInbox.State? = nil
local stop: (() -> ())? = nil
local contacts: CastContactInbox.State? = nil
local retiredContactThrough: number? = nil
local function release(dispose: () -> ())
	local ok, err = pcall(function(): any
		dispose()
		return nil
	end)
	if not ok then
		pcall(warn, err)
	end
end
local function vector(v: Vector3): { x: number, y: number, z: number }
	return { x = v.X, y = v.Y, z = v.Z }
end
function CastReceiptClient.inbox(): CastInbox.State?
	return active
end
function CastReceiptClient.contacts(): CastContactInbox.State?
	return contacts
end
function CastReceiptClient.start(): () -> ()
	if stop then
		return stop
	end
	local state = CastInbox.new(Config.CastClientReceipt)
	local contactState: CastContactInbox.State? = nil
	local disposers: { () -> () } = {}
	local closed = false
	local function cleanup()
		if closed then
			return
		end
		closed = true
		for i = #disposers, 1, -1 do
			release(disposers[i])
		end
		table.clear(disposers)
		release(function()
			CastInbox.destroy(state)
		end)
		if contactState then
			release(function()
				CastContactInbox.destroy(contactState :: CastContactInbox.State)
			end)
			retiredContactThrough = math.max(retiredContactThrough or -math.huge, contactState.retiredThrough)
		end
		-- A reset never replays pre-reset contacts, even if the clock is unavailable.
		release(function()
			retiredContactThrough = math.max(retiredContactThrough or -math.huge, workspace:GetServerTimeNow())
		end)
		active, contacts, stop = nil, nil, nil
	end
	stop = cleanup
	local ok, err = pcall(function()
		contactState = CastContactInbox.new(Config.CastClientContact, retiredContactThrough)
		local receiptContacts = contactState :: CastContactInbox.State
		table.insert(
			disposers,
			Net.CastAccepted.On(function(v)
				if closed then
					return
				end
				CastInbox.accept(state, {
					castId = v.castId,
					generation = v.generation,
					seq = v.seq,
					moveId = v.moveId,
					casterUserId = v.casterUserId,
					characterKey = v.characterKey,
					slotRevision = v.slotRevision,
					acceptedAt = v.acceptedAt,
					releaseAt = v.releaseAt,
					endsAt = v.endsAt,
					geometry = v.geometry,
					aim = vector(v.aim),
					origin = vector(v.origin),
					centre = if v.centre then vector(v.centre) else nil,
				}, os.clock(), workspace:GetServerTimeNow(), Config.CastLifetime.graceSeconds)
			end)
		)
		table.insert(
			disposers,
			Net.CastTerminal.On(function(v)
				if closed then
					return
				end
				CastInbox.terminal(state, v.castId, v.reason, v.at, os.clock())
			end)
		)
		-- A genuine contact can arrive before acceptance or after terminal on separate channels.
		table.insert(
			disposers,
			Net.CastContact.On(function(v)
				if closed then
					return
				end
				CastContactInbox.record(receiptContacts, {
					castId = v.castId,
					ordinal = v.ordinal,
					resource = v.resource,
					tick = v.tick,
					targetKey = v.targetKey,
					at = v.at,
					amount = v.amount,
					position = vector(v.position),
					direction = vector(v.direction),
				}, os.clock(), workspace:GetServerTimeNow())
			end)
		)
		table.insert(
			disposers,
			Net.CastDisposition.On(function(v)
				if closed then
					return
				end
				CastInbox.disposition(state, v, os.clock())
			end)
		)
		-- Once per second, not per rendered frame; all insert paths also prune.
		local lastPrune = os.clock()
		local heartbeat = RunService.Heartbeat:Connect(function()
			if closed then
				return
			end
			local now = os.clock()
			if now - lastPrune >= 1 then
				CastInbox.prune(state, now)
				CastContactInbox.prune(receiptContacts, now)
				lastPrune = now
			end
		end)
		table.insert(disposers, function()
			heartbeat:Disconnect()
		end)
	end)
	if not ok then
		cleanup()
		error(err, 0)
	end
	active, contacts = state, contactState
	return cleanup
end
return CastReceiptClient
