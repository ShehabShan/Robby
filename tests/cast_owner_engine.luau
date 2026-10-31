-- Actual client owners + actual pure state, with only engine acquisition mocked.
-- No live networking/device/visual acceptance claim.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local base = {}
for _, name in
	{
		"Config",
		"CastInbox",
		"CastContactInbox",
		"CastContactDispatch",
		"CastCommandMap",
		"CastDeliveryDispatch",
		"CastCharacterIdentity",
		"CastDeliveryPlan",
		"CastBridge",
		"CastWarningReserve",
		"HitFeel",
		"CastOwner",
	}
do
	base[name] = require("../src/shared/" .. name)
end
local function fixture()
	local f =
		{ stage = 0, fail = 0, subscriptions = {}, callbacks = {}, states = {}, log = {}, errors = {}, cleanFail = {} }
	local modules, shared, parent = {}, {}, {}
	for name, module in base do
		modules[name], shared[name] = table.clone(module), name
	end
	local function acquire(label)
		f.stage += 1
		table.insert(f.log, "acquire:" .. label)
		if f.fail == f.stage then
			error("injected acquisition " .. label)
		end
	end
	local function released(label)
		table.insert(f.log, "release:" .. label)
		if f.cleanFail[label] then
			error("injected cleanup " .. label)
		end
	end
	local function track(name, label)
		local module = modules[name]
		local create, destroy = module.new, module.destroy
		module.new = function(...)
			acquire(label)
			local state = create(...)
			table.insert(f.states, { state = state, label = label })
			return state
		end
		module.destroy = function(state)
			local result = destroy(state)
			released(label)
			return result
		end
	end
	track("CastInbox", "receipt")
	track("CastContactInbox", "contacts")
	track("CastDeliveryDispatch", "delivery")
	track("CastContactDispatch", "contact")
	local function subscribe(label, callback)
		acquire(label)
		local token = {}
		f.subscriptions[token] = label
		table.insert(f.callbacks, { label = label, fn = callback })
		return function()
			f.subscriptions[token] = nil
			released(label)
		end
	end
	modules.Net = {}
	for _, name in { "CastAccepted", "CastTerminal", "CastContact", "CastDisposition" } do
		modules.Net[name] = {
			On = function(fn)
				return subscribe(name, fn)
			end,
		}
	end
	local beats = 0
	local world = {
		GetServerTimeNow = function()
			if f.failClock then
				error("injected clock")
			end
			return 1000
		end,
	}
	local services = {
		ReplicatedStorage = { Shared = shared },
		Players = { LocalPlayer = { UserId = 42 } },
		RunService = {
			Heartbeat = {
				Connect = function(_, fn)
					beats += 1
					local disconnect = subscribe("heartbeat" .. beats, fn)
					return { Disconnect = disconnect }
				end,
			},
		},
	}
	for _, name in
		{
			"Net",
			"CastWorldTree",
			"CastDeliveryFx",
			"CastCharacterClient",
			"CastReceiptClient",
			"CastDeliveryClient",
			"CastContactFx",
			"CastContactClient",
			"CastPresentationClient",
		}
	do
		parent[name] = name
	end
	local env = {
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		workspace = world,
		script = { Parent = parent },
		require = function(name)
			return assert(modules[name], name)
		end,
		os = {
			clock = function()
				return 100
			end,
		},
		warn = function(problem)
			table.insert(f.errors, tostring(problem))
		end,
	}
	for _, name in
		{
			"CastWorldTree",
			"CastDeliveryFx",
			"CastCharacterClient",
			"CastReceiptClient",
			"CastDeliveryClient",
			"CastContactFx",
			"CastContactClient",
		}
	do
		modules[name] =
			luau.load(fs.readFile("src/client/" .. name .. ".luau"), { injectGlobals = true, environment = env })()
		if name == "CastDeliveryFx" then
			track(name, "pool")
		end
	end
	f.receipts, f.delivery, f.contact = modules.CastReceiptClient, modules.CastDeliveryClient, modules.CastContactClient
	function f:coordinator()
		if not modules.CastPresentationClient then
			modules.CastPresentationClient = luau.load(
				fs.readFile("src/client/CastPresentationClient.luau"),
				{ injectGlobals = true, environment = env }
			)()
		end
		return modules.CastPresentationClient
	end
	function f:closed()
		assert(next(self.subscriptions) == nil, "subscription leak")
		assert(self.receipts.inbox() == nil and self.receipts.contacts() == nil, "receipt still published")
		assert(self.delivery.state() == nil and self.contact.state() == nil, "consumer still published")
		for _, record in self.states do
			local state = record.state
			assert(
				if record.label == "receipt" then state.acceptances.closed else state.closed,
				"unclosed " .. record.label
			)
		end
	end
	return f
