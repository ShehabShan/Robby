-- Actual test adapter + pure policy; injected scheduler/transport, NOT engine evidence.
local S = require("../src/shared/OwnerTestSession")
local Adapter = require("./published/OwnerTestAdapter")
local serde = require("@lune/serde")
local function fixture(mode)
	local f = { now = 0, valid = true, sent = {}, queue = {}, connections = {}, stops = 0, runs = 0, stage = 0 }
	f.owner = {}
	local function connect(name, callback)
		f.stage += 1
		if mode == "acquire" and f.stage == 3 then
			error("acquisition fault")
		end
		f[name] = callback
		local c = { Connected = true }
		function c:Disconnect()
			self.Connected = false
			if mode == "disconnect" and name == "heartbeat" then
				error("disconnect fault")
			end
		end
		table.insert(f.connections, c)
		return c
	end
	local deps = {
		owner = f.owner,
		clock = function()
			return f.now
		end,
		valid = function()
			if mode == "guard-throws" then
				error("guard")
			end
			return f.valid
		end,
		onRequest = function(fn)
			return connect("request", fn)
		end,
		onHeartbeat = function(fn)
			return connect("heartbeat", fn)
		end,
		onInvalidated = function(fn)
			return connect("invalidate", fn)
		end,
		send = function(owner, response)
			assert(owner == f.owner)
			if mode == "send" then
				error("send fault")
			end
			table.insert(f.sent, response)
		end,
		spawn = function(fn)
			if mode == "spawn" then
				error("spawn fault")
			end
			table.insert(f.queue, fn)
		end,
		cancelWorker = function()
			f.stops += 1
			if mode == "cancel-throws" then
				error("stop fault")
			end
		end,
		encode = function(report)
			if mode == "encode" then
				error("encode fault")
			end
			if mode == "oversize" then
				return string.rep("x", S.maxBytes + 1)
			end
			return serde.encode("json", report)
		end,
		run = function(check, progress)
			f.runs += 1
			check()
			progress(1)
			if mode == "throw" then
				error("worker fault")
			end
			if mode == "leave" or mode == "cancel-throws" then
				f.invalidate()
			end
			if mode == "extra" then
				f.valid = false
				f.heartbeat()
			end
			if mode == "timeout" then
				f.now = 601
				f.heartbeat()
			end
			local ok = pcall(check)
			f.cleaned = true
			-- Deliberately overoptimistic payload to verify adapter downgrades it.
			return { matrixPassed = true, dynamicsAccepted = true, results = {} }, ok, mode ~= "cleanup"
		end,
	}
	local ok, handle = pcall(Adapter.start, S, deps)
	f.handle, f.started = handle, ok
	function f.ask(action, page)
		f.now += 0.21
		f.request(f.owner, action, page)
		return f.sent[#f.sent]
	end
	function f.drain()
		for _, fn in f.queue do
			fn()
		end
		table.clear(f.queue)
	end
	function f.status()
		return f.ask("status")
	end
	function f.report()
		local page = f.ask("report", 1)
		return serde.decode("json", page.data)
	end
	return f
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
test("explicit owner only bounded requests, status and complete report", function()
	local f = fixture()
	assert(f.started and f.runs == 0)
	f.request({}, "start")
	f.request(f.owner, "start", nil, "extra")
	assert(#f.queue == 0 and #f.sent == 0)
	assert(f.ask("start").phase == "running")
	f.request(f.owner, "start")
	assert(#f.queue == 1)
	f.drain()
	assert(f.runs == 1 and f.cleaned and f.status().phase == "complete")
	local report = f.report()
	assert(report.matrixPassed and report.cleanup and report.runCompleted and not report.dynamicsAccepted)
	f.ask("start")
	assert(#f.queue == 0)
	f.handle.stop()
	f.handle.stop()
	for _, c in f.connections do
		assert(not c.Connected)
	end
end)
test("leave extra join timeout cancel exactly once; overoptimistic payload downgraded", function()
	for _, mode in { "leave", "extra", "timeout", "cancel-throws" } do
		local f = fixture(mode)
		f.ask("start")
		f.drain()
		assert(f.runs == 1 and f.stops == 1 and f.cleaned)
		assert(f.status().phase == "failed")
		local report = f.report()
		assert(not report.matrixPassed and not report.runCompleted and not report.dynamicsAccepted)
		if mode == "cancel-throws" then
			assert(not report.cleanup)
		end
		f.invalidate()
		f.handle.stop()
		assert(f.stops == 1)
	end
end)
test("failed worker cleanup scheduler encoder and oversized output never succeed", function()
	for _, mode in { "throw", "cleanup", "spawn", "encode", "oversize" } do
		local f = fixture(mode)
		f.ask("start")
		f.drain()
		assert(f.status().phase == "failed")
		if mode ~= "oversize" then
			assert(not f.report().dynamicsAccepted)
		end
		f.handle.stop()
	end
end)
test("cancellation before deferred start and old/replacement identity cannot restart", function()
	for _, reason in { "leave", "stop" } do
		local f = fixture()
		f.ask("start")
		if reason == "leave" then
			f.invalidate()
		else
			f.handle.stop()
		end
		f.drain()
		assert(f.runs == 0 and f.stops == 1)
		f.request({}, "start")
		f.ask("start")
		assert(#f.queue == 0)
		f.handle.stop()
	end
end)
test("partial acquisition rollback, independent disconnects, guard/send errors", function()
	local f = fixture("acquire")
	assert(not f.started)
	for _, c in f.connections do
		assert(not c.Connected)
	end
	f = fixture("disconnect")
	f.handle.stop()
	for _, c in f.connections do
		assert(not c.Connected)
	end
	f = fixture("guard-throws")
	f.ask("start")
	assert(#f.queue == 0 and f.status().phase == "closed")
	f.handle.stop()
	f = fixture("send")
	f.ask("start")
	f.drain()
	assert(f.cleaned and f.runs == 1)
	f.handle.stop()
end)
test("100 complete stop cycles release subscriptions without invoking cancellation", function()
	for _ = 1, 100 do
		local f = fixture()
		f.ask("start")
		f.drain()
		f.handle.stop()
		for _, c in f.connections do
			assert(not c.Connected)
		end
		assert(f.stops == 0)
	end
end)
print("Owner test adapter: " .. count .. " groups PASS (offline only)")
