-- Appended to generated server; transport is inert until original owner requests start.
local Transport = require(script.OwnerTestTransport)
local Session = require(script.OwnerTestSession)
local Adapter = require(script.OwnerTestAdapter)
local stopTransport: (() -> ())? = nil
local lifetime: { RBXScriptConnection } = {}
local closed = false
local function stop()
	if closed then
		return
	end
	closed = true
	if stopTransport then
		pcall(stopTransport)
	end
	pcall(cancelActive)
	for _, connection in lifetime do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(lifetime)
end
local acquired, acquireError = pcall(function()
	table.insert(lifetime, script.Destroying:Connect(stop))
	table.insert(
		lifetime,
		script:GetPropertyChangedSignal("Disabled"):Connect(function()
			if script.Disabled then
				stop()
			end
		end)
	)
	stopTransport = Transport.start(Session, Adapter, Policy, {
		owner = current[1],
		target = target,
		optIn = true,
		run = runWorker,
		cancelWorker = function()
			cancelActive()
		end,
	})
	script:SetAttribute("HasRun", true)
end)
if not acquired then
	stop()
	warn("WIND_STEP_BLOCKED: " .. tostring(acquireError))
end
