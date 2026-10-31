local Store = require("../src/shared/CastReceipts")
local Admission = require("../src/shared/CastAdmission")
local function store(capacity)
	return Store.new({ capacity = capacity or 3, responseSeconds = 10, tombstoneSeconds = 20, maxLifetimeSeconds = 20 })
end
local function acceptance(seq, generation)
	local gen = generation or "scope:1"
	return {
		castId = gen .. ":" .. tostring(seq or 1),
		generation = gen,
		seq = seq or 1,
		moveId = "move.test",
		casterUserId = 42,
		characterKey = "character-1",
		slotRevision = 7,
		acceptedAt = 1000000,
		releaseAt = 1000000.2,
		endsAt = 1000001.6,
		aim = { x = 0, y = 0, z = -1 },
		origin = { x = 0, y = 3, z = 0 },
		centre = { x = 5, y = 0, z = -10 },
	}
end
return {
	["deep immutable original on duplicate; duplicate cannot extend expiry"] = function()
		local s, a = store(), acceptance()
		assert(Store.put(s, a, 0) == "stored")
		local entry = Store.get(s, a.castId, 0)
		a.aim.x = 99
		a.centre.y = 99
		a.acceptedAt = 0
		assert(
			entry.acceptance.aim.x == 0 and entry.acceptance.centre.y == 0 and entry.acceptance.acceptedAt == 1000000
		)
		assert(not pcall(function()
			entry.acceptance.origin.x = 1
		end))
		assert(not pcall(function()
			entry.expiresAt = 999
		end))
		assert(Store.put(s, acceptance(), 9) == "duplicate")
		assert(Store.get(s, a.castId, 9) == entry)
		assert(Store.get(s, a.castId, 10) == nil)
	end,
	["conflicting acceptance refuses every authoritative field"] = function()
		for _, change in
			{
				function(a)
					a.moveId = "other"
				end,
				function(a)
					a.casterUserId = 43
				end,
				function(a)
					a.characterKey = "character-2"
				end,
				function(a)
					a.slotRevision = 8
				end,
				function(a)
					a.acceptedAt -= 0.1
				end,
				function(a)
					a.releaseAt += 0.1
				end,
				function(a)
					a.endsAt += 0.1
				end,
				function(a)
					a.aim.y = 0.1
				end,
				function(a)
					a.origin.z = 0.1
				end,
				function(a)
					a.centre.x = 0.1
				end,
				function(a)
					a.centre = nil
				end,
			}
		do
			local s, a = store(), acceptance()
			Store.put(s, a, 0)
			change(a)
			assert(Store.put(s, a, 1) == "conflict")
			assert(Store.get(s, a.castId, 1).acceptance.moveId == "move.test")
		end
	end,
	["terminal before acceptance suppresses resurrection and first terminal wins"] = function()
		local s, a = store(), acceptance()
		assert(Store.terminate(s, a.castId, "cancelled", 1000000.5, 0) == "stored")
		assert(Store.put(s, a, 1) == "terminal")
		assert(Store.terminate(s, a.castId, "expired", 1000001.6, 9) == "duplicate")
		local e = Store.get(s, a.castId, 10)
		assert(e.acceptance == nil and e.terminal.reason == "cancelled" and e.terminal.at == 1000000.5)
		assert(Store.get(s, a.castId, 20) == nil)
	end,
	["accepted terminal preserves original record and survives generation rotation"] = function()
		local s, a = store(), acceptance()
		Store.put(s, a, 0)
		local original = Store.get(s, a.castId, 0).acceptance
		assert(Store.terminate(s, a.castId, "expired", a.endsAt, 2) == "stored")
		assert(Store.put(s, acceptance(1, "scope:2"), 3) == "stored")
		assert(Store.get(s, a.castId, 3).acceptance == original)
		assert(Store.get(s, a.castId, 3).terminal.reason == "expired")
	end,
	["bounded oldest eviction including tombstones never changes gameplay admission"] = function()
		local s = store(2)
		local admission =
			Admission.new("scope", { capacity = 2, maxAdvance = 10, responseSeconds = 10, renewDistance = 100 })
		local paid = 0
		local function dispatch(seq, now)
			return Admission.dispatch(
				admission,
				{ generation = "scope:1", seq = seq, moveId = "move.test", aim = { x = 0, y = 0, z = -1 } },
				now,
				function()
					paid += 1
					return true, nil
				end
			)
		end
		dispatch(1, 0)
		Store.put(s, acceptance(1), 0)
		for seq = 2, 1000 do
			Store.put(s, acceptance(seq), seq / 1000)
		end
		local count = 0
		for _ in s.entries do
			count += 1
		end
		assert(count == 2 and Store.get(s, "scope:1:1", 1) == nil)
		assert(dispatch(1, 1).kind == "duplicate" and paid == 1)
		assert(dispatch(1, 11).kind == "rejected" and paid == 1)
		Store.terminate(s, "old:1:1", "cancelled", 100, 11)
		Store.terminate(s, "old:1:2", "cancelled", 100, 11)
		count = 0
		for _ in s.entries do
			count += 1
		end
		assert(count == 2)
	end,
	["invalid identities times vectors clocks and lifetime refused"] = function()
		for _, change in
			{
				function(a)
					a.castId = "wrong"
				end,
				function(a)
					a.seq = 65536
				end,
				function(a)
					a.aim.x = 0 / 0
				end,
				function(a)
					a.centre.y = math.huge
				end,
				function(a)
					a.origin.z = -math.huge
				end,
				function(a)
					a.slotRevision = -1
				end,
				function(a)
					a.releaseAt = a.acceptedAt - 1
				end,
				function(a)
					a.endsAt = a.acceptedAt + 21
				end,
				function(a)
					a.acceptedAt = 0 / 0
				end,
				function(a)
					a.characterKey = ""
				end,
			}
		do
			local s, a = store(), acceptance()
			change(a)
			assert(Store.put(s, a, 0) == "invalid" and next(s.entries) == nil)
		end
		local s, a = store(), acceptance()
		Store.put(s, a, 5)
		assert(Store.get(s, a.castId, 4) == nil and Store.get(s, a.castId, 0 / 0) == nil)
		assert(Store.get(s, a.castId, 5) ~= nil)
		assert(Store.terminate(s, a.castId, "bad", a.acceptedAt - 1, 5) == "invalid")
		assert(
			not pcall(Store.new, { capacity = 1, responseSeconds = 10, tombstoneSeconds = 1, maxLifetimeSeconds = 2 })
		)
	end,
	["active lifetime retained; destroy is final"] = function()
		local s, a = store(), acceptance()
		a.endsAt = a.acceptedAt + 15
		Store.put(s, a, 0)
		assert(Store.get(s, a.castId, 14))
		Store.destroy(s)
		assert(next(s.entries) == nil and Store.get(s, a.castId, 14) == nil)
		assert(Store.put(s, a, 15) == "invalid" and Store.terminate(s, a.castId, "late", a.endsAt, 15) == "invalid")
	end,
}
