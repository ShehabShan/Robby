local D = require("../src/shared/CastContactDispatch")
local I = require("../src/shared/CastContactInbox")
local B = require("../src/shared/CastBridge")
local Config = require("../src/shared/Config")
local function contact(n, at, castId)
	return {
		castId = castId or "g:1",
		ordinal = n,
		resource = 1,
		tick = n,
		targetKey = "target:1",
		at = at or 100,
		amount = 4,
		position = { x = 1, y = 2, z = 3 },
		direction = { x = 0, y = 0, z = 1 },
	}
end
local function setup(cap, render, receiptCap)
	local inbox = I.new({ capacity = receiptCap or 8, retentionSeconds = 12, futureSeconds = 1 })
	local f = { frames = {}, disposed = 0, tickets = {} }
	local state = D.new(inbox, { capacity = cap or 4, perContact = 2, effectSeconds = 0.5 }, render or function(frame)
		table.insert(f.frames, frame)
		table.insert(
			f.tickets,
			assert(frame.bind("spark", function()
				f.disposed += 1
			end))
		)
		return true
	end)
	return state, inbox, f
end
local function record(inbox, n, now, at, castId)
	assert(I.record(inbox, contact(n, at, castId), now or 0, at or 100) == "stored")
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end
return {
	["one command per confirmed identity despite duplicate delivery and repeated polling"] = function()
		local s, i, f = setup()
		record(i, 1)
		assert(D.tick(s, 0, 100) and #f.frames == 1 and s.consumed == 1)
		for _ = 1, 1000 do
			assert(I.record(i, contact(1), 0, 100) == "duplicate")
			assert(D.tick(s, 0, 100))
		end
		assert(#f.frames == 1 and count(i.consumed) == 1)
		assert(f.frames[1].action == "contact" and table.isfrozen(f.frames[1]))
	end,
	["contact take is atomic and bounded by normal inbox retirement"] = function()
		local s, i = setup()
		record(i, 1)
		local key = next(i.entries)
		assert(I.take(i, key, 0) and I.take(i, key, 0) == nil)
		assert(D.tick(s, 0, 100) and s.consumed == 0)
		assert(I.take(i, key, -1) == nil)
		I.prune(i, 12)
		assert(count(i.consumed) == 0 and i.count == 0)
		assert(I.record(i, contact(1), 12, 100) == "expired")
	end,
	["all acceptance contact terminal orders render exactly once for owner and observer"] = function()
		for _, predicted in { true, false } do
			for _, order in { "ACT", "ATC", "CAT", "CTA", "TAC", "TCA" } do
				local s, i, f = setup()
				local bridge = B.new(
					{ capacity = 4, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 },
					2,
					function()
						return true
					end
				)
				if predicted then
					B.predict(bridge, "g:1", 99.9)
				end
				for index = 1, 3 do
					local action = string.sub(order, index, index)
					if action == "A" then
						B.accept(
							bridge,
							"g:1",
							{ acceptedAt = 100, releaseAt = 100, endsAt = 101, x = 0, y = 0, z = 0 },
							100
						)
					elseif action == "T" then
						B.cancel(bridge, "g:1", 100)
					else
						record(i, 1)
						D.tick(s, 0, 100)
					end
				end
				assert(#f.frames == 1 and s.resources.count == 1, order)
				B.destroy(bridge)
				assert(f.disposed == 0)
				D.tick(s, 0.5, 100.5)
				assert(f.disposed == 1)
			end
		end
	end,
	["no acceptance prediction terminal or empty inbox invents a hit"] = function()
		local s, _, f = setup()
		assert(D.tick(s, 0, 100) and D.tick(s, 5, 105))
		assert(#f.frames == 0 and s.consumed == 0)
	end,
	["lower ordinals and independent cast resources survive reordering"] = function()
		local s, i, f = setup()
		for _, n in { 3, 1, 2 } do
			record(i, n)
		end
		D.tick(s, 0, 100)
		assert(#f.frames == 3 and f.frames[1].contact.ordinal == 3 and f.frames[2].contact.ordinal == 1)
		assert(f.frames[1].lease ~= f.frames[2].lease)
	end,
	["resource expiry is local independent per contact and does not erase receipt dedupe"] = function()
		local s, i, f = setup()
		record(i, 1)
		D.tick(s, 0, 100)
		record(i, 2, 0.2, 100.2)
		D.tick(s, 0.2, 100.2)
		D.tick(s, 0.5, 500)
		assert(f.disposed == 1 and s.resources.count == 1 and i.count == 2)
		D.tick(s, 0.7, 50)
		assert(f.disposed == 2 and s.resources.count == 0 and s.consumed == 2)
		assert(not f.frames[1].isCurrent(f.tickets[1]))
	end,
	["capacity refuses new cosmetics without evicting existing contact or retrying later"] = function()
		local s, i, f = setup(1)
		record(i, 1)
		record(i, 2)
		D.tick(s, 0, 100)
		assert(s.consumed == 2 and s.overflow == 1 and #f.frames == 1 and f.disposed == 0)
		D.tick(s, 1, 101)
		assert(#f.frames == 1 and f.disposed == 1)
		record(i, 3, 1, 101)
		D.tick(s, 1, 101)
		assert(#f.frames == 2 and s.resources.count == 1)
	end,
	["future contacts wait for server time without early consumption"] = function()
		local s, i, f = setup()
		assert(I.record(i, contact(1, 101), 0, 100) == "stored")
		D.tick(s, 0, 100)
		D.tick(s, 0.1, 99)
		assert(s.consumed == 0 and #f.frames == 0)
		D.tick(s, 0.2, 101)
		assert(#f.frames == 1 and f.frames[1].expiresAt == 0.7)
	end,
	["future waiting cannot outlive inbox TTL or revive after clock recovery"] = function()
		local s, i, f = setup()
		assert(I.record(i, contact(1, 101), 0, 100) == "stored")
		D.tick(s, 12, 100)
		D.tick(s, 13, 101)
		assert(#f.frames == 0 and i.count == 0)
		assert(I.record(i, contact(1, 101), 13, 101) == "expired")
	end,
	["server-stale retained contact is consumed but never rendered or retried"] = function()
		local s, i, f = setup()
		record(i, 1)
		D.tick(s, 1, 112)
		assert(s.stale == 1 and s.consumed == 1 and #f.frames == 0)
		D.tick(s, 2, 100)
		assert(s.stale == 1 and #f.frames == 0)
	end,
	["invalid clocks refuse without consuming or refreshing existing lifetime"] = function()
		local s, i, f = setup()
		record(i, 1)
		D.tick(s, 1, 100)
		for _, bad in { 0 / 0, math.huge, -math.huge } do
			assert(not D.tick(s, bad, 100) and not D.tick(s, 1, bad))
		end
		assert(not D.tick(s, 0, 100) and f.disposed == 0)
		D.tick(s, 1.5, 100)
		assert(f.disposed == 1 and s.refusals == 7)
	end,
	["immutable server payload includes zero damage and delimiter rich identities"] = function()
		local s, i, f = setup()
		local value = contact(1, 100, "a:b:c:1")
		value.amount = 0
		value.targetKey = "x:y:2"
		assert(I.record(i, value, 0, 100) == "stored")
		value.position.x = 999
		value.direction.z = 999
		D.tick(s, 0, 100)
		local c = f.frames[1].contact
		assert(c.amount == 0 and c.position.x == 1 and c.direction.z == 1 and c.targetKey == "x:y:2")
		assert(not pcall(function()
			c.amount = 2
		end))
	end,
	["false and throwing renderer clean partial allocation and never retry"] = function()
		for _, throwing in { false, true } do
			local cleaned = 0
			local s, i = setup(4, function(frame)
				frame.bind("partial", function()
					cleaned += 1
				end)
				if throwing then
					error("render failure")
				end
				return false
			end)
			record(i, 1)
			D.tick(s, 0, 100)
			D.tick(s, 1, 101)
			assert(cleaned == 1 and s.resources.count == 0 and s.renderFailures == 1 and s.rendered == 0)
		end
	end,
	["bind limits dispose refused allocations and cleanup errors cannot stop later leases"] = function()
		local cleaned = 0
		local s, i = setup(4, function(frame)
			assert(frame.bind("one", function()
				cleaned += 1
				error("cleanup")
			end))
			assert(frame.bind("two", function()
				cleaned += 1
			end))
			assert(not frame.bind("three", function()
				cleaned += 1
			end))
			return true
		end)
		record(i, 1)
		record(i, 2)
		D.tick(s, 0, 100)
		assert(cleaned == 2 and s.resourceRefusals == 2)
		D.tick(s, 0.5, 100.5)
		assert(cleaned == 6 and s.resources.cleanupFailures == 2 and s.resources.count == 0)
	end,
	["foreign and stale tickets cannot release a different contact"] = function()
		local s, i, f = setup()
		record(i, 1)
		record(i, 2)
		D.tick(s, 0, 100)
		assert(not f.frames[1].isCurrent(f.tickets[2]) and not f.frames[1].release(f.tickets[2]))
		assert(f.frames[1].release(f.tickets[1]) and not f.frames[1].release(f.tickets[1]))
		D.tick(s, 0.5, 100.5)
		assert(f.disposed == 2)
		assert(not f.frames[1].bind("late", function()
			f.disposed += 1
		end))
		assert(f.disposed == 3)
	end,
	["reentrant tick destroy and disposer cannot duplicate or corrupt a command"] = function()
		local state, cleaned
		cleaned = 0
		local s, i = setup(4, function(frame)
			assert(not D.tick(state, 0, 100) and not D.destroy(state))
			frame.bind("x", function()
				cleaned += 1
				assert(not frame.isCurrent({ lease = frame.lease, slot = "x", serial = -1 }))
				assert(not D.tick(state, 0.5, 100.5))
			end)
			return true
		end)
		state = s
		record(i, 1)
		D.tick(s, 0, 100)
		D.tick(s, 0.5, 100.5)
		assert(s.rendered == 1 and cleaned == 1 and not s.busy)
	end,
	["teardown is idempotent closes leases but preserves borrowed inbox consumed flags"] = function()
		local s, i, f = setup()
		record(i, 1)
		D.tick(s, 0, 100)
		assert(D.destroy(s) and not D.destroy(s) and not D.tick(s, 1, 101))
		assert(f.disposed == 1 and not i.closed)
		local replayed = 0
		local replacement = D.new(i, s.policy, function()
			replayed += 1
			return true
		end)
		assert(D.tick(replacement, 1, 101) and replayed == 0)
		record(i, 2, 1, 101)
		D.tick(replacement, 1, 101)
		assert(replayed == 1)
	end,
	["closed inbox shuts down active resources on next valid tick"] = function()
		local s, i, f = setup()
		record(i, 1)
		D.tick(s, 0, 100)
		I.destroy(i)
		assert(not D.tick(s, 0.1, 100.1) and s.closed and f.disposed == 1)
		assert(I.take(i, "unknown", 0.1) == nil and count(i.consumed) == 0)
	end,
	["sustained streams bound every map and cannot replay evicted consumed records"] = function()
		local s, i, f = setup(2, nil, 3)
		for n = 1, 1000 do
			record(i, n, n, 100 + n)
			D.tick(s, n, 100 + n)
			assert(count(i.entries) <= 3 and count(i.consumed) <= 3 and count(i.identities) <= 3)
			assert(count(s.active) <= 2 and s.resources.count <= 2)
		end
		assert(#f.frames == 1000 and f.disposed == 999)
		assert(I.record(i, contact(1, 101), 1000, 1100) == "expired")
		D.destroy(s)
		assert(f.disposed == 1000 and count(s.active) == 0)
	end,
	["production policy and invalid constructor settings are checked"] = function()
		local i = I.new(Config.CastClientContact)
		local s = D.new(i, Config.CastContactPresentation, function()
			return true
		end)
		assert(s.resources.capacity == 128 and s.resources.perCast == 4 and s.policy.effectSeconds == 0.6)
		for _, duration in { 0, -1, 0 / 0, math.huge, 13 } do
			assert(not pcall(D.new, i, { capacity = 1, perContact = 1, effectSeconds = duration }, function()
				return true
			end))
		end
		I.destroy(i)
		assert(not pcall(D.new, i, Config.CastContactPresentation, function()
			return true
		end))
	end,
}
