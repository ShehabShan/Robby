local Inbox = require("../src/shared/CastInbox")
local Receipts = require("../src/shared/CastReceipts")
local function inbox()
	return Inbox.new({ capacity = 2, responseSeconds = 10, tombstoneSeconds = 10, maxLifetimeSeconds = 10 })
end
local function accepted(seq)
	return {
		["all duplicate reorder permutations converge on one terminal without TTL refresh"] = function()
			local function permutations(items, prefix)
				if #items == 0 then
					local s, a = inbox(), accepted(1)
					local firstTerminal
					for i, event in prefix do
						if event == "A" then
							Inbox.accept(s, a, i * 0.01)
						else
							Inbox.terminal(s, a.castId, "completed", a.endsAt, i * 0.01)
							firstTerminal = firstTerminal or i * 0.01
						end
					end
					local entry = s.acceptances.entries[a.castId]
					assert(entry.terminal.reason == "completed" and entry.expiresAt == firstTerminal + 10)
					assert(Inbox.accept(s, a, 1) == "terminal")
					return
				end
				for i, event in items do
					local rest, nextPrefix = table.clone(items), table.clone(prefix)
					table.remove(rest, i)
					table.insert(nextPrefix, event)
					permutations(rest, nextPrefix)
				end
			end
			permutations({ "A", "A", "T", "T" }, {})
		end,
		["terminal before acceptance wins; duplicate cannot refresh reason clock or ttl"] = function()
			local s, a = inbox(), accepted(1)
			assert(Inbox.disposition(s, disposition(1), 0) == "stored")
			assert(Inbox.terminal(s, a.castId, "caster_lost", a.acceptedAt + 0.3, 1) == "stored")
			local original = s.acceptances.entries[a.castId]
			assert(next(s.responses) == nil and original.acceptance == nil)
			assert(Inbox.accept(s, a, 2) == "terminal")
			assert(Inbox.terminal(s, a.castId, "expired", a.acceptedAt + 5, 9) == "duplicate")
			assert(s.acceptances.entries[a.castId] == original and original.expiresAt == 11)
			assert(original.terminal.reason == "caster_lost")
		end,
		["acceptance then terminal retains immutable geometry and ignores late disposition"] = function()
			local s, a = inbox(), accepted(1)
			assert(Inbox.accept(s, a, 0) == "stored")
			assert(Inbox.terminal(s, a.castId, "completed", a.acceptedAt + 1, 1) == "stored")
			local entry = s.acceptances.entries[a.castId]
			a.origin.y = 999
			assert(entry.acceptance.origin.y == 3 and entry.terminal.at == 1000001)
			assert(Inbox.disposition(s, disposition(1, "expired"), 2) == "accepted")
			assert(next(s.responses) == nil and Inbox.accept(s, a, 2) == "terminal")
		end,
		["terminal eviction and expiry leave bounded watermark blocking resurrection"] = function()
			local s, a = inbox(), accepted(1)
			Inbox.terminal(s, a.castId, "completed", a.acceptedAt + 0.1, 0)
			Inbox.terminal(s, "scope:1:2", "completed", a.acceptedAt + 0.2, 0)
			Inbox.terminal(s, "scope:1:3", "completed", a.acceptedAt + 0.3, 0)
			assert(s.acceptances.entries[a.castId] == nil and s.retiredThrough == a.acceptedAt + 0.1)
			assert(Inbox.accept(s, a, 1) == "terminal")
			Inbox.prune(s, 10)
			assert(next(s.acceptances.entries) == nil and s.retiredThrough == a.acceptedAt + 0.3)
			assert(Inbox.accept(s, accepted(3), 11) == "terminal")
			local fresh = accepted(4)
			fresh.acceptedAt, fresh.releaseAt, fresh.endsAt = 1000011, 1000011.6, 1000012.6
			assert(Inbox.accept(s, fresh, 11, 1000011, 1) == "stored")
		end,
		["acceptance pressure retires evicted terminal without clearing an existing world hazard"] = function()
			local s, a = inbox(), accepted(1)
			Inbox.terminal(s, a.castId, "completed", a.acceptedAt + 0.5, 0)
			Inbox.accept(s, accepted(2), 0)
			local hazard = s.acceptances.entries["scope:1:2"]
			Inbox.accept(s, accepted(3), 0)
			assert(s.retiredThrough == a.acceptedAt + 0.5)
			assert(Inbox.accept(s, a, 1) == "terminal")
			assert(Inbox.accept(s, accepted(2), 1) == "duplicate" and s.acceptances.entries["scope:1:2"] == hazard)
		end,
		["expiry is tested with synchronized server clock plus grace not cache clock"] = function()
			local s, a = inbox(), accepted(1)
			assert(Inbox.accept(s, a, 500, a.endsAt + 0.99, 1) == "stored")
			assert(Inbox.accept(inbox(), a, 0, a.endsAt + 1, 1) == "expired")
			assert(Inbox.accept(inbox(), a, 5000000, a.acceptedAt, 1) == "stored")
		end,
		["invalid early terminal backward time and destroyed inbox cannot mutate state"] = function()
			local s, a = inbox(), accepted(1)
			Inbox.accept(s, a, 1)
			assert(Inbox.terminal(s, a.castId, "completed", a.acceptedAt - 1, 2) == "invalid")
			assert(Inbox.terminal(s, a.castId, "completed", a.acceptedAt, 1) == "invalid")
			assert(Inbox.terminal(s, a.castId, "", a.acceptedAt, 2) == "invalid")
			assert(Inbox.terminal(s, a.castId, "completed", 0 / 0, 2) == "invalid")
			assert(s.acceptances.entries[a.castId].terminal == nil and s.retiredThrough == -math.huge)
			Inbox.destroy(s)
			assert(Inbox.terminal(s, a.castId, "completed", a.acceptedAt, 3) == "invalid")
		end,
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
