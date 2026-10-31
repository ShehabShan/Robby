--!strict
-- Prepared engine adapter; startup remains off until the atomic keyed FX cutover.
-- Borrows receipt inboxes. Stop this owner BEFORE stopping CastReceiptClient.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Dispatch = require(ReplicatedStorage.Shared.CastContactDispatch)
local CommandMap = require(ReplicatedStorage.Shared.CastCommandMap)
local ReceiptClient = require(script.Parent.CastReceiptClient)
local Fx = require(script.Parent.CastContactFx)
local CastContactClient = {}
local stop: (() -> ())? = nil
local active: Dispatch.State? = nil

function CastContactClient.state(): Dispatch.State?
	return active
end

function CastContactClient.start(catalog: CommandMap.Catalog): () -> ()
	if stop then
		return stop
	end
	local inbox, contacts = ReceiptClient.inbox(), ReceiptClient.contacts()
	assert(inbox and contacts and not inbox.acceptances.closed and not contacts.closed, "start receipts first")
	local state = Dispatch.new(contacts, Config.CastContactPresentation, function(frame)
		local entry = inbox.acceptances.entries[frame.contact.castId]
		return Fx.render(frame, CommandMap.contact(catalog, frame.contact, entry))
	end)
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
		Dispatch.destroy(state)
		active, stop = nil, nil
	end
	stop = cleanup
	heartbeat = RunService.Heartbeat:Connect(function()
		-- Also fail closed if a caller tears down the borrowed receipt owner first.
		if inbox.acceptances.closed or contacts.closed then
			cleanup()
			return
		end
		Dispatch.tick(state, os.clock(), workspace:GetServerTimeNow())
	end)
	return cleanup
end

return CastContactClient
