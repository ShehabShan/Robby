--!strict
-- Reliable receipt adapter. Renderer adoption belongs to T-043c0b4.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local CastInbox = require(ReplicatedStorage.Shared.CastInbox)
local Net = require(script.Parent.Net)
local CastReceiptClient = {}
local active: CastInbox.State? = nil
local stop: (() -> ())? = nil
local function vector(v: Vector3): { x: number, y: number, z: number }
	return { x = v.X, y = v.Y, z = v.Z }
end
function CastReceiptClient.inbox(): CastInbox.State?
	return active
end
function CastReceiptClient.start(): () -> ()
	if stop then
		return stop
	end
	local state = CastInbox.new(Config.CastClientReceipt)
	active = state
	local disconnectAccepted = Net.CastAccepted.On(function(v)
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
			aim = vector(v.aim),
			origin = vector(v.origin),
			centre = if v.centre then vector(v.centre) else nil,
		}, os.clock(), workspace:GetServerTimeNow(), Config.CastLifetime.graceSeconds)
	end)
	local disconnectTerminal = Net.CastTerminal.On(function(v)
		CastInbox.terminal(state, v.castId, v.reason, v.at, os.clock())
	end)
	-- c3c2 ships the server channel before c3c3 stores contacts. Drain it now:
	-- Blink otherwise retains an unbounded queue while waiting for a listener.
	local disconnectContact = Net.CastContact.On(function() end)
	local disconnectDisposition = Net.CastDisposition.On(function(v)
		CastInbox.disposition(state, v, os.clock())
	end)
	-- Once per second, not per rendered frame; all insert paths also prune.
	local lastPrune = os.clock()
	local heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastPrune >= 1 then
			CastInbox.prune(state, now)
			lastPrune = now
		end
	end)
	local closed = false
	local function cleanup()
		if closed then
			return
		end
		closed = true
		disconnectAccepted()
		disconnectTerminal()
		disconnectContact()
		disconnectDisposition()
		heartbeat:Disconnect()
		CastInbox.destroy(state)
		active, stop = nil, nil
	end
	stop = cleanup
	return cleanup
end
return CastReceiptClient
