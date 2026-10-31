-- Actual delivery renderer + tree composed with real pure receipt/map/outer gate.
-- Mocked engine only: not a device/visual/network acceptance test.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config = require("../src/shared/Config")
local Gate = require("../src/shared/CastWarningGate")
local Plan = require("../src/shared/CastDeliveryPlan")
local Geometry = require("../src/shared/CastGeometry")
local Receipts = require("../src/shared/CastReceipts")
local Map = require("../src/shared/CastCommandMap")
local Store = require("../src/shared/CastDeliveryStore")
local Dispatch = require("../src/shared/CastDeliveryDispatch")
local Inbox = require("../src/shared/CastInbox")
local function command(kind, seq)
	local a = {
		castId = "g:" .. tostring(seq or 1),
		generation = "g",
		seq = seq or 1,
		casterUserId = 42,
		characterKey = "old",
		slotRevision = 4,
		moveId = "m",
		acceptedAt = 100,
		releaseAt = 101,
		endsAt = 105,
		origin = { x = 2, y = 3, z = 4 },
		centre = { x = 5, y = 6, z = 7 },
		aim = { x = 0, y = 0, z = -1 },
		geometry = assert(Geometry.capture({
			delivery = {
				kind = kind,
				params = {
					speed = 10,
					range = 40,
					count = 5,
					spreadDeg = 60,
					radius = 17,
					hitbox = { x = 2, y = 3, z = 4 },
				},
			},
		}, {})),
	}
	local r = Receipts.new(Config.CastClientReceipt)
	assert(Receipts.put(r, a, 0) == "stored")
	return assert(
		Map.accepted({ m = { delivery = kind, worldWarning = kind ~= "Self" } }, Receipts.get(r, a.castId, 0))
	)
