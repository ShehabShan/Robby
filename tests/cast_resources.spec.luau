local R = require("../src/shared/CastResources")
local P = require("../src/shared/CastPresentation")
return {
	["real presentation actions keep adoption lease then clear at authoritative expiry"] = function()
		local p = P.new({ capacity = 4, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 })
		local s = R.new(4, 4)
		local key = "g:1"
		local poses, worlds = 0, 0
		assert(P.predict(p, key, 100).action == "predict")
		local lease = assert(R.open(s, key))
		local pose = assert(R.bind(s, lease, "animation", "pose", function()
			poses += 1
		end))
		local timeline = { acceptedAt = 100, releaseAt = 100.2, endsAt = 102, x = 1, y = 2, z = 3 }
		assert(#P.tick(p, 100.1) == 0 and P.accept(p, key, timeline, 100.1).action == "adopt")
		local world = assert(R.bind(s, lease, "tell", "world", function()
			worlds += 1
		end))
		assert(P.accept(p, key, timeline, 100.2).action == "ignore" and R.isCurrent(s, pose))
		R.retirePose(s, lease) -- local death while an accepted world effect remains active
		assert(poses == 1 and worlds == 0 and R.isCurrent(s, world))
		for _, clear in assert(P.tick(p, 102)) do
			assert(clear.key == key and clear.action == "clear")
			R.clear(s, lease)
		end
		assert(worlds == 1 and s.count == 0 and s.cleanupFailures == 0)
		assert(P.cancel(p, key, 102).action == "ignore" and not R.clear(s, lease))
	end,
	["prediction timeout and late acceptance create a fresh lease immune to old callbacks"] = function()
		local p = P.new({ capacity = 4, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 })
		local s = R.new(4, 4)
		local key = "g:1"
		local cleaned = 0
		assert(P.predict(p, key, 100).action == "predict")
		local old = assert(R.open(s, key))
		local oldTicket = assert(R.bind(s, old, "timer", "world", function()
			cleaned += 1
		end))
		for _ in assert(P.tick(p, 101)) do
			R.clear(s, old)
		end
		assert(cleaned == 1 and not R.isCurrent(s, oldTicket))
		local timeline = { acceptedAt = 100, releaseAt = 100.2, endsAt = 103, x = 1, y = 2, z = 3 }
		assert(P.accept(p, key, timeline, 101.5).action == "start")
		local fresh = assert(R.open(s, key))
		local ticket = assert(R.bind(s, fresh, "timer", "world", function()
			cleaned += 1
		end))
		assert(not R.release(s, oldTicket) and not R.clear(s, old) and R.isCurrent(s, ticket))
		for _ in P.destroy(p) do
			R.clear(s, fresh)
		end
		R.destroy(s)
		assert(cleaned == 2 and s.cleanupFailures == 0 and s.count == 0)
	end,
	["retiring a pose may reenter full clear without double disposing any scope"] = function()
		local s = R.new(1, 3)
		local lease = assert(R.open(s, "g:1"))
		local pose, world = 0, 0
		for i = 1, 2 do
			assert(R.bind(s, lease, "pose" .. i, "pose", function()
				pose += 1
				R.clear(s, lease)
			end))
		end
		assert(R.bind(s, lease, "world", "world", function()
			world += 1
		end))
		assert(R.retirePose(s, lease))
		assert(pose == 2 and world == 1 and s.count == 0 and s.cleanupFailures == 0)
	end,

	["owner and resource caps refuse without evicting active world hazards"] = function()
		local s = R.new(1, 2)
		local lease = assert(R.open(s, "g:1"))
		local dropped = 0
		assert(not R.open(s, "g:1") and not R.open(s, "g:2"))
		local a = assert(R.bind(s, lease, "tell", "world", function() end))
		local b = assert(R.bind(s, lease, "pose", "pose", function() end))
		assert(not R.bind(s, lease, "extra", "world", function()
			dropped += 1
		end))
		assert(dropped == 1 and R.isCurrent(s, a) and R.isCurrent(s, b) and s.owners[lease.key].count == 2)
	end,
	["each ticket disposes once and delayed callbacks cannot affect replacement"] = function()
		local s = R.new(2, 2)
		local lease = assert(R.open(s, "g:1"))
		local calls = 0
		local a = assert(R.bind(s, lease, "timer", "world", function()
			calls += 1
		end))
		assert(R.release(s, a) and not R.release(s, a) and calls == 1)
		local b = assert(R.bind(s, lease, "timer", "world", function()
			calls += 1
		end))
		assert(not R.isCurrent(s, a) and R.isCurrent(s, b) and not R.release(s, a))
		assert(R.clear(s, lease) and calls == 2 and not R.clear(s, lease))
		assert(not R.release(s, b) and s.count == 0)
	end,
	["pose retirement cannot cancel world tells and refuses late pose attachment"] = function()
		local s = R.new(2, 3)
		local lease = assert(R.open(s, "g:1"))
		local pose, world = 0, 0
		local a = assert(R.bind(s, lease, "pose", "pose", function()
			pose += 1
		end))
		local b = assert(R.bind(s, lease, "zone", "world", function()
			world += 1
		end))
		assert(R.retirePose(s, lease) and not R.retirePose(s, lease))
		assert(pose == 1 and world == 0 and not R.isCurrent(s, a) and R.isCurrent(s, b))
		assert(not R.bind(s, lease, "late-pose", "pose", function()
			pose += 1
		end))
		assert(pose == 2 and R.isActive(s, lease))
		R.clear(s, lease)
		assert(world == 1)
	end,
	["reentrant clear and throwing disposer never skip sibling cleanup"] = function()
		local s = R.new(2, 3)
		local lease = assert(R.open(s, "g:1"))
		local calls = 0
		for i = 1, 3 do
			assert(R.bind(s, lease, tostring(i), "world", function()
				calls += 1
				assert(not R.isActive(s, lease) and not R.clear(s, lease))
				if i == 2 then
					error("synthetic cleanup error")
				end
			end))
		end
		assert(R.clear(s, lease) and calls == 3 and s.cleanupFailures == 1 and s.count == 0)
	end,
	["reentrant replacement lease survives stale terminal cleanup"] = function()
		local s = R.new(1, 2)
		local old = assert(R.open(s, "g:1"))
		local replacement
		assert(R.bind(s, old, "timer", "world", function()
			replacement = assert(R.open(s, "g:1"))
		end))
		assert(R.clear(s, old))
		assert(replacement and replacement ~= old and R.isActive(s, replacement))
		assert(not R.clear(s, old) and not R.isActive(s, old))
		local refused = 0
		assert(not R.bind(s, old, "late", "world", function()
			refused += 1
		end))
		assert(refused == 1 and s.count == 1 and table.isfrozen(replacement) and s.cleanupFailures == 0)
	end,
	["reentrant resource replacement cannot be overwritten by a caller"] = function()
		local s = R.new(1, 1)
		local lease = assert(R.open(s, "g:1"))
		local replacement
		local drops = 0
		local first = assert(R.bind(s, lease, "timer", "world", function()
			replacement = assert(R.bind(s, lease, "timer", "world", function()
				drops += 1
			end))
		end))
		R.release(s, first)
		assert(replacement and R.isCurrent(s, replacement))
		assert(not R.bind(s, lease, "timer", "world", function()
			drops += 1
		end))
		assert(drops == 1 and not R.release(s, first))
		R.destroy(s)
		assert(drops == 2 and s.cleanupFailures == 0)
	end,
	["pose batch detaches all tickets before first disposer can reenter"] = function()
		local s = R.new(1, 3)
		local lease = assert(R.open(s, "g:1"))
		local tickets = {}
		local calls = 0
		for i = 1, 2 do
			table.insert(
				tickets,
				assert(R.bind(s, lease, tostring(i), "pose", function()
					calls += 1
					for _, ticket in tickets do
						assert(not R.isCurrent(s, ticket) and not R.release(s, ticket))
					end
				end))
			)
		end
		R.retirePose(s, lease)
		assert(calls == 2 and s.owners[lease.key].count == 0 and s.cleanupFailures == 0)
	end,
	["destroy disables reentrant admission and releases all owners despite failures"] = function()
		local s = R.new(3, 2)
		local calls = 0
		for i = 1, 3 do
			local lease = assert(R.open(s, "g:" .. i))
			assert(R.bind(s, lease, "timer", "world", function()
				calls += 1
				assert(s.closed and s.count == 0 and not R.open(s, "new"))
				R.destroy(s)
				error("synthetic disposal failure")
			end))
		end
		R.destroy(s)
		R.destroy(s)
		assert(calls == 3 and s.cleanupFailures == 3 and next(s.owners) == nil)
	end,
	["forged leases and tickets cannot invalidate real resources"] = function()
		local s = R.new(1, 1)
		local lease = assert(R.open(s, "g:1"))
		local calls = 0
		local ticket = assert(R.bind(s, lease, "x", "world", function()
			calls += 1
		end))
		assert(not R.isActive(s, table.clone(lease)) and not R.clear(s, table.clone(lease)))
		assert(not R.isCurrent(s, table.clone(ticket)) and not R.release(s, table.clone(ticket)))
		assert(calls == 0 and R.isCurrent(s, ticket))
	end,
	["invalid policy or names and closed state leave no unowned cleanup"] = function()
		for _, n in { 0, -1, 1.5, 0 / 0, math.huge } do
			assert(not pcall(R.new, n, 1) and not pcall(R.new, 1, n))
		end
		local s = R.new(1, 1)
		assert(not R.open(s, "") and not R.open(s, string.rep("x", 257)))
		local lease = assert(R.open(s, "g:1"))
		local calls = 0
		assert(not R.bind(s, lease, "", "world", function()
			calls += 1
		end))
		R.destroy(s)
		assert(not R.bind(s, lease, "x", "world", function()
			calls += 1
		end) and calls == 2)
	end,
}