end
local count = 0
local function test(name, body)
	body()
	count += 1
	print("PASS owner-engine " .. name)
end
-- Receipt constructors are pure; a second-constructor failure must not publish state.
test("receipt acquisition faults unwind all returned resources and retry cleanly", function()
	for failure = 1, 7 do
		local f = fixture()
		f.fail = failure
		local ok, problem = pcall(f.receipts.start)
		assert(not ok and tostring(problem):find("injected acquisition", 1, true))
		f:closed()
		f.fail = 0
		local stop = f.receipts.start()
		assert(f.receipts.start() == stop)
		stop()
		stop()
		f:closed()
	end
end)
test("delivery constructor and heartbeat faults unwind without destroying borrowed receipts", function()
	for failure = 1, 4 do
		local f = fixture()
		local stopReceipts = f.receipts.start()
		local inbox = f.receipts.inbox()
		f.fail = f.stage + failure
		assert(not pcall(f.delivery.start, {}))
		assert(f.delivery.state() == nil and f.receipts.inbox() == inbox and not inbox.acceptances.closed)
		for _, record in f.states do
			if record.label == "pool" or record.label == "delivery" then
				assert(record.state.closed)
			end
		end
		f.fail = 0
		local stop = f.delivery.start({})
		assert(f.delivery.start({}) == stop)
		stop()
		stopReceipts()
		f:closed()
	end
end)
test("contact constructor and heartbeat faults preserve borrowed contacts and permit retry", function()
	for failure = 1, 2 do
		local f = fixture()
		local stopReceipts = f.receipts.start()
		local contacts = f.receipts.contacts()
		f.fail = f.stage + failure
		assert(not pcall(f.contact.start, {}))
		assert(f.contact.state() == nil and not contacts.closed)
		f.fail = 0
		local stop = f.contact.start({})
		stop()
		stopReceipts()
		f:closed()
	end
end)
test("cleanup faults do not skip remaining independent releases or mask startup failure", function()
	local f = fixture()
	f.cleanFail = { CastTerminal = true, heartbeat1 = true, receipt = true, contacts = true }
	f.fail = 6 -- final listener, after three returned subscriptions
	local ok, problem = pcall(f.receipts.start)
	assert(not ok and tostring(problem):find("injected acquisition CastDisposition", 1, true))
	assert(#f.errors == 3)
	f:closed()
	f.fail = 0
	f.cleanFail = {}
	local stop = f.receipts.start()
	f.failClock = true
	stop()
	f:closed()
end)
test("consumer cleanup faults still release pools, clear singleton and stop receipts", function()
	local f = fixture()
	local receipts = f.receipts.start()
	local delivery = f.delivery.start({})
	local contact = f.contact.start({})
	f.cleanFail = { heartbeat2 = true, heartbeat3 = true, delivery = true, pool = true, contact = true }
	contact()
	delivery()
	receipts()
	assert(#f.errors == 6)
	f:closed()
end)
test("stale cleanup and queued callbacks cannot kill or mutate a replacement", function()
	local f = fixture()
	local r, d, c = f.receipts.start(), nil, nil
	d, c = f.delivery.start({}), f.contact.start({})
	c()
	d()
	r()
	local old = table.clone(f.callbacks)
	local r2 = f.receipts.start()
	local d2, c2 = f.delivery.start({}), f.contact.start({})
	local inbox, delivery, contact = f.receipts.inbox(), f.delivery.state(), f.contact.state()
	for _, callback in old do
		callback.fn(nil)
	end -- nil would fail if stale listeners still execute
	c()
	d()
	r()
	assert(f.receipts.inbox() == inbox and f.delivery.state() == delivery and f.contact.state() == contact)
	assert(not inbox.acceptances.closed and not delivery.closed and not contact.closed)
	c2()
	d2()
	r2()
	f:closed()
end)
print("OWNER ENGINE: PASS (" .. count .. " cases)")
