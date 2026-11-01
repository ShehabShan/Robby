-- Execute the actual engine-binding source with real adapter/policies; engine only mocked.
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local Policy = require("../../src/shared/OwnerTestSession")
local Adapter = require("../published/OwnerTestAdapter")
local Admission = require("../published/WindStepPublishedPolicy")
local function fixture(mode, configure)
	local f = { now = 0, signals = {}, instances = {}, jobs = {}, sent = {}, runs = 0, cancels = 0, connects = 0 }
	local function signal()
		local s = { list = {} }
		function s:Connect(fn)
			f.connects += 1
			if mode == "acquire" and f.connects == 4 then
				error("connect fault")
			end
			local c = { Connected = true, callback = fn }
			function c:Disconnect()
				self.Connected = false
			end
			table.insert(self.list, c)
			return c
		end
		function s:Fire(...)
			for _, c in table.clone(self.list) do
				if c.Connected then
					c.callback(...)
				end
			end
		end
		table.insert(f.signals, s)
		return s
	end
	local function instance(class)
		local object = { ClassName = class, Name = class }
		function object:FindFirstChild(name)
			for _, child in f.instances do
				if child.Parent == self and child.Name == name then
					return child
				end
			end
			return nil
		end
		function object:FindFirstChildOfClass(name)
			for _, child in f.instances do
				if child.Parent == self and child.ClassName == name then
					return child
				end
			end
			return nil
		end
		function object:Destroy()
			self.Parent = nil
			self.destroyed = true
			for _, child in f.instances do
				if child.Parent == self then
					child:Destroy()
				end
			end
		end
		if class == "RemoteEvent" then
			object.OnServerEvent = signal()
			function object:FireClient(owner, response)
				assert(owner == f.owner)
				table.insert(f.sent, response)
			end
		end
		table.insert(f.instances, object)
		return object
	end
	f.players = { PlayerAdded = signal(), PlayerRemoving = signal() }
	f.owner = instance("Player")
	f.owner.UserId, f.owner.Parent = 7738981129, f.players
	f.gui = instance("PlayerGui")
	f.gui.Parent = f.owner
	f.list = { f.owner }
	function f.players:GetPlayers()
		return f.list
	end
	f.run = {
		Heartbeat = signal(),
		IsStudio = function()
			return mode == "studio"
		end,
		IsRunning = function()
			return true
		end,
		IsServer = function()
			return true
		end,
	}
	f.game = {
		GameId = if mode == "wrong-place" then 999 else 123,
		PlaceId = 456,
		PlaceVersion = 1,
		JobId = "OFFLINE",
		GetService = function(_, name)
			if name == "Players" then
				return f.players
			end
			if name == "RunService" then
				return f.run
			end
			assert(name == "HttpService")
			return {
				JSONEncode = function(_, t)
					return serde.encode("json", t)
				end,
			}
		end,
	}
	local environment = {
		game = f.game,
		Instance = { new = instance },
		os = {
			clock = function()
				return f.now
			end,
		},
		task = {
			defer = function(fn)
				table.insert(f.jobs, fn)
			end,
		},
	}
	f.instance, f.signal = instance, signal
	if configure then
		configure(f, environment)
	end
	local transport = if f.entry
		then nil
		else luau.load(fs.readFile("tests/published/OwnerTestTransport.luau"), { environment = environment })()
	local options = {
		owner = f.owner,
		target = { universeId = 123, placeId = 456, ownerUserId = 7738981129 },
		optIn = true,
		cancelWorker = function()
			f.cancels += 1
		end,
		run = function(check, progress)
			f.runs += 1
			check()
			progress(1)
			if mode == "extra" then
				f.players.PlayerAdded:Fire({}) -- fires before list update: must still cancel
			elseif mode == "leave" then
				f.players.PlayerRemoving:Fire(f.owner)
			elseif mode == "timeout" then
				f.now = 601
				f.run.Heartbeat:Fire()
			elseif mode == "destination-change" then
				f.game.PlaceId = 999
				f.run.Heartbeat:Fire()
			end
			local ok = pcall(check)
			f.cleaned = true
			return { results = {}, matrixPassed = true }, ok, true
		end,
	}
	if f.entry then
		f.ok, f.error = pcall(luau.load(f.entry, { environment = environment }))
	else
		f.ok, f.stop = pcall(transport.start, Policy, Adapter, Admission, options)
	end
	function f.restart()
		return pcall(transport.start, Policy, Adapter, Admission, options)
	end
	f.folder = f.gui:FindFirstChild("WindStepTestSession")
	function f.ask(action, page, owner)
		f.now += 0.21
		f.folder:FindFirstChild("Request").OnServerEvent:Fire(owner or f.owner, action, page)
		return f.sent[#f.sent]
	end
	function f.drain()
		for _, job in f.jobs do
			job()
		end
		table.clear(f.jobs)
	end
	function f.noLeaks()
		for _, s in f.signals do
			for _, c in s.list do
				assert(not c.Connected, "live listener")
			end
		end
		for _, object in f.instances do
			if object.ClassName == "RemoteEvent" or object.Name == "WindStepTestSession" then
				assert(object.destroyed and object.Parent == nil, "live transport instance")
			end
		end
	end
	return f
end
return fixture
