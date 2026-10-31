local L = require("../src/shared/CastLifetime")
local function acceptance(id)
	return {
		["terminal callback runs only after winning transition and registry release"] = function()
			local s, count = L.new(2), 0
			s.onTerminal = function(h, now)
				count += 1
				assert(not L.isActive(s, h) and s.count == 0 and h.terminal.at == 10001 and now == 11)
				assert(not L.finish(s, h, 1, now))
			end
			local h = L.start(s, acceptance(), 10, 1, 1)
			assert(L.finish(s, h, 1, 11))
			L.expire(s, 99)
			assert(not L.terminate(s, h, "expired", 99) and count == 1)
		end,
		castId = id or "g:1",
		generation = "g",
		seq = 1,
		moveId = "move.test",
		casterUserId = 1,
		characterKey = "c",
		slotRevision = 1,
		acceptedAt = 10000,
		releaseAt = 10000,
		endsAt = 10002,
		aim = { x = 0, y = 0, z = 1 },
		origin = { x = 0, y = 0, z = 0 },
	}
end
return {
	["copied immutable acceptance survives cache mutation"] = function()
		local s, a = L.new(2), acceptance()
		local h = L.start(s, a, 10, 1, 1)
		a.origin.x = 90
		assert(h.acceptance.origin.x == 0 and table.isfrozen(h.acceptance))
		assert(not pcall(function()
			h.acceptance.aim.x = 3
		end))
	end,
	["all shards complete once with original paired clock"] = function()
		local s = L.new(2)
		local h = L.start(s, acceptance(), 10, 3, 1)
		assert(not L.finish(s, h, 1, 10.1) and h.remaining == 2)
		assert(not L.finish(s, h, 1, 11) and h.remaining == 2)
		assert(not L.finish(s, h, 0, 11) and not L.finish(s, h, 4, 11))
		assert(not L.finish(s, h, 2, 11))
		assert(L.finish(s, h, 3, 12) and s.count == 0)
		assert(h.terminal.reason == "completed" and h.terminal.at == 10002)
		assert(not L.terminate(s, h, "expired", 99) and not L.finish(s, h, 3, 99))
	end,
	["capacity never evicts active paid work and returns on release"] = function()
		local s = L.new(1)
		local h = L.start(s, acceptance(), 10, 1, 1)
		assert(not L.hasRoom(s) and not pcall(L.start, s, acceptance("g:2"), 10, 1, 1))
		assert(L.isActive(s, h))
		L.terminate(s, h, "caster_lost", 11)
		assert(L.hasRoom(s) and h.terminal.reason == "caster_lost")
	end,
	["bounded expiry and late callbacks cannot resurrect"] = function()
		local s = L.new(2)
		local h = L.start(s, acceptance(), 10, 1, 1)
		L.expire(s, 12.99)
		assert(L.isActive(s, h))
		L.expire(s, 13)
		assert(s.count == 0 and h.terminal.reason == "expired")
		assert(not L.finish(s, h, 1, 14))
	end,
	["invalid resource and clock cannot mutate completion"] = function()
		local s = L.new(1)
		local h = L.start(s, acceptance(), 10, 1, 1)
		for _, n in { 0 / 0, math.huge, -1, 1.5 } do
			assert(not L.finish(s, h, n, 11))
		end
		for _, n in { 0 / 0, math.huge, 9 } do
			assert(not L.finish(s, h, 1, n))
		end
		assert(h.remaining == 1 and s.count == 1)
		assert(not pcall(L.start, L.new(2), acceptance(), 10, 17, 1))
	end,
}
