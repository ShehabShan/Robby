local Store = require("../src/shared/CastDeliveryStore")
local Gate = require("../src/shared/CastWarningGate")
local Map = require("../src/shared/CastCommandMap")
local Geometry = require("../src/shared/CastGeometry")
local Inbox = require("../src/shared/CastInbox")
local Config = require("../src/shared/Config")
local function acceptance(seq)
	return {
		castId = "g:" .. tostring(seq or 1),
		generation = "g",
		seq = seq or 1,
		casterUserId = 42,
		characterKey = "old",
		slotRevision = 4,
		moveId = "m",
		acceptedAt = 100,
		releaseAt = 101,
		endsAt = 105,
		origin = { x = 2, y = 3, z = 4 },
		centre = { x = 5, y = 6, z = 7 },
		aim = { x = 0, y = 0, z = -1 },
		geometry = assert(Geometry.capture({ delivery = { kind = "Zone", params = { radius = 17, range = 40 } } }, {})),
	}
end
local catalog = { m = { delivery = "Zone", worldWarning = true } }
local function fixture(capacity)
	local f =
		{ store = Store.new(capacity or 16), inbox = Inbox.new(Config.CastClientReceipt), rendered = {}, warnings = {} }
	f.gate = Gate.new(Config.CastWarning, function(frame)
		local entry = assert(Store.get(f.store, frame.key), "missing staged metadata")
		table.insert(f.rendered, entry)
		return not f.fail
	end, function(frame)
		local entry = assert(Store.get(f.store, frame.key), "missing pinned reserve metadata")
		assert(entry.accepted)
		table.insert(f.warnings, entry)
		return not f.failReserve
	end)
	function f:command(seq)
		local a = acceptance(seq)
		assert(Inbox.accept(self.inbox, a, 0, 100, 1) == "stored")
		return assert(Map.accepted(catalog, self.inbox.acceptances.entries[a.castId]))
	end
	function f:accept(c, localNow, serverNow)
		assert(Store.accept(self.store, c) == "stored")
		local result = Gate.accept(self.gate, c.key, c.timeline, localNow or 0, serverNow or 100)
		Store.prune(self.store, self.gate)
		return result
	end
	return f
