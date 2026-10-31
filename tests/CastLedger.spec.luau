local Ledger = require("../src/shared/CastLedger")
local function fresh(capacity)
	return Ledger.new("character-1", { capacity = capacity or 3, maxAdvance = 100, responseSeconds = 2 })
end
local function reserve(s, seq, now, fingerprint)
	return Ledger.reserve(s, s.generation, seq, fingerprint or "fan|0,0,1", now or 0)
end
local function eq(a, b)
	assert(a == b, `expected {tostring(b)}, got {tostring(a)}`)
end
return {
	["reserve pending duplicate, then replay immutable accepted verdict"] = function()
		local s = fresh()
		local first = reserve(s, 1)
		eq(first.kind, "reserved")
		eq(reserve(s, 1).kind, "pending")
		local receipt = { status = "accepted", castId = "cast-1" }
		assert(Ledger.complete(s, first.entry, receipt, 0))
		receipt.castId = "mutated"
		local duplicate = reserve(s, 1)
		eq(duplicate.kind, "duplicate")
		eq(duplicate.receipt.castId, "cast-1")
		assert(table.isfrozen(duplicate.receipt))
		assert(not Ledger.complete(s, first.entry, { status = "rejected", reason = "changed" }, 0))
	end,
	["failed request replays rejection without rerunning payment"] = function()
		local s = fresh()
		local first = reserve(s, 1)
		assert(Ledger.complete(s, first.entry, { status = "rejected", reason = "qi" }, 0))
		local again = reserve(s, 1)
		eq(again.kind, "duplicate")
		eq(again.receipt.reason, "qi")
	end,
	["duplicate different move or aim is rejected"] = function()
		local s = fresh()
		reserve(s, 1)
		eq(reserve(s, 1, 0, "fall|5,0,2").reason, "payload_changed")
		eq(reserve(s, 1).kind, "pending")
	end,
	["out of order is stale but skipped forward numbers are allowed"] = function()
		local s = fresh()
		reserve(s, 10)
		eq(reserve(s, 12).kind, "reserved")
		eq(reserve(s, 11).reason, "stale")
		eq(reserve(s, 9).reason, "stale")
		eq(reserve(s, 113).reason, "jump")
		eq(reserve(s, 13).kind, "reserved")
	end,
	["u16 wrap retains duplicate receipt"] = function()
		local s = fresh()
		local first = reserve(s, 65535)
		Ledger.complete(s, first.entry, { status = "accepted", castId = "old" }, 0)
		eq(reserve(s, 0).kind, "reserved")
		eq(reserve(s, 1).kind, "reserved")
		eq(reserve(s, 65535).receipt.castId, "old")
		eq(reserve(s, 65534).reason, "stale")
	end,
	["expiry cannot turn an old sequence into new input"] = function()
		local s = fresh()
		local first = reserve(s, 4)
		eq(Ledger.prune(s, 1.999), 1)
		eq(Ledger.prune(s, 2), 0)
		eq(reserve(s, 4, 2).reason, "stale")
		assert(not Ledger.complete(s, first.entry, { status = "accepted", castId = "late" }, 2))
		eq(reserve(s, 5, 2).kind, "reserved")
	end,
	["duplicates do not extend response cache expiry"] = function()
		local s = fresh()
		reserve(s, 1)
		eq(reserve(s, 1, 1.9).kind, "pending")
		eq(Ledger.prune(s, 2), 0)
	end,
	["capacity eviction cannot replay or complete removed reservation"] = function()
		local s = fresh(1)
		local first = reserve(s, 1)
		reserve(s, 2, 0.1)
		eq(Ledger.prune(s, 0.1), 1)
		eq(reserve(s, 1, 0.1).reason, "stale")
		assert(not Ledger.complete(s, first.entry, { status = "rejected", reason = "late" }, 0.1))
	end,
	["memory remains bounded during sustained unique input"] = function()
		local s = fresh(3)
		for i = 1, 1000 do
			eq(reserve(s, i, i / 10000).kind, "reserved")
			assert(Ledger.prune(s, i / 10000) <= 3)
		end
	end,
	["generation change refuses old packets and completion handles"] = function()
		local old = fresh()
		local first = reserve(old, 1)
		local new = Ledger.new("character-2", old.policy)
		eq(Ledger.reserve(new, "character-1", 1, "fan|0,0,1", 0).reason, "generation")
		eq(reserve(new, 1).kind, "reserved")
		assert(not Ledger.complete(new, first.entry, { status = "accepted", castId = "old" }, 0))
	end,
	["rotate generation before ancient u16 packet can look fresh"] = function()
		local s = Ledger.new("g", { capacity = 1, maxAdvance = 16384, responseSeconds = 1 })
		reserve(s, 65000)
		eq(reserve(s, (65000 + 16384) % 65536).kind, "reserved")
		eq(reserve(s, (65000 + 32767) % 65536).kind, "reserved")
		eq(reserve(s, (65000 + 32768) % 65536).reason, "rotate_generation")
		eq(reserve(s, 65000).reason, "stale")
	end,
	["invalid sequence fingerprint or generation allocates nothing"] = function()
		local s = fresh()
		for _, seq in { -1, 65536, 1.5, 0 / 0, math.huge, -math.huge } do
			eq(reserve(s, seq).reason, "malformed")
		end
		eq(reserve(s, 1, 0, "").reason, "malformed")
		eq(reserve(s, 1, 0, string.rep("x", 257)).reason, "malformed")
		eq(Ledger.reserve(s, "bad", 1, "x", 0).reason, "generation")
		eq(Ledger.prune(s, 0), 0)
		eq(s.lastSeq, nil)
	end,
	["nonfinite and backward clock cannot mutate ledger"] = function()
		local s = fresh()
		reserve(s, 1, 10)
		for _, now in { 9, 0 / 0, math.huge, -math.huge } do
			eq(reserve(s, 2, now).reason, "clock")
			eq(Ledger.prune(s, now), nil)
		end
		eq(s.lastSeq, 1)
		eq(reserve(s, 2, 10).kind, "reserved")
	end,
	["invalid receipts never complete"] = function()
		local s = fresh()
		local first = reserve(s, 1)
		for _, receipt in
			{
				{ status = "accepted" },
				{ status = "accepted", castId = "x", reason = "bad" },
				{ status = "rejected" },
				{ status = "rejected", castId = "x", reason = "bad" },
				{ status = "bad" },
			}
		do
			assert(not Ledger.complete(s, first.entry, receipt, 0))
		end
		eq(reserve(s, 1).kind, "pending")
	end,
	["configuration is copied and validated"] = function()
		local p = { capacity = 2, maxAdvance = 10, responseSeconds = 2 }
		local s = Ledger.new("g", p)
		p.capacity = 100
		eq(s.policy.capacity, 2)
		for _, bad in
			{
				{ capacity = 0, maxAdvance = 10, responseSeconds = 2 },
				{ capacity = 2, maxAdvance = 32768, responseSeconds = 2 },
				{ capacity = 2, maxAdvance = 10, responseSeconds = math.huge },
			}
		do
			assert(not pcall(Ledger.new, "g", bad))
		end
	end,
}
