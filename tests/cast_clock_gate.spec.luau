local G = require("../src/shared/CastClockGate")
local B = require("../src/shared/CastBridge")
local function timeline(at)
	return { acceptedAt = at, releaseAt = at + 0.5, endsAt = at + 2, x = 1, y = 2, z = 3 }
end
local function setup(options)
	local o = options or {}
	local f = { frames = {}, cleaned = 0 }
	local b = B.new(
		{ capacity = 8, predictionSeconds = 1, tombstoneSeconds = 20, maxLifetimeSeconds = 10 },
		2,
		function(frame)
			table.insert(f.frames, frame)
			if frame.action == "start" or frame.action == "predict" then
				frame.bind("world", "world", function()
					f.cleaned += 1
				end)
			end
			return true
		end
	)
	local g = G.new(b, {
		pendingCapacity = o.capacity or 2,
		futureSeconds = o.future or 0.5,
		maxWaitSeconds = o.wait or 2,
		maxSampleError = 1,
		correctionPerSecond = 0.25,
	})
	return g, f
end
return {
	["overflow cancellation watermark suppresses queued and replayed future receipts"] = function()
		local g, f = setup()
		G.accept(g, "future1", timeline(100.2), 0, 100)
		G.accept(g, "future2", timeline(100.1), 0, 100)
		for i = 1, 8 do
			assert(G.predict(g, "full" .. i, 0, 100) == "predict")
		end
		assert(G.cancel(g, "future1", 0, 100) == "refuse")
		assert(g.retiredThrough == 100.2)
		G.tick(g, 1.1, 101.1)
		assert(g.count == 0 and #f.frames == 8)
		assert(G.accept(g, "future1", timeline(100.2), 1.1, 101.1) == "ignore")
		G.destroy(g)
	end,
	["future wait expiry under full bridge leaves a bounded anti-replay watermark"] = function()
		local g = setup({ wait = 0.1 })
		G.accept(g, "future", timeline(100.2), 0, 100)
		for i = 1, 8 do
			G.predict(g, "full" .. i, 0, 100)
		end
		G.tick(g, 0.1, 100.1)
		assert(g.expired == 1 and g.count == 0 and g.retiredThrough == 100.2)
		G.tick(g, 1.1, 101.1)
		assert(G.accept(g, "future", timeline(100.2), 1.1, 101.1) == "ignore")
		G.destroy(g)
	end,
	["invalid policies and already used bridge are rejected"] = function()
		local g = setup()
		local p = table.clone(g.policy)
		p.correctionPerSecond = 1
		assert(not pcall(G.new, g.bridge, p))
		p = table.clone(g.policy)
		p.futureSeconds = 11
		assert(not pcall(G.new, g.bridge, p))
		G.tick(g, 0, 100)
		assert(not pcall(G.new, g.bridge, g.policy))
		G.destroy(g)
	end,
	["queued future acceptance adopts prediction once and retains server timeline"] = function()
		local g, f = setup()
		assert(G.predict(g, "g:1", 0, 100) == "predict")
		local lease = f.frames[1].lease
		local t = timeline(100.2)
		assert(G.accept(g, "g:1", t, 0, 100) == "queued" and g.count == 1)
		t.x = 999
		assert(G.tick(g, 0.2, 100.2) and g.count == 0)
		local last = f.frames[#f.frames]
		assert(last.action == "adopt" and last.lease == lease and last.timeline.x == 1)
		assert(G.accept(g, "g:1", timeline(100.2), 0.2, 100.2) == "ignore")
		G.destroy(g)
		assert(f.cleaned == 1)
	end,
	["duplicate future packet does not extend wait or replace first payload"] = function()
		local g, f = setup({ future = 3, wait = 0.5 })
		assert(G.accept(g, "g:1", timeline(102), 0, 100) == "queued")
		local deadline = g.pending["g:1"].deadline
		assert(G.accept(g, "g:1", timeline(102.5), 0.4, 100.4) == "ignore")
		assert(g.pending["g:1"].deadline == deadline and g.pending["g:1"].timeline.acceptedAt == 102)
		G.tick(g, 0.5, 100.5)
		assert(g.count == 0 and g.expired == 1 and #f.frames == 0)
		assert(G.accept(g, "g:1", timeline(102), 2, 102) == "ignore")
		G.destroy(g)
	end,
	["cancel beats queued acceptance at release and cannot flash a warning"] = function()
		local g, f = setup()
		G.accept(g, "g:1", timeline(100.2), 0, 100)
		assert(G.cancel(g, "g:1", 0.2, 100.2) == "ignore")
		assert(g.count == 0 and #f.frames == 0)
		assert(G.accept(g, "g:1", timeline(100.2), 0.3, 100.3) == "ignore")
		G.destroy(g)
	end,
	["cancel before future receipt never queues it"] = function()
		local g, f = setup()
		G.cancel(g, "g:1", 0, 100)
		assert(G.accept(g, "g:1", timeline(100.2), 0, 100) == "ignore" and g.count == 0)
		G.tick(g, 0.3, 100.3)
		assert(#f.frames == 0)
		G.destroy(g)
	end,
	["queue capacity and extreme future receipts refuse without eviction"] = function()
		local g = setup({ capacity = 1 })
		assert(G.accept(g, "g:1", timeline(100.2), 0, 100) == "queued")
		assert(G.accept(g, "g:2", timeline(100.2), 0, 100) == "refuse")
		assert(G.accept(g, "g:3", timeline(100.6), 0, 100) == "refuse")
		assert(g.count == 1 and g.pending["g:1"] and g.refusals == 2)
		G.destroy(g)
	end,
	["deadline wins over late clock catchup and idle cleanup never needs a packet"] = function()
		local g, f = setup()
		G.predict(g, "prediction", 0, 100)
		G.accept(g, "future", timeline(100.2), 0, 100)
		G.tick(g, 3, 103)
		assert(g.count == 0 and g.expired == 1 and f.cleaned == 1 and #f.frames == 1)
		assert(g.bridge.resources.count == 0)
		G.destroy(g)
	end,
	["server outliers and NaN samples cannot strand cleanup after clock anchor"] = function()
		local g, f = setup()
		G.accept(g, "g:1", timeline(100), 0, 100)
		G.tick(g, 1, -1000)
		assert(g.now == 101 and g.badSamples == 1)
		G.tick(g, 2, 0 / 0)
		assert(g.now == 102 and g.badSamples == 2 and f.cleaned == 1)
		G.tick(g, 3, math.huge)
		assert(g.now == 103)
		G.destroy(g)
	end,
	["bounded backward sample slew always progresses and cannot replay prior phase"] = function()
		local g, f = setup()
		G.accept(g, "g:1", timeline(100), 0, 100)
		G.tick(g, 1, 100.5)
		assert(g.now == 100.75)
		local now = g.now
		G.tick(g, 1, 101.5)
		assert(g.now == now) -- same local timestamp cannot apply more correction
		G.tick(g, 2, 101)
		assert(g.now == 101.5 and f.frames[#f.frames].phase == "active")
		G.tick(g, 3, 102)
		assert(g.now == 102.25 and f.cleaned == 1)
		G.destroy(g)
	end,
	["bad local clock refuses without consuming pending work and can recover"] = function()
		local g, f = setup()
		assert(not G.tick(g, 0, 0 / 0) and g.now == nil)
		G.accept(g, "g:1", timeline(100.2), 10, 100)
		assert(not G.tick(g, 9, 101) and not G.tick(g, math.huge, 101))
		assert(G.cancel(g, "g:1", 9, 101) == "refuse" and g.count == 1)
		assert(G.tick(g, 10.3, 100.3) and g.count == 0 and #f.frames == 1)
		G.destroy(g)
	end,
	["invalid queued timeline is refused before taking a slot"] = function()
		local g = setup()
		local t = timeline(100.2)
		t.z = 0 / 0
		assert(G.accept(g, "g:1", t, 0, 100) == "refuse")
		t = timeline(100.2)
		t.endsAt = 99
		assert(G.accept(g, "g:1", t, 0, 100) == "refuse")
		assert(G.accept(g, "", timeline(100.2), 0, 100) == "refuse" and g.count == 0)
		G.destroy(g)
	end,
	["destroy clears active and pending once and rejects all later work"] = function()
		local g, f = setup()
		G.accept(g, "g:1", timeline(100), 0, 100)
		G.accept(g, "g:2", timeline(100.2), 0, 100)
		assert(G.destroy(g) and G.destroy(g) and g.count == 0 and next(g.pending) == nil and f.cleaned == 1)
		assert(not G.tick(g, 1, 101) and G.accept(g, "g:3", timeline(101), 1, 101) == "refuse")
		assert(G.predict(g, "g:3", 1, 101) == "refuse" and G.cancel(g, "g:3", 1, 101) == "refuse")
		assert(not G.retirePose(g, "g:1", 1, 101))
	end,
	["reentrant gate commands are refused while draining and teardown can retry"] = function()
		local g
		local calls = 0
		local b = B.new(
			{ capacity = 2, predictionSeconds = 1, tombstoneSeconds = 20, maxLifetimeSeconds = 10 },
			1,
			function()
				calls += 1
				assert(not G.destroy(g) and not G.tick(g, 0.2, 100.2))
				assert(G.cancel(g, "g:1", 0.2, 100.2) == "refuse")
				return true
			end
		)
		g = G.new(b, {
			pendingCapacity = 1,
			futureSeconds = 0.5,
			maxWaitSeconds = 2,
			maxSampleError = 1,
			correctionPerSecond = 0.25,
		})
		G.accept(g, "g:1", timeline(100.2), 0, 100)
		G.tick(g, 0.2, 100.2)
		assert(calls == 1 and not g.closed and G.destroy(g))
	end,
}
