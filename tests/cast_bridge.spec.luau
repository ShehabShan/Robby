local B = require("../src/shared/CastBridge")
local R = require("../src/shared/CastResources")
local function timeline(start, finish)
	return { acceptedAt = start or 100, releaseAt = (start or 100) + 1, endsAt = finish or 104, x = 7, y = 8, z = 9 }
end
local function setup(capacity, renderer, perCast)
	return B.new(
		{ capacity = capacity or 4, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 },
		perCast or 4,
		renderer or function()
			return true
		end
	)
end
local function fake()
	local f = { frames = {}, tickets = {}, poseCleaned = 0, worldCleaned = 0 }
	f.render = function(frame)
		table.insert(f.frames, frame)
		local tickets = f.tickets[frame.lease]
		if not tickets then
			tickets = {}
			f.tickets[frame.lease] = tickets
			if frame.poseAllowed then
				tickets.pose = assert(frame.bind("pose", "pose", function()
					f.poseCleaned += 1
				end))
			end
		end
		if frame.timeline and not tickets.world then
			tickets.world = assert(frame.bind("warning", "world", function()
				f.worldCleaned += 1
			end))
		end
		return true
	end
	return f
end
return {
	["owner prediction adopts the identical lease without restarting resources"] = function()
		local f = fake()
		local s = setup(4, f.render)
		assert(B.predict(s, "g:1", 100) == "predict")
		local before = f.frames[1]
		assert(B.accept(s, "g:1", timeline(), 100.2) == "adopt")
		local after = f.frames[2]
		assert(before.lease == after.lease and before.isCurrent(f.tickets[before.lease].pose))
		assert(after.phase == "warning" and math.abs(after.progress - 0.2) < 0.0001)
		assert(after.timeline.x == 7 and after.timeline.y == 8 and after.timeline.z == 9)
		assert(f.poseCleaned == 0 and f.worldCleaned == 0 and s.resources.count == 1)
		assert(B.accept(s, "g:1", timeline(), 100.3) == "ignore" and #f.frames == 2)
		B.destroy(s)
		assert(f.poseCleaned == 1 and f.worldCleaned == 1)
	end,
	["observer seeks the authoritative phase and never invents an impact"] = function()
		local f = fake()
		local s = setup(4, f.render)
		assert(B.accept(s, "g:1", timeline(), 102) == "start")
		assert(f.frames[1].phase == "active" and math.abs(f.frames[1].progress - 1 / 3) < 0.0001)
		assert(B.tick(s, 103) and f.frames[2].action == "seek")
		assert(math.abs(f.frames[2].progress - 2 / 3) < 0.0001)
		assert(B.tick(s, 104) and #f.frames == 2 and s.resources.count == 0)
		assert(f.poseCleaned == 1 and f.worldCleaned == 1)
	end,
	["owner and observer converge on immutable server centre and common clock"] = function()
		local a, b = fake(), fake()
		local owner, observer = setup(4, a.render), setup(4, b.render)
		B.predict(owner, "g:1", 100)
		local t = timeline()
		B.accept(owner, "g:1", t, 100.4)
		B.accept(observer, "g:1", t, 100.4)
		t.x = -900
		B.tick(owner, 102)
		B.tick(observer, 102)
		local af, bf = a.frames[#a.frames], b.frames[#b.frames]
		assert(
			af.phase == bf.phase
				and af.progress == bf.progress
				and af.timeline.x == bf.timeline.x
				and af.timeline.x == 7
		)
		assert(not pcall(function()
			af.timeline.x = 1
		end) and not pcall(function()
			af.key = "wrong"
		end))
		B.destroy(owner)
		B.destroy(observer)
	end,
	["idle tick expires prediction and late acceptance has a fresh lease"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.predict(s, "g:1", 100)
		local old = f.frames[1]
		local ticket = f.tickets[old.lease].pose
		assert(B.tick(s, 101) and f.poseCleaned == 1)
		assert(B.accept(s, "g:1", timeline(), 102) == "start")
		local fresh = f.frames[2]
		assert(old.lease ~= fresh.lease and not old.isCurrent(ticket) and not old.release(ticket))
		local staleDisposed = 0
		assert(old.bind("stale", "world", function()
			staleDisposed += 1
		end) == nil)
		assert(staleDisposed == 1 and s.resourceRefusals == 1)
		assert(fresh.isCurrent(f.tickets[fresh.lease].pose))
		B.destroy(s)
	end,
	["event reduction consumes timeout cleanup before allocating a new cast"] = function()
		local f = fake()
		local s = setup(1, f.render)
		B.predict(s, "g:1", 100)
		assert(B.predict(s, "g:2", 101) == "predict")
		assert(f.poseCleaned == 1 and s.resources.count == 1 and s.leases["g:1"] == nil)
		B.destroy(s)
	end,
	["cancel before accept and repeated rejection never render"] = function()
		local f = fake()
		local s = setup(4, f.render)
		assert(B.cancel(s, "g:1", 100) == "ignore")
		assert(B.accept(s, "g:1", timeline(), 100.5) == "ignore")
		assert(B.cancel(s, "g:1", 101) == "ignore" and #f.frames == 0)
		B.destroy(s)
	end,
	["rejection clears prediction once and terminal clears accepted worlds"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.predict(s, "g:1", 100)
		assert(B.cancel(s, "g:1", 100.2) == "clear")
		assert(B.cancel(s, "g:1", 100.3) == "ignore" and f.poseCleaned == 1)
		B.accept(s, "g:2", timeline(), 100.4)
		assert(B.cancel(s, "g:2", 101) == "clear" and f.worldCleaned == 1 and f.poseCleaned == 2)
		assert(B.accept(s, "g:2", timeline(), 101.1) == "ignore")
		B.destroy(s)
	end,
	["late expired acceptance does not flash any resource"] = function()
		local f = fake()
		local s = setup(4, f.render)
		assert(B.accept(s, "g:1", timeline(), 105) == "ignore")
		assert(#f.frames == 0 and s.resources.count == 0)
		B.destroy(s)
	end,
	["local pose loss preserves accepted world until expiry and forbids later poses"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.accept(s, "g:1", timeline(), 100)
		local frame = f.frames[1]
		assert(B.retirePose(s, "g:1", 100.5) and not B.retirePose(s, "g:1", 100.6))
		assert(f.poseCleaned == 1 and f.worldCleaned == 0 and frame.isCurrent(f.tickets[frame.lease].world))
		assert(B.tick(s, 102) and not f.frames[2].poseAllowed)
		local disposed = 0
		assert(frame.bind("new-pose", "pose", function()
			disposed += 1
		end) == nil and disposed == 1)
		assert(B.tick(s, 104) and f.worldCleaned == 1)
		B.destroy(s)
	end,
	["capacity refuses newcomers without evicting a live warning"] = function()
		local f = fake()
		local s = setup(1, f.render)
		B.accept(s, "g:1", timeline(), 100)
		local lease = s.leases["g:1"]
		assert(B.accept(s, "g:2", timeline(), 100.1) == "refuse")
		assert(s.refusals == 1 and s.leases["g:1"] == lease and f.worldCleaned == 0 and #f.frames == 1)
		B.destroy(s)
	end,
	["cancel overflow suppresses delayed old acceptance after slots free"] = function()
		local f = fake()
		local s = setup(1, f.render)
		B.predict(s, "g:1", 100)
		assert(B.cancel(s, "g:2", 100.1) == "refuse")
		assert(B.accept(s, "g:2", timeline(), 101.5) == "ignore")
		assert(#f.frames == 1 and s.resources.count == 0)
		B.destroy(s)
	end,
	["backward nonfinite and future clocks refuse without corrupting a live cast"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.accept(s, "g:1", timeline(), 100)
		assert(not B.tick(s, 99) and not B.tick(s, math.huge) and not B.tick(s, 0 / 0))
		assert(B.accept(s, "future", timeline(110, 114), 100) == "refuse")
		assert(B.accept(s, "invalid", timeline(100, 150), 100) == "refuse")
		assert(#f.frames == 1 and f.worldCleaned == 0)
		assert(B.tick(s, 101) and #f.frames == 2)
		B.destroy(s)
	end,
	["renderer throw disposes partially allocated resources then suppresses retry"] = function()
		local cleaned = 0
		local s = setup(4, function(frame)
			assert(frame.bind("first", "world", function()
				cleaned += 1
			end))
			error("renderer failed after allocation")
		end)
		assert(B.accept(s, "g:1", timeline(), 100) == "failed")
		assert(cleaned == 1 and s.renderFailures == 1 and s.resources.count == 0 and next(s.leases) == nil)
		assert(B.accept(s, "g:1", timeline(), 100.1) == "ignore" and B.tick(s, 102))
		B.destroy(s)
		assert(cleaned == 1)
	end,
	["renderer false and resource refusal are explicit and fully cleaned"] = function()
		local cleaned = 0
		local s = setup(4, function(frame)
			assert(frame.bind("first", "world", function()
				cleaned += 1
			end))
			assert(frame.bind("second", "world", function()
				cleaned += 1
			end) == nil)
			return false
		end, 1)
		assert(B.accept(s, "g:1", timeline(), 100) == "failed")
		assert(cleaned == 2 and s.resourceRefusals == 1 and s.renderFailures == 1 and s.resources.count == 0)
		B.destroy(s)
	end,
	["throwing cleanup cannot block sibling casts or bridge teardown"] = function()
		local cleaned = 0
		local s = setup(4, function(frame)
			assert(frame.bind("bad", "world", function()
				error("broken engine disposer")
			end))
			assert(frame.bind("good", "world", function()
				cleaned += 1
			end))
			return true
		end)
		B.accept(s, "g:1", timeline(), 100)
		B.accept(s, "g:2", timeline(), 100)
		assert(B.destroy(s) and B.destroy(s))
		assert(cleaned == 2 and s.resources.cleanupFailures == 2 and s.resources.count == 0)
		assert(next(s.presentation.entries) == nil and next(s.leases) == nil)
	end,
	["failing seek retires only the failed cast and still seeks healthy sibling"] = function()
		local frames, cleaned = {}, 0
		local s = setup(4, function(frame)
			if frame.action == "start" then
				frame.bind("world", "world", function()
					cleaned += 1
				end)
			elseif frame.key == "g:1" then
				error("seek failure")
			else
				table.insert(frames, frame)
			end
			return true
		end)
		B.accept(s, "g:1", timeline(), 100)
		B.accept(s, "g:2", timeline(), 100)
		assert(not B.tick(s, 102) and cleaned == 1 and #frames == 1 and frames[1].key == "g:2")
		assert(s.resources.count == 1 and s.renderFailures == 1)
		B.destroy(s)
		assert(cleaned == 2)
	end,
	["renderer and disposer reentry refuse before any reducer mutation"] = function()
		local s, nested, destroyResult
		s = setup(4, function(frame)
			nested = B.accept(s, "nested", timeline(), 100)
			assert(frame.bind("world", "world", function()
				assert(B.predict(s, "nested2", 100) == "refuse")
				destroyResult = B.destroy(s)
			end))
			return true
		end)
		assert(B.accept(s, "g:1", timeline(), 100) == "start" and nested == "refuse")
		assert(B.cancel(s, "g:1", 100.5) == "clear" and destroyResult == false)
		assert(s.presentation.entries.nested == nil and s.presentation.entries.nested2 == nil)
		assert(B.destroy(s))
	end,
	["closed bridge refuses events and disposes delayed allocation"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.accept(s, "g:1", timeline(), 100)
		local frame = f.frames[1]
		B.destroy(s)
		assert(B.predict(s, "g:2", 101) == "refuse" and B.accept(s, "g:2", timeline(), 101) == "refuse")
		assert(B.cancel(s, "g:2", 101) == "refuse" and not B.retirePose(s, "g:1", 101) and not B.tick(s, 101))
		local cleaned = 0
		assert(frame.bind("late", "world", function()
			cleaned += 1
		end) == nil and cleaned == 1)
		assert(#f.frames == 1 and B.destroy(s))
	end,
	["frame release cannot touch another cast and stale ticket cannot release replacement"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.accept(s, "g:1", timeline(), 100)
		B.accept(s, "g:2", timeline(), 100)
		local a, b = f.frames[1], f.frames[2]
		local ticket = f.tickets[a.lease].world
		assert(not b.release(ticket) and not b.isCurrent(ticket))
		assert(a.release(ticket) and not a.release(ticket))
		local replacement = assert(a.bind("warning", "world", function() end))
		assert(not a.isCurrent(ticket) and not a.release(ticket) and a.isCurrent(replacement))
		B.destroy(s)
	end,
	["long event stream remains bounded and old leases are never retained by bridge"] = function()
		local s = setup(2)
		for i = 1, 1000 do
			local now = i * 20
			assert(B.accept(s, "g:" .. i, timeline(now, now + 4), now) == "start")
			assert(B.tick(s, now + 4) and s.resources.count == 0 and next(s.leases) == nil)
			local count = 0
			for _ in s.presentation.entries do
				count += 1
			end
			assert(count <= 2)
		end
		B.destroy(s)
	end,
	["actual resource registry invariants are retained through the executor"] = function()
		local f = fake()
		local s = setup(4, f.render)
		B.predict(s, "g:1", 100)
		local frame = f.frames[1]
		assert(R.isActive(s.resources, frame.lease))
		assert(not R.isActive(s.resources, table.clone(frame.lease)))
		assert(not frame.isCurrent(table.clone(f.tickets[frame.lease].pose)))
		B.destroy(s)
	end,
}