end
return {
	["queued wait timeout prunes pinned metadata without flashing old geometry"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c, 0, 99.8)
		Gate.tick(f.gate, 3, 102.8)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0 and #f.rendered == 0 and f.gate.gate.expired == 1)
	end,
	["failed prediction retains identity for later genuine acceptance"] = function()
		local f, a = fixture(), acceptance()
		Store.predict(f.store, a.castId, a)
		f.fail = true
		Gate.predict(f.gate, a.castId, 0, 100)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 1 and #f.warnings == 0)
		f.fail = false
		local c = f:command()
		f:accept(c, 0.5, 100.5)
		assert(Store.get(f.store, c.key).accepted == c)
	end,
	["primary pose retirement retains accepted world metadata until exact expiry"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c)
		local e = Store.get(f.store, c.key)
		Gate.retirePose(f.gate, c.key, 1, 101)
		Store.prune(f.store, f.gate)
		assert(Store.get(f.store, c.key) == e)
		Gate.tick(f.gate, 5, 105)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0)
	end,
	["metadata prediction snapshots identity; adoption pins canonical command"] = function()
		local f, a = fixture(), acceptance()
		assert(Store.predict(f.store, a.castId, a) == "stored")
		a.characterKey = "mutated"
		assert(Store.get(f.store, a.castId).identity.characterKey == "old")
		assert(Gate.predict(f.gate, a.castId, 0, 100) == "predict")
		local c = f:command()
		f:accept(c, 0.5, 100.5)
		local e = Store.get(f.store, c.key)
		assert(e.accepted == c and table.isfrozen(e) and table.isfrozen(e.identity))
		assert(f.store.count == 1)
		Gate.tick(f.gate, 2, 102)
		Store.prune(f.store, f.gate)
		assert(f.rendered[#f.rendered] == e)
	end,
	["duplicate mapper output preserves first metadata object; conflicting receipt refuses"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c)
		local other = assert(Map.accepted(catalog, f.inbox.acceptances.entries[c.key]))
		assert(other.metadata ~= c.metadata)
		assert(Store.accept(f.store, other) == "duplicate")
		assert(Store.get(f.store, c.key).accepted.metadata == c.metadata)
		local fresh = fixture():command()
		assert(Store.accept(f.store, fresh) == "conflict")
		assert(Store.get(f.store, c.key).accepted == c)
	end,
	["future queue pins metadata until drain; admission refusal prunes stage"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c, 0, 99.8)
		assert(#f.rendered == 0 and f.store.count == 1 and f.gate.gate.pending[c.key])
		Gate.tick(f.gate, 0.3, 100.1)
		Store.prune(f.store, f.gate)
		assert(#f.rendered > 0 and f.store.count == 1)
		local g = fixture()
		local d = g:command()
		g:accept(d, 0, 98)
		assert(g.store.count == 0 and #g.rendered == 0)
	end,
	["late primary failure transfers same metadata to reserve after inbox eviction"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c)
		local e = Store.get(f.store, c.key)
		table.clear(f.inbox.acceptances.entries)
		f.fail = true
		Gate.tick(f.gate, 2, 102)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 1 and f.warnings[#f.warnings] == e)
		Gate.retirePose(f.gate, c.key, 3, 103)
		Store.prune(f.store, f.gate)
		assert(Store.get(f.store, c.key) == e)
		Gate.tick(f.gate, 5, 105)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0)
	end,
	["both pool failures release metadata despite retained terminal tombstones"] = function()
		local f = fixture()
		f.fail, f.failReserve = true, true
		local c = f:command()
		f:accept(c)
		assert(f.gate.gate.bridge.presentation.entries[c.key] and f.gate.reserve.bridge.presentation.entries[c.key])
		assert(f.store.count == 0)
	end,
	["cancel before queue drain removes pending and pinned metadata"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c, 0, 99.8)
		Gate.cancel(f.gate, c.key, 0.05, 99.85)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0 and not f.gate.gate.pending[c.key])
		Gate.tick(f.gate, 1, 100.8)
		assert(#f.rendered == 0)
	end,
	["prediction timeout drops metadata and capacity reopens without evicting live casts"] = function()
		local f = fixture(1)
		local a = acceptance()
		Store.predict(f.store, a.castId, a)
		Gate.predict(f.gate, a.castId, 0, 100)
		assert(Store.predict(f.store, "g:2", acceptance(2)) == "refuse")
		Gate.tick(f.gate, 1, 101)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0)
		assert(Store.predict(f.store, "g:2", acceptance(2)) == "stored")
	end,
	["identity conflicts never replace original generation character user or slot"] = function()
		for _, field in { "generation", "characterKey", "casterUserId", "slotRevision" } do
			local f = fixture()
			local a = acceptance()
			Store.predict(f.store, a.castId, a)
			local changed = table.clone(a)
			changed[field] = if type(a[field]) == "string" then "changed" else a[field] + 1
			assert(Store.predict(f.store, a.castId, changed) == "conflict")
			assert(Store.get(f.store, a.castId).identity[field] == a[field])
		end
	end,
	["gate destruction and registry destruction release references idempotently"] = function()
		local f = fixture()
		local c = f:command()
		f:accept(c)
		Gate.destroy(f.gate)
		Store.prune(f.store, f.gate)
		assert(f.store.count == 0)
		Store.destroy(f.store)
		Store.destroy(f.store)
		assert(Store.get(f.store, c.key) == nil and Store.accept(f.store, c) == "refuse")
	end,
	["invalid capacities and identity refuse without storage"] = function()
		for _, n in { 0, -1, 0.5, math.huge, 0 / 0 } do
			assert(not pcall(Store.new, n))
		end
		local s, a = Store.new(1), acceptance()
		a.slotRevision = 0 / 0
		assert(Store.predict(s, "g:1", a) == "refuse" and s.count == 0)
	end,
}
