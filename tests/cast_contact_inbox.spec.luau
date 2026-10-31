local Inbox = require("../src/shared/CastContactInbox")
local function inbox(capacity)
	return Inbox.new({ capacity = capacity or 4, retentionSeconds = 12, futureSeconds = 1 })
end
local function contact(ordinal, at, castId)
	return {
		castId = castId or "g:1",
		ordinal = ordinal,
		resource = 1,
		tick = ordinal,
		targetKey = "target:1",
		at = at or 1000,
		amount = 4,
		position = { x = 1, y = 2, z = 3 },
		direction = { x = 0, y = 0, z = 1 },
	}
end
return {
	["reordered contacts retain independent ordinals without refreshing duplicates"] = function()
		local s = inbox()
		for i, ordinal in { 3, 1, 2 } do
			assert(Inbox.record(s, contact(ordinal, 1000 + ordinal), i, 1004) == "stored")
		end
		local first = Inbox.get(s, "g:1", 1)
		local changed = contact(1, 1009)
		changed.amount = 99
		changed.position.x = 80
		assert(Inbox.record(s, changed, 4, 1009) == "duplicate")
		assert(Inbox.get(s, "g:1", 1) == first and first.expiresAt == 14 and first.value.amount == 4)
		assert(s.count == 3)
	end,
	["stored contacts are immutable deep copies"] = function()
		local s, c = inbox(), contact(1)
		assert(Inbox.record(s, c, 0, 1000) == "stored")
		c.position.x = 9
		c.amount = 80
		local v = Inbox.get(s, "g:1", 1).value
		assert(v.amount == 4 and v.position.x == 1 and table.isfrozen(v) and table.isfrozen(v.position))
		assert(not pcall(function()
			v.direction.z = 0
		end))
	end,
	["ordinal and semantic identity collisions cannot produce two effects"] = function()
		local s = inbox()
		local a = contact(1)
		assert(Inbox.record(s, a, 0, 1000) == "stored")
		local b = contact(1)
		b.targetKey = "other"
		assert(Inbox.record(s, b, 1, 1000) == "conflict")
		b = contact(2)
		b.tick = 1
		assert(Inbox.record(s, b, 1, 1000) == "conflict")
		b = contact(1, 1000, "g:2")
		assert(Inbox.record(s, b, 1, 1000) == "stored" and s.count == 2)
	end,
	["eviction retires duplicates conservatively without clearing retained contacts"] = function()
		local s = inbox(2)
		for i = 1, 3 do
			assert(Inbox.record(s, contact(i, 1000 + i), i, 1003) == "stored")
		end
		assert(s.count == 2 and Inbox.get(s, "g:1", 1) == nil and s.retiredThrough == 1001)
		assert(Inbox.record(s, contact(1, 1001), 4, 1004) == "expired")
		assert(Inbox.record(s, contact(4, 1001, "unseen"), 4, 1004) == "expired")
		assert(Inbox.get(s, "g:1", 2) and Inbox.get(s, "g:1", 3))
		local keys = 0
		for _ in s.identities do
			keys += 1
		end
		assert(keys == s.count)
	end,
	["expiry and destruction never refresh or resurrect old effects"] = function()
		local s = inbox()
		local c = contact(1)
		assert(Inbox.record(s, c, 0, 1000) == "stored")
		assert(Inbox.record(s, c, 11, 1001) == "duplicate")
		assert(Inbox.prune(s, 12) and s.count == 0 and next(s.identities) == nil)
		assert(Inbox.record(s, c, 12, 1001) == "expired")
		assert(Inbox.record(s, contact(2, 1002), 12, 1002) == "stored")
		Inbox.destroy(s)
		Inbox.destroy(s)
		assert(s.closed and s.count == 0 and next(s.entries) == nil and next(s.identities) == nil)
		assert(Inbox.record(s, contact(3, 1003), 13, 1003) == "invalid")
		local restarted = Inbox.new(s.policy, s.retiredThrough)
		assert(Inbox.record(restarted, contact(2, 1002), 0, 1003) == "expired")
	end,
	["late receipts use server freshness not local clock and reject invalid data"] = function()
		local s = inbox()
		assert(Inbox.record(s, contact(1, 1000), 50000, 1011) == "stored")
		assert(Inbox.record(s, contact(2, 1000), 50000, 1012) == "expired")
		assert(Inbox.record(s, contact(3, 1014), 50000, 1012) == "invalid")
		assert(Inbox.record(s, contact(3, 1013), 50000, 1012) == "stored")
		assert(Inbox.record(s, contact(4, 1013), 49999, 1012) == "invalid")
		for _, field in { "ordinal", "resource", "tick", "at", "amount" } do
			for _, bad in { 0 / 0, math.huge, -1 } do
				local c = contact(4, 1012)
				c[field] = bad
				if field == "at" and bad == -1 then
					assert(Inbox.record(s, c, 50000, 1012) == "expired")
				else
					assert(Inbox.record(s, c, 50000, 1012) == "invalid")
				end
			end
		end
		for _, field in { "castId", "targetKey" } do
			local c = contact(4, 1012)
			c[field] = ""
			assert(Inbox.record(s, c, 50000, 1012) == "invalid")
		end
		local c = contact(4, 1012)
		c.position.x = 0 / 0
		assert(Inbox.record(s, c, 50000, 1012) == "invalid" and s.count == 2)
	end,
	["length-prefixed keys cannot alias delimiter-rich cast and target identities"] = function()
		local s = inbox()
		local a = contact(1, 1000, "a:1")
		a.targetKey = "2:target"
		local b = contact(1, 1000, "a")
		b.resource = 2
		b.targetKey = "1:2:target"
		assert(Inbox.record(s, a, 0, 1000) == "stored" and Inbox.record(s, b, 0, 1000) == "stored")
		assert(s.count == 2 and Inbox.get(s, "a:1", 1).value.targetKey == a.targetKey)
	end,
	["sustained pressure has bounded payload and dedupe maps including same-time overload"] = function()
		local s = inbox(8)
		for i = 1, 1000 do
			assert(Inbox.record(s, contact(1, 1000 + i, "cast:" .. i), i, 1000 + i) == "stored")
			assert(s.count <= 8)
		end
		local n = 0
		for _ in s.identities do
			n += 1
		end
		assert(n == s.count)
		local same = inbox(1)
		assert(Inbox.record(same, contact(1, 1000), 0, 1000) == "stored")
		assert(Inbox.record(same, contact(2, 1000), 0, 1000) == "expired")
		assert(Inbox.record(same, contact(1, 1000), 0, 1000) == "expired" and same.count == 0)
	end,
	["invalid policies fail construction and zero damage remains a valid contact"] = function()
		for _, capacity in { 0, -1, 1.5, 65536, math.huge } do
			assert(not pcall(inbox, capacity))
		end
		local s, c = inbox(), contact(1)
		c.amount = 0
		assert(Inbox.record(s, c, 0, 1000) == "stored")
	end,
}
