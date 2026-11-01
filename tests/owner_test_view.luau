-- Actual UI module with real client policy, transport, adapter and server controller.
-- GUI instances and scheduler are mocked; this does not certify actual device rendering.
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local rb = require("@lune/roblox")
local Client = require("../src/shared/OwnerTestClient")
local fixture = require("./helpers/owner_test_fixture")
local text = string.rep("x", 11980) .. "界🙂" .. string.rep("y", 16000)
local function setup(mode)
	local env
	local f = fixture(nil, function(f, environment)
		env = environment
		f.worker = function(check, progress)
			f.runs += 1
			check()
			progress(106)
			return { matrixPassed = true, blob = text }, true, true
		end
	end)
	assert(f.ok)
	local made = {}
	local new = f.instance
	env.Instance.new = function(class)
		if mode == "acquire" and class == "TextBox" then
			error("UI acquisition fault")
		end
		local obj = new(class)
		function obj:IsA(name)
			return self.ClassName == name
		end
		function obj:CaptureFocus()
			self.focused = true
		end
		if class == "TextButton" then
			obj.Activated = f.signal()
		end
		table.insert(made, obj)
		return obj
	end
	local request, response = f.folder:FindFirstChild("Request"), f.folder:FindFirstChild("Response")
	function request:IsA(name)
		return name == "RemoteEvent"
	end
	function response:IsA(name)
		return name == "RemoteEvent"
	end
	response.OnClientEvent = f.signal()
	function request:FireServer(action, page)
		f.requests = (f.requests or 0) + 1
		if mode == "request-error" then
			error("request fault")
		end
		self.OnServerEvent:Fire(f.owner, action, page)
	end
	local send = response.FireClient
	function response:FireClient(owner, data)
		send(self, owner, data)
		if mode == "drop-page" and data.data then
			return
		end
		self.OnClientEvent:Fire(data)
	end
	local services = f.game.GetService
	function f.game:GetService(name)
		if name == "HttpService" then
			return {
				JSONDecode = function(_, json)
					if mode == "json-error" then
						error("decode error")
					end
					return serde.decode("json", json)
				end,
				JSONEncode = function(_, value)
					return serde.encode("json", value)
				end,
			}
		end
		return services(self, name)
	end
	env.UDim2, env.Color3, env.Enum, env.Vector2 = rb.UDim2, rb.Color3, rb.Enum, rb.Vector2
	local View = luau.load(fs.readFile("tests/published/OwnerTestView.luau"), { environment = env })()
	f.viewOk, f.viewStop = pcall(View.start, Client, f.owner, f.folder)
	function f.item(class, value)
		for _, obj in made do
			if obj.ClassName == class and (value == nil or obj.Text == value or obj.Name == value) then
				return obj
			end
		end
		error("missing " .. class .. ": " .. tostring(value))
	end
	function f.step(n)
		for _ = 1, n or 1 do
			f.now += 1.1
			f.run.Heartbeat:Fire()
			f.drain()
		end
	end
	function f.close()
		if f.viewOk then
			f.viewStop()
			f.viewStop()
		end
		f.stop()
		f.noLeaks()
		for _, obj in made do
			assert(obj.destroyed and obj.Parent == nil, "UI instance leak")
		end
	end
	return f
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
test("server status not auto-start; explicit activation retrieves every copyable byte", function()
	local f = setup()
	assert(f.viewOk, tostring(f.viewStop))
	f.step(2)
	assert(f.runs == 0)
	local start = f.item("TextButton", "Start test")
	start.Activated:Fire()
	start.Activated:Fire()
	f.step(12)
	assert(f.runs == 1 and not start.Active)
	local box = f.item("TextBox", "ReportPage")
	assert(not box.TextEditable and box.MultiLine and not box.RichText)
	local wire = {}
	for _, message in f.sent do
		if message.data then
			table.insert(wire, message.data)
		end
	end
	local expected = Client.displayPages(table.concat(wire))
	local chunks = {}
	for i = 1, #expected do
		assert(box.Text == expected[i], "display lost/reordered bytes")
		assert(utf8.len(box.Text) and #box.Text <= 6000)
		table.insert(chunks, box.Text)
		f.item("TextButton", "Next").Activated:Fire()
	end
	local report = serde.decode("json", table.concat(chunks))
	assert(report.blob == text and report.cleanup and report.runCompleted and not report.dynamicsAccepted)
	f.item("TextButton", "Select page").Activated:Fire()
	assert(box.focused and box.SelectionStart == 1 and box.CursorPosition == #box.Text + 1)
	f.item("TextButton", "Previous").Activated:Fire()
	assert(box.Text == chunks[#chunks - 1])
	local retained = box.Text
	f.stop()
	f.now = 1000
	f.step()
	assert(box.Text == retained, "completed evidence should remain copyable")
	f.close()
end)
test("bounded transfer retries and invalid JSON never present partial report", function()
	for _, mode in { "drop-page", "json-error", "request-error" } do
		local f = setup(mode)
		assert(f.viewOk)
		f.step()
		f.item("TextButton", "Start test").Activated:Fire()
		f.step(12)
		assert(f.item("TextBox", "ReportPage").Text == "Full JSON will appear here after cleanup and download.", mode)
		f.close()
	end
end)
test("partial acquisition unwinds and original channel replacement never rebinds", function()
	local f = setup("acquire")
	assert(not f.viewOk)
	f.close()
	f = setup()
	f.folder.Parent = nil
	local requests = f.requests or 0
	f.step()
	assert((f.requests or 0) == requests, "must not request after original channel loss")
	assert(f.runs == 0)
	f.item("TextButton", "Start test").Activated:Fire()
	f.step()
	assert(f.runs == 0)
	f.close()
end)
test("100 UI lifetimes disconnect and destroy independently", function()
	for _ = 1, 100 do
		local f = setup()
		assert(f.viewOk)
		f.step()
		f.close()
	end
end)
test("actual client launcher waits for replicated children and bounds teardown", function()
	for _, mode in { "delayed", "missing", "replaced-gui", "acquire-error", "disabled" } do
		local now, waits, starts, stops = 0, 0, 0, 0
		local events = {}
		local function signal()
			local s = { callbacks = {} }
			function s:Connect(fn)
				local c = { Connected = true, callback = fn }
				function c:Disconnect()
					self.Connected = false
				end
				table.insert(self.callbacks, c)
				return c
			end
			function s:Fire()
				for _, c in self.callbacks do
					if c.Connected then
						c.callback()
					end
				end
			end
			table.insert(events, s)
			return s
		end
		local channel = {
			IsA = function()
				return true
			end,
			FindFirstChild = function()
				return if waits >= 2 then {} else nil
			end,
		}
		local gui = {
			FindFirstChild = function()
				return if mode == "missing" then nil else channel
			end,
		}
		local owner = {
			FindFirstChildOfClass = function()
				return if mode == "replaced-gui" and waits > 0 then {} else gui
			end,
		}
		local script = { OwnerTestClient = "client", OwnerTestView = "view", Destroying = signal(), changed = signal() }
		function script:GetPropertyChangedSignal()
			return self.changed
		end
		luau.load(fs.readFile("tests/published/wind_step.client.luau"), {
			environment = {
				game = {
					GetService = function()
						return { LocalPlayer = owner }
					end,
				},
				script = script,
				os = {
					clock = function()
						return now
					end,
				},
				task = {
					wait = function()
						waits += 1
						now += 1
					end,
				},
				warn = function() end,
				require = function(name)
					return if name == "client"
						then Client
						else {
							start = function(_, actualOwner, actualChannel)
								assert(actualOwner == owner and actualChannel == channel and waits >= 2)
								starts += 1
								if mode == "acquire-error" then
									error("view failed")
								end
								return function()
									stops += 1
								end
							end,
						}
				end,
			},
		})()
		if mode == "missing" or mode == "replaced-gui" then
			assert(starts == 0 and now <= 120)
		else
			assert(starts == 1)
			if mode == "disabled" then
				script.Disabled = true
				script.changed:Fire()
			end
			script.Destroying:Fire()
			script.Destroying:Fire()
			assert(stops == (if mode == "acquire-error" then 0 else 1))
		end
		for _, e in events do
			for _, c in e.callbacks do
				assert(not c.Connected)
			end
		end
	end
end)
print(string.format("PASS %d actual-source UI groups (mocked GUI, no device acceptance)", count))
