local Inbox = require("../src/shared/CastInbox")
local Receipts = require("../src/shared/CastReceipts")
local function inbox()
	return Inbox.new({ capacity = 2, responseSeconds = 10, tombstoneSeconds = 10, maxLifetimeSeconds = 10 })
end
local function accepted(seq)
	return {
		castId = "scope:1:" .. seq,
		generation = "scope:1",
		seq = seq,
		moveId = "move.test",
		casterUserId = 1,
		characterKey = "char-1",
		slotRevision = 0,
		acceptedAt = 1000000,
		releaseAt = 1000000.6,
		endsAt = 1000001.6,
		aim = { x = 0, y = 0, z = -1 },
		origin = { x = 0, y = 3, z = 0 },
		centre = { x = 0, y = 0, z = -10 },
	}
end
local function disposition(seq, status)
	return { generation = "scope:1", seq = seq, moveId = "move.test", status = status or "rejected", reason = "test" }
end
return {
	["duplicate acceptance never refreshes cache; copied immutable clock and centre"] = function()
		local s, a = inbox(), accepted(1)
		assert(Inbox.accept(s, a, 0) == "stored")
		assert(Inbox.accept(s, a, 9) == "duplicate")
		a.centre.y = 9
		assert(Receipts.get(s.acceptances, a.castId, 9).acceptance.centre.y == 0)
		assert(Inbox.accept(s, a, 9) == "conflict")
		Inbox.prune(s, 10)
		assert(next(s.acceptances.entries) == nil)
	end,
	["expired response is not cancellation; acceptance wins over subsequent disposition"] = function()
		local s, a = inbox(), accepted(1)
		assert(Inbox.disposition(s, disposition(1, "expired"), 0) == "stored")
		assert(Inbox.accept(s, a, 1) == "stored" and next(s.responses) == nil)
		assert(Inbox.disposition(s, disposition(1), 2) == "accepted")
		assert(Receipts.get(s.acceptances, a.castId, 2).acceptance == s.acceptances.entries[a.castId].acceptance)
	end,
	["rejection remains bounded, immutable, and suppresses inconsistent late acceptance"] = function()
		local s, v = inbox(), disposition(1)
		assert(Inbox.disposition(s, v, 0) == "stored")
		v.reason = "changed"
		assert(s.responses["scope:1:1"].value.reason == "test")
		assert(Inbox.disposition(s, v, 9) == "duplicate")
		assert(Inbox.accept(s, accepted(1), 9) == "rejected")
		Inbox.prune(s, 10)
		assert(next(s.responses) == nil)
	end,
	["both caches bound insertion floods and destroy all state"] = function()
		local s = inbox()
		for seq = 1, 100 do
			assert(Inbox.accept(s, accepted(seq), 0) == "stored")
			assert(Inbox.disposition(s, disposition(seq + 100), 0) == "stored")
		end
		local a, r = 0, 0
		for _ in s.acceptances.entries do
			a += 1
		end
		for _ in s.responses do
			r += 1
		end
		assert(a == 2 and r == 2 and s.acceptances.entries["scope:1:1"] == nil)
		Inbox.destroy(s)
		Inbox.destroy(s)
		assert(next(s.responses) == nil and next(s.acceptances.entries) == nil)
		assert(Inbox.accept(s, accepted(1), 1) == "invalid" and Inbox.disposition(s, disposition(1), 1) == "invalid")
	end,
	["invalid identity and backwards clocks cannot write inbox"] = function()
		local s = inbox()
		for _, seq in { -1, 65536, 0 / 0, math.huge, 0.5 } do
			assert(Inbox.disposition(s, disposition(seq), 0) == "invalid")
		end
		assert(Inbox.disposition(s, disposition(1, "cancelled"), 0) == "invalid")
		assert(Inbox.disposition(s, disposition(1), 5) == "stored")
		assert(Inbox.disposition(s, disposition(2), 4) == "invalid")
	end,
}
