-- Actual receipt listener -> contact owner -> Roblox renderer, with a fake engine.
-- No claim of device/visual quality or live-network proof.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config = require("../src/shared/Config")
local Inbox = require("../src/shared/CastInbox")
local Contacts = require("../src/shared/CastContactInbox")
local Dispatch = require("../src/shared/CastContactDispatch")
local Map = require("../src/shared/CastCommandMap")
local Feel = require("../src/shared/HitFeel")
local All = require("../src/shared/Content/All")
local Registry = require("../src/shared/Registry")
local catalog = Map.catalog(Registry.build(All.content(Config)).moves)
local sources = {}
for _, name in { "CastReceiptClient", "CastContactClient", "CastContactFx" } do
	sources[name] = fs.readFile("src/client/" .. name .. ".luau")
end
local function fixture(capacity)
	local f = { now = 100, server = 1000000, objects = {}, bursts = 0, routes = {}, listeners = {}, ticks = {} }
	local cfg = table.clone(Config)
	cfg.CastContactPresentation = { capacity = capacity or 128, perContact = 4, effectSeconds = 0.6 }
	local modules = {
		Config = cfg,
		CastInbox = Inbox,
		CastContactInbox = Contacts,
		CastContactDispatch = Dispatch,
		CastCommandMap = Map,
		HitFeel = Feel,
	}
	local shared = {}
	for k in modules do
		shared[k] = k
	end
	local net = {}
	for _, name in { "CastAccepted", "CastTerminal", "CastDisposition", "CastContact" } do
		net[name] = {
			On = function(fn)
				assert(not f.listeners[name])
				f.listeners[name] = fn
				return function()
					f.listeners[name] = nil
				end
			end,
		}
	end
	modules.Net = net
	local world = {
		GetServerTimeNow = function()
			return f.server
		end,
	}
	local heartbeat = {
		Connect = function(_, fn)
			local c = { fn = fn, connected = true }
			function c:Disconnect()
				self.connected = false
			end
			table.insert(f.ticks, c)
			return c
		end,
	}
	local function new(class)
		if f.failClass == class then
			error("allocation failure")
		end
		local values = { ClassName = class, destroyed = false }
		local object
		object = setmetatable({}, {
			__index = function(_, key)
				if key == "Destroy" then
					return function()
						if values.destroyed then
							return
						end
						values.destroyed = true
						for _, child in f.objects do
							if child.Parent == object then
								child:Destroy()
							end
						end
						values.Parent = nil
					end
				end
				if key == "Emit" then
					return function(_, count)
						if f.failEmit then
							error("emit failure")
						end
						assert(values.Parent.Parent == world, "emit before attached")
						assert(count >= 0 and count <= 32)
						f.bursts += 1
					end
				end
				return values[key]
			end,
			__newindex = function(_, key, value)
				if f.failProperty == key or (key == "Parent" and f.failParentClass == class) then
					error("property failure")
				end
				values[key] = value
			end,
		})
		table.insert(f.objects, object)
		return object
	end
	local services = { ReplicatedStorage = { Shared = shared }, RunService = { Heartbeat = heartbeat } }
	local env = {
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		workspace = world,
		script = { Parent = { Net = "Net", CastReceiptClient = "CastReceiptClient", CastContactFx = "CastContactFx" } },
		require = function(id)
			assert(modules[id], id)
			return modules[id]
		end,
		os = {
			clock = function()
				return f.now
			end,
		},
		Instance = { new = new },
		Vector3 = rb.Vector3,
		Vector2 = rb.Vector2,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		NumberRange = rb.NumberRange,
		UDim2 = rb.UDim2,
		Enum = rb.Enum,
	}
	for _, name in { "CastReceiptClient", "CastContactFx", "CastContactClient" } do
		modules[name] = luau.load(sources[name], { injectGlobals = true, environment = env })()
	end
	f.receipts, f.client, f.fx = modules.CastReceiptClient, modules.CastContactClient, modules.CastContactFx
	local render = f.fx.render
	f.fx.render = function(frame, command)
		table.insert(f.routes, command)
		if f.staleTicket then
			local copy = table.clone(frame)
			copy.isCurrent = function()
				return false
			end
			return render(copy, command)
		end
		if f.refuseBind then
			local copy = table.clone(frame)
			copy.bind = function(_, dispose)
				dispose()
				return nil
			end
			return render(copy, command)
		end
		return render(frame, command)
	end
	function f:start()
		self.stopReceipts = self.receipts.start()
		self.stop = self.client.start(catalog)
		assert(self.client.start(catalog) == self.stop)
	end
	function f:tick(delta)
		self.now += delta or 0
		self.server += delta or 0
		for _, c in self.ticks do
			if c.connected then
				c.fn()
			end
		end
	end
	function f:accept(seq, move)
		self.listeners.CastAccepted({
			castId = "gen:" .. seq,
			generation = "gen",
			seq = seq,
			moveId = move or "move.rime.fall",
			casterUserId = 42,
			characterKey = "old-character",
			slotRevision = 2,
			acceptedAt = self.server,
			releaseAt = self.server + 0.1,
			endsAt = self.server + 1,
			aim = rb.Vector3.zAxis,
			origin = rb.Vector3.zero,
			centre = rb.Vector3.new(5, 0, -10),
		})
	end
	function f:contact(seq, amount, at)
		self.listeners.CastContact({
			castId = "gen:" .. seq,
			ordinal = 1,
			resource = 1,
			tick = 1,
			targetKey = "target",
			at = at or self.server,
			amount = amount or 4.4,
			position = rb.Vector3.new(1, 2, 3),
			direction = rb.Vector3.zAxis,
		})
	end
	function f:terminal(seq)
		self.listeners.CastTerminal({ castId = "gen:" .. seq, reason = "completed", at = self.server })
	end
	function f:alive(class)
		local out = {}
		for _, o in self.objects do
			if not o.destroyed and (not class or o.ClassName == class) then
				table.insert(out, o)
			end
		end
		return out
	end
	function f:finish()
		self.stop()
		self.stop()
		self.stopReceipts()
		assert(#self:alive() == 0, "leaked engine objects")
		assert(self.client.state() == nil)
		for _, c in self.ticks do
			assert(not c.connected, "heartbeat leak")
		end
	end
	return f
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS engine " .. name)
end
for _, order in { "ACT", "ATC", "CAT", "CTA", "TAC", "TCA" } do
	test(order .. " generic/style at consumption + independent terminal", function()
		local f = fixture()
		f:start()
		for i = 1, 3 do
			local e = order:sub(i, i)
			if e == "A" then
				f:accept(1)
			elseif e == "T" then
				f:terminal(1)
			else
				f:contact(1)
			end
			f:tick()
		end
		local styled = order == "ACT" or order == "ATC"
		assert(#f.routes == 1 and (f.routes[1].fx ~= nil) == styled)
		assert(f.bursts == 1 and #f:alive() == 4)
		local anchor, label = f:alive("Part")[1], f:alive("TextLabel")[1]
		assert(
			anchor.Position == rb.Vector3.new(1, 2, 3)
				and anchor.Anchored
				and not anchor.CanCollide
				and not anchor.CanTouch
				and not anchor.CanQuery
		)
		assert(label.Text == "4")
		assert(label.TextColor3 == (if styled then rb.Color3.fromRGB(180, 235, 255) else rb.Color3.new(1, 1, 1)))
		for _ = 1, 100 do
			f:contact(1)
			f:tick()
		end
		assert(f.bursts == 1, "replayed contact")
		f:tick(0.61)
		assert(#f:alive() == 0, "missed local expiry")
		f:finish()
	end)
end
test("missing startup owner fails", function()
	local f = fixture()
	assert(not pcall(f.client.start, catalog))
	assert(#f:alive() == 0)
end)
test("inbox retained across renderer stop/restart without replay", function()
	local f = fixture()
	f:start()
	f:contact(1)
	f:tick()
	f.stop()
	assert(#f:alive() == 0 and not f.receipts.contacts().closed)
	f.stop = f.client.start(catalog)
	f:tick()
	assert(f.bursts == 1)
	f:contact(2, 0)
	f:tick()
	assert(f.bursts == 2 and f:alive("TextLabel")[1].Text == "0")
	f:finish()
end)
test("closed borrowed owner disconnects engine heartbeat", function()
	local f = fixture()
	f:start()
	f:contact(1)
	f:tick()
	f.stopReceipts()
	f:tick()
	assert(f.client.state() == nil and #f:alive() == 0)
	f:finish()
end)
test("unknown content remains generic", function()
	local f = fixture()
	f:start()
	f:accept(1, "move.unknown")
	f:contact(1)
	f:tick()
	assert(f.routes[1].delivery == "Generic" and f.bursts == 1)
	f:finish()
end)
test("local expiry independent of backward server clock", function()
	local f = fixture()
	f:start()
	f:contact(1)
	f:tick()
	f.server -= 100
	f:tick(0.61)
	assert(#f:alive() == 0)
	f:finish()
end)
test("future contact waits; stale and malformed contact never render", function()
	local f = fixture()
	f:start()
	f:contact(1, 4, f.server + 0.5)
	f:tick()
	assert(f.bursts == 0)
	f:tick(0.51)
	assert(f.bursts == 1)
	f:contact(2, 4, f.server - 13)
	f:contact(3, -1)
	f:tick()
	assert(f.bursts == 1)
	f:finish()
end)
test("capacity refusal never evicts or replays", function()
	local f = fixture(1)
	f:start()
	f:contact(1)
	f:contact(2)
	f:tick()
	assert(f.bursts == 1 and f.client.state().overflow == 1)
	f:tick(0.61)
	f:contact(2)
	f:tick()
	assert(f.bursts == 1)
	f:contact(3)
	f:tick()
	assert(f.bursts == 2)
	f:finish()
end)
for _, failure in { "new", "property", "emit", "bind", "parent", "stale" } do
	test(failure .. " failure cleans all partial objects; no retry", function()
		local f = fixture()
		f:start()
		if failure == "new" then
			f.failClass = "TextLabel"
		elseif failure == "property" then
			f.failProperty = "Text"
		elseif failure == "parent" then
			f.failParentClass = "TextLabel"
		elseif failure == "stale" then
			f.staleTicket = true
		elseif failure == "emit" then
			f.failEmit = true
		else
			f.refuseBind = true
		end
		f:contact(1)
		f:tick()
		assert(f.client.state().renderFailures == 1 and #f:alive() == 0 and f.bursts == 0)
		f.failClass, f.failProperty, f.failEmit, f.refuseBind = nil, nil, nil, nil
		f.failParentClass, f.staleTicket = nil, nil
		f:contact(1)
		f:tick()
		assert(f.bursts == 0)
		f:contact(2)
		f:tick()
		assert(f.bursts == 1)
		f:finish()
	end)
end
test("bounded stream, no character/Player/legacy dependency", function()
	local f = fixture(2)
	f:start()
	for i = 1, 100 do
		f:contact(i)
		f:tick()
		assert(#f:alive() <= 8)
		f:tick(0.61)
		assert(#f:alive() == 0)
	end
	assert(f.bursts == 100)
	f:finish()
end)
assert(
	not fs.readFile("src/client/init.client.luau"):find("CastContactClient", 1, true),
	"premature duplicate live playback"
)
print("CONTACT ENGINE: PASS (" .. count .. " cases)")