end
local function fixture(capacity, useStore)
	local f = { objects = {}, commands = {}, faults = {}, frames = {}, stale = {}, disposers = {} }
	local function fault(name)
		if (f.faults[name] or 0) > 0 then
			f.faults[name] -= 1
			error("injected " .. name)
		end
	end
	local function new(class)
		fault("allocate-" .. class)
		local props = { ClassName = class, dead = false }
		local o
		o = setmetatable({}, {
			__index = function(_, k)
				if k == "Destroy" then
					return function()
						if props.dead then
							return
						end
						props.dead = true
						for _, child in f.objects do
							if child.Parent == o then
								child:Destroy()
							end
						end
					end
				end
				return props[k]
			end,
			__newindex = function(_, k, v)
				if k == "Parent" then
					local state = if f.borrowedOwner then f.owner.state() else nil
					local owned = state
						and (
							state.gate.gate.bridge.resources.count > 0
							or state.gate.reserve.bridge.resources.count > 0
						)
					assert(if f.borrowedOwner then owned else f.bound, "activation before ownership")
					fault("parent-" .. class)
				elseif k == "CFrame" then
					fault("update")
				end
				props[k] = v
			end,
		})
		table.insert(f.objects, o)
		return o
	end
	local Identity = require("../src/shared/CastCharacterIdentity")
	local modules = {
		CastDeliveryPlan = Plan,
		CastCommandMap = Map,
		CastBridge = {},
		CastWarningReserve = {},
		Config = Config,
		CastDeliveryDispatch = Dispatch,
		CastCharacterIdentity = Identity,
		CastInbox = Inbox,
		CastContactInbox = require("../src/shared/CastContactInbox"),
	}
	local shared = {}
	for k in modules do
		shared[k] = k
	end
	f.localNow, f.serverNow = 0, 100
	f.listeners, f.heartbeats, f.oldBeats = {}, {}, {}
	local net = {}
	for _, name in { "CastAccepted", "CastTerminal", "CastContact", "CastDisposition" } do
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
			return f.serverNow
		end,
	}
	f.model = {
		raw = Identity.encode({ generation = "g", characterKey = "old", slotRevision = 4, casterUserId = 42 }),
		present = true,
		humanoid = { Health = 100 },
		GetAttribute = function(self)
			return self.raw
		end,
		IsDescendantOf = function(self, parent)
			assert(parent == world)
			return self.present
		end,
		FindFirstChildOfClass = function(self)
			return self.humanoid
		end,
	}
	f.player = { UserId = 42, Character = f.model }
	local players = {
		LocalPlayer = f.player,
		GetPlayerByUserId = function(_, id)
			return if id == 42 then f.player else nil
		end,
	}
	f.player.Parent = players
	local services = {
		Players = players,
		ReplicatedStorage = { Shared = shared },
		RunService = {
			Heartbeat = {
				Connect = function(_, fn)
					f.heartbeats[fn] = true
					table.insert(f.oldBeats, fn)
					return {
						Disconnect = function()
							f.heartbeats[fn] = nil
						end,
					}
				end,
			},
		},
	}
	local env = {
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		script = {
			Parent = {
				CastWorldTree = "CastWorldTree",
				CastCharacterClient = "CastCharacterClient",
				CastDeliveryFx = "CastDeliveryFx",
				CastReceiptClient = "CastReceiptClient",
				Net = "Net",
			},
		},
		require = function(k)
			return assert(modules[k], k)
		end,
		workspace = world,
		os = {
			clock = function()
				return f.localNow
			end,
		},
		Instance = { new = new },
		Vector3 = rb.Vector3,
		CFrame = rb.CFrame,
		Color3 = rb.Color3,
		Enum = rb.Enum,
	}
	for _, name in
		{ "CastWorldTree", "CastDeliveryFx", "CastCharacterClient", "CastReceiptClient", "CastDeliveryClient" }
	do
		modules[name] =
			luau.load(fs.readFile("src/client/" .. name .. ".luau"), { injectGlobals = true, environment = env })()
	end
	f.owner, f.receipts = modules.CastDeliveryClient, modules.CastReceiptClient
	function f:beat(localNow, serverNow)
		self.localNow, self.serverNow = localNow, serverNow
		for callback in self.heartbeats do
			callback()
		end
	end
	function f:wire(cmd)
		local a = table.clone(cmd.metadata.acceptance)
		local function vector(v)
			return rb.Vector3.new(v.x, v.y, v.z)
		end
		a.origin, a.aim = vector(a.origin), vector(a.aim)
		a.centre = if a.centre then vector(a.centre) else nil
		self.listeners.CastAccepted(a)
	end
	function f:startOwner()
		self:stop() -- dispose unused manual fixture ownership first
		self.borrowedOwner = true
		self.stopReceipts = self.receipts.start()
		self.stopOwner = self.owner.start({ m = { delivery = "Zone", worldWarning = true } })
	end
	function f:stopOwnerAll()
		self.stopOwner()
		self.stopReceipts()
		assert(next(self.heartbeats) == nil and next(self.listeners) == nil and #self:live() == 0)
	end
	f.store = if useStore then Store.new(16) else nil
	f.fx = modules.CastDeliveryFx
	f.primary, f.reserve = f.fx.new(capacity or 256), f.fx.new(capacity or 64)
	f.pose = { generation = "g", characterKey = "old", slotRevision = 4, casterUserId = 42, alive = true }
	f.identity = table.clone(f.pose)
	local function wrap(frame, reserve)
		local copy = table.clone(frame)
		copy.bind = function(slot, scope, dispose)
			local callback = if reserve then scope else dispose
			if f.refuseBind and not reserve then
				return nil
			end
			local ticket = if reserve then frame.bind(slot, callback) else frame.bind(slot, scope, callback)
			if ticket then
				f.bound = true
				table.insert(f.disposers, callback)
			end
			return ticket
		end
		copy.isCurrent = function(ticket)
			return not f.stale[if reserve then "reserve" else "primary"] and frame.isCurrent(ticket)
		end
		return copy
	end
	f.gate = Gate.new(Config.CastWarning, function(frame)
		table.insert(f.frames, { action = frame.action, now = frame.now, key = frame.key })
		local e = if f.store then Store.get(f.store, frame.key) else nil
		local cmd = if f.store then (if e then e.accepted else nil) else f.commands[frame.key]
		return f.fx.primary(f.primary, wrap(frame, false), if cmd then cmd.metadata else nil, f.identity, f.pose)
	end, function(frame)
		local e = if f.store then Store.get(f.store, frame.key) else nil
		local cmd = if f.store then (if e then e.accepted else nil) else f.commands[frame.key]
		return f.fx.warning(f.reserve, wrap(frame, true), if cmd then cmd.metadata else nil)
	end)
	function f:dispatch(cursor, inbox)
		Gate.destroy(self.gate)
		if self.store then
			Store.destroy(self.store)
		end
		self.inbox = inbox or Inbox.new(Config.CastClientReceipt)
		self.dispatcher = Dispatch.new(
			self.inbox,
			{ m = { delivery = "Zone", worldWarning = true } },
			Config.CastWarning,
			function(frame, entry)
				table.insert(self.frames, { action = frame.action, key = frame.key, now = frame.now })
				local c = if entry then entry.accepted else nil
				return self.fx.primary(
					self.primary,
					wrap(frame, false),
					if c then c.metadata else nil,
					if entry then entry.identity else nil,
					self.pose
				)
			end,
			function(frame, entry)
				local c = if entry then entry.accepted else nil
				return self.fx.warning(self.reserve, wrap(frame, true), if c then c.metadata else nil)
			end,
			cursor
		)
		self.gate, self.store = self.dispatcher.gate, self.dispatcher.store
	end
	function f:accept(cmd, localNow, serverNow)
		if self.store then
			local result = Store.accept(self.store, cmd)
			assert(result == "stored" or result == "duplicate", result)
			cmd = assert(Store.get(self.store, cmd.key).accepted)
		end
		self.commands[cmd.key] = cmd
		local outcome = Gate.accept(self.gate, cmd.key, cmd.timeline, localNow or 0, serverNow or 100)
		if self.store then
			Store.prune(self.store, self.gate)
		end
		return outcome
	end
	function f:live(class)
		local out = {}
		for _, o in self.objects do
			if not o.dead and (not class or o.ClassName == class) then
				table.insert(out, o)
			end
		end
		return out
	end
	function f:stop()
		if self.dispatcher then
			Dispatch.destroy(self.dispatcher)
		end
		Gate.destroy(self.gate)
		if self.store then
			Store.prune(self.store, self.gate)
			assert(self.store.count == 0)
			Store.destroy(self.store)
		end
		self.fx.destroy(self.primary)
		self.fx.destroy(self.reserve)
		assert(self.primary.count == 0 and self.reserve.count == 0 and #self:live() == 0, "leaked resources")
	end
	return f
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS delivery-engine " .. name)
end
local function near(a, b)
	assert(math.abs(a - b) < 1e-5, tostring(a) .. " vs " .. tostring(b))
end

test("prediction allocates nothing; adoption seeks without replay or repeat allocation", function()
	local f, c = fixture(), command("Projectile")
	assert(Gate.predict(f.gate, c.key, 0, 100) == "predict")
	assert(#f.objects == 0)
	f:accept(c, 0.5, 100.5)
	assert(f.frames[#f.frames].action == "adopt")
	local root, part = f:live("Folder")[1], f:live("Part")[1]
	assert(root and part and f.primary.count == 1)
	for i = 1, 30 do
		assert(Gate.tick(f.gate, 0.5 + i / 10, 100.5 + i / 10))
	end
	assert(#f.objects == 2 and f:live("Folder")[1] == root and f:live("Part")[1] == part)
	near(part.CFrame.Position.Z, -21)
	assert(part.Size == rb.Vector3.new(2, 3, 4))
	f:stop()
end)
test("late volley seeks all five captured rays; stable children", function()
	local f, c = fixture(), command("Volley")
	f:accept(c, 0, 103)
	local expected = assert(Plan.accepted(c.metadata, 103, nil, false))
	assert(#f:live("Part") == 5)
	for i, p in f:live("Part") do
		local e = expected.world[i].position
		near(p.CFrame.Position.X, e.x)
		near(p.CFrame.Position.Z, e.z)
	end
	Gate.tick(f.gate, 1, 104)
	assert(#f.objects == 6)
	f:stop()
end)
test("death pose retirement and replacement preserve accepted zone centre", function()
	local f, c = fixture(), command("Zone")
	f:accept(c)
	local p = f:live("Part")[1]
	assert(p.Size == rb.Vector3.new(0.06, 34, 34) and p.CFrame.Position == rb.Vector3.new(5, 6, 7))
	f.pose.alive = false
	assert(Gate.retirePose(f.gate, c.key, 0.1, 100.1))
	f.pose.characterKey, f.pose.alive = "replacement", true
	Gate.tick(f.gate, 1, 101)
	assert(f:live("Part")[1] == p and p.CFrame.Position == rb.Vector3.new(5, 6, 7))
	Gate.tick(f.gate, 5, 105)
	assert(p.dead and f.primary.count == 0)
	f:stop()
end)
test("Self and Burst without a fresh original sample are allocation-free", function()
	local f = fixture()
	f:accept(command("Self"))
	assert(#f.objects == 0 and f.gate.gate.bridge.renderFailures == 0)
	f:accept(command("Burst", 2))
	assert(#f.objects == 0 and f.gate.gate.bridge.renderFailures == 0)
	assert(f.gate.reserve.bridge.renderFailures == 0 and f.gate.fallbacks == 0)
	f:stop()
end)
test("single engine failures clean primary before identical reserve warning", function()
	for _, fault in { "allocate-Folder", "allocate-Part", "parent-Part", "parent-Folder", "update" } do
		local f, c = fixture(), command("Zone")
		f.faults[fault] = 1
		f:accept(c)
		assert(f.primary.count == 0 and f.reserve.count == 1, fault)
		assert(#f:live("Folder") == 1 and #f:live("Part") == 1, fault)
		assert(f:live("Part")[1].CFrame.Position == rb.Vector3.new(5, 6, 7))
		Gate.retirePose(f.gate, c.key, 0.2, 100.2) -- primary failed; no pose lease remains
		assert(f.reserve.count == 1)
		Gate.cancel(f.gate, c.key, 0.5, 100.5)
		assert(f.reserve.count == 0 and #f:live() == 0)
		f:stop()
	end
end)
test("bind refusal falls back; late update fault replaces rather than duplicates", function()
	local f, c = fixture(), command("Projectile")
	f.refuseBind = true
	f:accept(c)
	assert(f.primary.count == 0 and f.reserve.count == 1)
	f:stop()
	f = fixture()
	f:accept(c)
	local old = f:live("Folder")[1]
	f.faults.update = 1
	Gate.tick(f.gate, 2, 102)
	assert(old.dead and f.primary.count == 0 and f.reserve.count == 1)
	near(f:live("Part")[1].CFrame.Position.Z, -6)
	f:stop()
end)
test("stale primary ticket routes reserve; dual failure leaks nothing", function()
	local f, c = fixture(), command("Zone")
	f:accept(c)
	f.stale.primary = true
	Gate.tick(f.gate, 1, 101)
	assert(f.primary.count == 0 and f.reserve.count == 1)
	f:stop()
	f = fixture()
	f.faults["allocate-Folder"] = 2
	f:accept(c)
	assert(f.primary.count == 0 and f.reserve.count == 0 and #f:live() == 0)
	assert(f.gate.reserve.bridge.renderFailures == 1)
	f:stop()
end)
test("bounded pools refuse overflow without evicting accepted warnings", function()
	local f = fixture(1)
	for i = 1, 3 do
		f:accept(command("Zone", i))
	end
	assert(f.primary.count == 1 and f.reserve.count == 1 and #f:live("Part") == 2)
	assert(f.gate.reserve.bridge.renderFailures == 1)
	Gate.cancel(f.gate, "g:1", 1, 101)
	f:accept(command("Zone", 4), 1, 101)
	assert(f.primary.count == 1 and f.reserve.count == 1)
	f:stop()
end)
test("future admission never allocates early; terminal before acceptance never renders", function()
	local f, c = fixture(), command("Zone")
	f:accept(c, 0, 99.8)
	assert(#f.objects == 0)
	Gate.tick(f.gate, 0.3, 100.1)
	assert(f.primary.count == 1)
	local c2 = command("Zone", 2)
	Gate.cancel(f.gate, c2.key, 0.4, 100.2)
	local allocations = #f.objects
	f:accept(c2, 0.5, 100.3)
	assert(#f.objects == allocations)
	f:stop()
end)
test("retained metadata identity cannot change under an existing tree", function()
	local f, c = fixture(), command("Zone")
	f:accept(c)
	local old = f:live("Folder")[1]
	f.commands[c.key] = command("Zone") -- equal values, different immutable receipt
	Gate.tick(f.gate, 1, 101)
	assert(old.dead and f.primary.count == 0 and f.reserve.count == 1)
	f:stop()
end)
test("wrong key and timeline refuse rather than drawing unrelated metadata", function()
	for _, field in { "key", "releaseAt" } do
		local f, c = fixture(), command("Zone")
		local bad = table.clone(c)
		if field == "key" then
			bad.key = "g:bad"
		else
			bad.timeline = table.clone(c.timeline)
			bad.timeline.releaseAt += 0.5
		end
		f:accept(bad)
		assert(#f.objects == 0 and f.primary.count == 0 and f.reserve.count == 0)
		f:stop()
	end
end)
test("old disposers cannot clear reused key; teardown works in either order", function()
	local f, c = fixture(), command("Zone")
	f:accept(c)
	local oldDispose = f.disposers[1]
	Gate.cancel(f.gate, c.key, 1, 101)
	-- Fresh outer gate is the only valid reuse after terminals; pool remains empty.
	Gate.destroy(f.gate)
	f.gate = Gate.new(Config.CastWarning, function(frame)
		return f.fx.primary(f.primary, frame, c.metadata, f.identity, f.pose)
	end, function()
		return false
	end)
	Gate.accept(f.gate, c.key, c.timeline, 0, 100)
	assert(f.primary.count == 1)
	oldDispose()
	assert(f.primary.count == 1 and #f:live("Part") == 1)
	f.fx.destroy(f.primary)
	f.fx.destroy(f.primary)
	assert(#f:live() == 0)
	assert(Gate.tick(f.gate, 1, 101)) -- closed renderer fails safely
	f:stop()
	f:stop()
end)
test("pinned registry composes future prediction adoption remap and late fallback", function()
	local f, c = fixture(nil, true), command("Zone")
	assert(Store.predict(f.store, c.key, f.identity) == "stored")
	Gate.predict(f.gate, c.key, 0, 99.8)
	f:accept(c, 0, 99.8)
	assert(#f.objects == 0 and f.store.count == 1)
	Gate.tick(f.gate, 0.3, 100.1)
	Store.prune(f.store, f.gate)
	local root = f:live("Folder")[1]
	assert(root and f.primary.count == 1)
	local remapped = Map.accepted({ m = c.metadata.style }, { acceptance = c.metadata.acceptance })
	f:accept(remapped, 0.4, 100.2)
	assert(Store.get(f.store, c.key).accepted == c and not root.dead)
	table.clear(f.commands) -- renderer must use pinned registry, not the receipt producer
	f.faults.update = 1
	Gate.tick(f.gate, 2.2, 102)
	Store.prune(f.store, f.gate)
	assert(root.dead and f.primary.count == 0 and f.reserve.count == 1 and f.store.count == 1)
	assert(f.reserve.entries[c.key].metadata == c.metadata)
	Gate.cancel(f.gate, c.key, 3.2, 103)
	Store.prune(f.store, f.gate)
	assert(f.store.count == 0 and #f:live() == 0)
	f:stop()
end)
test("repeated accepted lease turnover keeps one bounded tree and no pinned residue", function()
	local f = fixture(1, true)
	for i = 1, 100 do
		local c = command("Zone", i)
		local a = table.clone(c.metadata.acceptance)
		a.acceptedAt, a.releaseAt, a.endsAt = 100 + i, 100 + i, 100 + i + 0.5
		local r = Receipts.new(Config.CastClientReceipt)
		assert(Receipts.put(r, a, 0) == "stored")
		c = assert(Map.accepted({ m = c.metadata.style }, Receipts.get(r, a.castId, 0)))
		f:accept(c, i, 100 + i)
		assert(f.primary.count == 1 and f.store.count == 1 and #f:live("Part") == 1)
		Gate.tick(f.gate, i + 0.5, 100 + i + 0.5)
		Store.prune(f.store, f.gate)
		assert(f.primary.count == 0 and f.reserve.count == 0 and f.store.count == 0 and #f:live() == 0)
	end
	f:stop()
end)
test("borrowed dispatcher adopts actual tree, survives death, seeks fallback and cancels", function()
	local f, c = fixture(1), command("Zone")
	f:dispatch()
	assert(Dispatch.predict(f.dispatcher, c.key, f.identity, 0, 100) == "predict")
	assert(Inbox.accept(f.inbox, c.metadata.acceptance, 0) == "stored")
	assert(Dispatch.tick(f.dispatcher, 0, 100))
	assert(f.primary.count == 1 and f.frames[#f.frames].action == "adopt")
	local root = f:live("Folder")[1]
	f.pose.alive = false
	Dispatch.retirePose(f.dispatcher, c.key, 0.1, 100.1)
	assert(not root.dead and f.primary.count == 1)
	f.faults.update = 1
	Dispatch.tick(f.dispatcher, 0.2, 100.2)
	assert(root.dead and f.primary.count == 0 and f.reserve.count == 1 and f.store.count == 1)
	Inbox.terminal(f.inbox, c.key, "cancel", 100.3, 0.3)
	Dispatch.tick(f.dispatcher, 0.3, 100.3)
	assert(#f:live() == 0 and f.store.count == 0)
	f:stop()
end)
test("borrowed dispatcher cancels two due futures without allocating engine objects", function()
	local f = fixture()
	f:dispatch()
	for i = 1, 2 do
		local a = table.clone(command("Zone", i).metadata.acceptance)
		a.acceptedAt, a.releaseAt, a.endsAt = 100.4, 101.4, 105.4
		assert(Inbox.accept(f.inbox, a, 0) == "stored")
	end
	Dispatch.tick(f.dispatcher, 0, 100)
	assert(f.gate.gate.count == 2 and #f.objects == 0)
	for i = 1, 2 do
		Inbox.terminal(f.inbox, "g:" .. i, "cancel", 100.4, 0.4)
	end
	Dispatch.tick(f.dispatcher, 0.4, 100.4)
	assert(#f.objects == 0 and f.store.count == 0)
	f:stop()
end)
test("borrowed dispatcher closes on inbox loss and restart never replays old trees", function()
	local f, c = fixture(), command("Zone")
	f:dispatch()
	Inbox.accept(f.inbox, c.metadata.acceptance, 0)
	Dispatch.tick(f.dispatcher, 0, 100)
	assert(#f:live() > 0)
	Inbox.destroy(f.inbox)
	assert(not Dispatch.tick(f.dispatcher, 0.1, 100.1))
	assert(#f:live() == 0)
	local token = assert(Dispatch.destroy(f.dispatcher))
	f:dispatch(token)
	Inbox.accept(f.inbox, c.metadata.acceptance, 0)
	Dispatch.tick(f.dispatcher, 0, 100)
	assert(#f:live() == 0 and f.store.count == 0)
	f:stop()
end)
test("actual borrowed receipt owner resolves pose then retires only pose on death", function()
	local f, c = fixture(), command("Zone")
	f:startOwner()
	assert(f.owner.start({}) == f.stopOwner)
	f:wire(c)
	f:beat(0, 100)
	local state = assert(f.owner.state())
	local resource = state.gate.gate.bridge.resources.owners[c.key]
	assert(
		resource and not resource.poseClosed and #f:live() > 0,
		`resource={resource} live={#f:live()} store={state.store.count} receipts={state.inbox.acceptances.serial} refusals={state.refusals} raw={f.model.raw}`
	)
	f.model.humanoid.Health = 0
	f:beat(0.1, 100.1)
	assert(resource.poseClosed and #f:live() > 0 and state.store.count == 1)
	f.model.humanoid.Health = 100
	f:beat(0.2, 100.2)
	assert(resource.poseClosed)
	f:stopOwnerAll()
end)
test("late missing observer can resolve but replacement cannot inherit seen pose", function()
	local f, c = fixture(), command("Zone")
	local raw = f.model.raw
	f.model.raw = nil
	f:startOwner()
	f:wire(c)
	f:beat(0, 100)
	local state = f.owner.state()
	local resource = state.gate.gate.bridge.resources.owners[c.key]
	assert(resource and not resource.poseClosed and #f:live() > 0)
	f.model.raw = raw
	f:beat(0.1, 100.1)
	f.player.Character = table.clone(f.model)
	f.player.Character.raw = nil
	f:beat(0.2, 100.2)
	assert(resource.poseClosed and #f:live() > 0)
	f:stopOwnerAll()
end)
test("slot mismatch and missing world descendant retire pose not accepted warning", function()
	for _, reason in { "slot", "stream", "leave" } do
		local f, c = fixture(), command("Zone")
		f:startOwner()
		f:wire(c)
		f:beat(0, 100)
		local resource = f.owner.state().gate.gate.bridge.resources.owners[c.key]
		if reason == "slot" then
			f.model.raw = "1:g3:old42:5"
		elseif reason == "stream" then
			f.model.present = false
		else
			f.player.Parent = nil
		end
		f:beat(0.1, 100.1)
		assert(resource.poseClosed and #f:live() > 0)
		f:stopOwnerAll()
	end
end)
test("actual owner prediction requires fresh local identity and adopts immutable receipt", function()
	local f, c = fixture(), command("Zone")
	f:startOwner()
	local identity = { generation = "g", characterKey = "old", slotRevision = 4, casterUserId = 42 }
	local bad = table.clone(identity)
	bad.casterUserId = 43
	assert(f.owner.predict("g:1", bad) == "refuse")
	f.model.humanoid.Health = 0
	assert(f.owner.predict("g:1", identity) == "refuse")
	f.model.humanoid.Health = 100
	assert(f.owner.predict("g:1", identity) ~= "refuse")
	assert(#f:live() == 0)
	local state = f.owner.state()
	local lease = state.gate.gate.bridge.leases[c.key]
	f:wire(c)
	f:beat(0.1, 100.1)
	assert(state.gate.gate.bridge.leases[c.key] == lease and #f:live() > 0)
	f:stopOwnerAll()
	assert(f.owner.predict("g:2", identity) == "refuse")
end)
test("owner stops safely on borrowed receipt loss and stale callbacks cannot kill restart", function()
	local f, c = fixture(), command("Zone")
	f:startOwner()
	f:wire(c)
	f:beat(0, 100)
	local oldStop = f.stopOwner
	f.stopReceipts()
	f:beat(0.1, 100.1)
	assert(f.owner.state() == nil and #f:live() == 0 and next(f.heartbeats) == nil)
	f.stopReceipts = f.receipts.start()
	f.stopOwner = f.owner.start({ m = { delivery = "Zone", worldWarning = true } })
	oldStop()
	f.oldBeats[2]() -- stopped delivery callback must be inert
	f:wire(c)
	f:beat(0.2, 100.2)
	assert(f.owner.state() and #f:live() == 0) -- cursor also suppresses fresh inbox replay
	f:stopOwnerAll()
end)
test("same inbox restart suppresses unpolled receipt and permits later fresh cast", function()
	local f, c = fixture(), command("Zone")
	f:startOwner()
	f:wire(c)
	f.stopOwner()
	f.stopOwner = f.owner.start({ m = { delivery = "Zone", worldWarning = true } })
	f:beat(0, 100)
	assert(#f:live() == 0)
	local fresh = command("Zone", 2)
	local a = table.clone(fresh.metadata.acceptance)
	a.acceptedAt = 100.1
	a.releaseAt = 101.1
	a.endsAt = 105.1
	f:wire({ metadata = { acceptance = a } })
	f:beat(0.1, 100.1)
	assert(#f:live() > 0)
	f:stopOwnerAll()
end)
test("one hundred actual owner restart cycles leak neither subscriptions nor trees", function()
	local f = fixture()
	f:startOwner()
	for n = 1, 100 do
		local c = command("Zone", n)
		local a = table.clone(c.metadata.acceptance)
		a.acceptedAt = 100 + n
		a.releaseAt = 101 + n
		a.endsAt = 105 + n
		f:beat(n, 100 + n)
		f:wire({ metadata = { acceptance = a } })
		f:beat(n, 100 + n)
		assert(#f:live() > 0)
		f.stopOwner()
		assert(#f:live() == 0)
		f.stopOwner = f.owner.start({ m = { delivery = "Zone", worldWarning = true } })
	end
	f:stopOwnerAll()
end)
test("actual owner terminal batch cancels futures before geometry and failure routes reserve", function()
	local f, c = fixture(), command("Zone")
	f:startOwner()
	local a = table.clone(c.metadata.acceptance)
	a.acceptedAt = 100.4
	a.releaseAt = 101.4
	a.endsAt = 105.4
	f:wire({ metadata = { acceptance = a } })
	f:beat(0, 100)
	assert(#f:live() == 0)
	f.listeners.CastTerminal({ castId = c.key, reason = "cancel", at = 100.4 })
	f:beat(0.4, 100.4)
	assert(#f.objects == 0)
	f:stopOwnerAll()
	f, c = fixture(), command("Zone")
	f:startOwner()
	f.faults.update = 1
	f:wire(c)
	f:beat(0, 100)
	local state = f.owner.state()
	assert(
		state.gate.gate.bridge.resources.count == 0 and state.gate.reserve.bridge.resources.count == 1 and #f:live() > 0
	)
	f.model.humanoid.Health = 0
	f:beat(0.1, 100.1)
	assert(#f:live() > 0)
	f:stopOwnerAll()
end)
print("DELIVERY ENGINE: PASS (" .. count .. " cases)")
