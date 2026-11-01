--!strict
-- Disabled by the candidate builder. Release tooling must opt in both server/client.
local Players = game:GetService("Players")
local owner = Players.LocalPlayer
local deadline = os.clock() + 120
local originalGui: PlayerGui? = nil
local channel: Folder? = nil
repeat
	local gui = owner:FindFirstChildOfClass("PlayerGui")
	if gui then
		if originalGui and originalGui ~= gui then
			return
		end
		originalGui = gui
		local found = gui:FindFirstChild("WindStepTestSession")
		if found and found:IsA("Folder") then
			channel = found
		end
	end
	if not channel then
		task.wait(0.1)
	end
until channel ~= nil or os.clock() >= deadline
if not channel then
	warn("Wind Step owner channel unavailable; use a fresh test server.")
	return
end
local Client = require(script.OwnerTestClient)
local View = require(script.OwnerTestView)
local stopView: (() -> ())? = nil
local lifetime: { RBXScriptConnection } = {}
local closed = false
local function stop()
	if closed then
		return
	end
	closed = true
	if stopView then
		pcall(stopView)
	end
	for _, c in lifetime do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(lifetime)
end
local ok, err = pcall(function()
	table.insert(lifetime, script.Destroying:Connect(stop))
	table.insert(
		lifetime,
		script:GetPropertyChangedSignal("Disabled"):Connect(function()
			if script.Disabled then
				stop()
			end
		end)
	)
	stopView = View.start(Client, owner, channel :: Folder)
end)
if not ok then
	stop()
	warn(tostring(err))
end
