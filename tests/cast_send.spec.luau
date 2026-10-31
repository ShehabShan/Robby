local Send = require("../src/shared/CastSend")
local function fixture()
	local f = { ready = true, generation = "server:1", sent = {}, predicted = {}, reads = 0 }
	f.identity = { generation = "server:1", characterKey = "original", slotRevision = 1, casterUserId = 42 }
	f.deps = {
		ready = function()
			return f.ready
		end,
		generation = function()
			return f.generation
		end,
		fire = function(value)
			table.insert(f.sent, value)
			if f.fireHook then
				f.fireHook()
			end
		end,
		snapshot = function()
			f.reads += 1
			if f.snapshotHook then
				return f.snapshotHook()
			end
			return f.identity
		end,
		predict = function(key, value)
			table.insert(f.predicted, { key = key, identity = value })
			if f.predictHook then
				f.predictHook()
			end
		end,
	}
	f.send = Send.new(f.deps)
	return f
end
return {
	["two callers share exact server key generation and immutable original snapshot"] = function()
		local f = fixture()
		local ability = f.send
		local kith = f.send
		local aim, point = { x = 1 }, { x = 2 }
		local status, key = ability("move.a", aim, point)
		assert(status == "sent" and key == "server:1:1")
		f.generation = "server:2"
		f.identity.generation = "server:2"
		kith("move.b", aim, nil)
		assert(#f.sent == 2 and f.sent[1].aim == aim and f.sent[1].point == point and f.sent[2].point == nil)
		assert(f.predicted[1].identity.generation == "server:1" and table.isfrozen(f.predicted[1].identity))
		assert(f.predicted[2].key == "server:2:2" and f.sent[2].seq == 2)
	end,
	["unready neither allocates sequence nor snapshots nor sends"] = function()
		local f = fixture()
		f.ready = false
		assert(f.send("a", {}) == "unready")
		f.ready = true
		f.generation = nil
		assert(f.send("a", {}) == "unready")
		f.generation = ""
		assert(f.send("a", {}) == "unready")
		assert(#f.sent == 0 and f.reads == 0)
		f.generation = "server:1"
		assert(select(2, f.send("a", {})) == "server:1:1")
	end,
	["missing stale malformed and throwing cosmetic identity never blocks request"] = function()
		for _, mode in { "missing", "stale", "malformed", "throw" } do
			local f = fixture()
			f.snapshotHook = function()
				if mode == "throw" then
					error("snapshot unavailable")
				end
				if mode == "missing" then
					return nil
				end
				if mode == "malformed" then
					return {}
				end
				local v = table.clone(f.identity)
				v.generation = "old"
				return v
			end
			assert(f.send("a", {}) == "sent" and #f.sent == 1 and #f.predicted == 0, mode)
		end
	end,
	["prediction failure never retries duplicates or reports gameplay refusal"] = function()
		local f = fixture()
		f.predictHook = function()
			error("pool failure")
		end
		assert(f.send("a", {}) == "sent" and #f.sent == 1 and #f.predicted == 1)
		assert(f.send("b", {}) == "sent" and #f.sent == 2 and f.sent[2].seq == 2)
	end,
	["uncertain transport consumes key and never predicts or retries possibly paid cast"] = function()
		local f = fixture()
		f.fireHook = function()
			error("disconnect after send")
		end
		local status, key = f.send("a", {})
		assert(status == "transport_uncertain" and key == "server:1:1" and #f.sent == 1 and #f.predicted == 0)
		f.fireHook = nil
		f.send("b", {})
		assert(f.sent[2].seq == 2 and f.predicted[1].key == "server:1:2")
	end,
	["prediction remains optional and off means no snapshot work"] = function()
		local f = fixture()
		f.deps.predict = nil
		assert(f.send("a", {}) == "sent" and #f.sent == 1 and #f.predicted == 0 and f.reads == 0)
	end,
	["transport callback cannot relabel the captured original prediction"] = function()
		local f = fixture()
		f.fireHook = function()
			f.identity.characterKey = "replacement"
		end
		f.send("a", {})
		assert(f.predicted[1].identity.characterKey == "original")
	end,
	["sequence wraps u16 without allocating a second per-input counter"] = function()
		local f = fixture()
		f.deps.predict = nil
		for _ = 1, 65536 do
			f.send("a", {})
		end
		assert(f.sent[65535].seq == 65535 and f.sent[65536].seq == 0)
	end,
}
