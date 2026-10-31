local Dispatch = require("../src/shared/CastDeliveryDispatch")
local Inbox = require("../src/shared/CastInbox")
local Geometry = require("../src/shared/CastGeometry")
local Config = require("../src/shared/Config")
local Store = require("../src/shared/CastDeliveryStore")
local function acceptance(seq, at)
	at = at or 100
	return {
		castId = "g:" .. tostring(seq or 1),
		generation = "g",
		seq = seq or 1,
		casterUserId = 42,
		characterKey = "old",
		slotRevision = 4,
		moveId = "m",
		acceptedAt = at,
		releaseAt = at + 1,
		endsAt = at + 5,
		origin = { x = 2, y = 3, z = 4 },
		centre = { x = 5, y = 6, z = 7 },
		aim = { x = 0, y = 0, z = -1 },
		geometry = assert(Geometry.capture({ delivery = { kind = "Zone", params = { radius = 17, range = 40 } } }, {})),
	}
end
local function fixture(capacity, cursor, borrowed)
	local f = {
		inbox = borrowed or Inbox.new(Config.CastClientReceipt),
		frames = {},
		warnings = {},
		live = 0,
		tickets = {},
		fail = false,
		failReserve = false,
	}
	local policy = table.clone(Config.CastWarning)
	policy.presentation = table.clone(policy.presentation)
	policy.warning = table.clone(policy.warning)
	policy.presentation.capacity, policy.warning.capacity = capacity or 4, capacity or 4
	local function record(frame, entry, reserve)
		assert(entry, "metadata was not staged")
		if frame.timeline then
			assert(entry.accepted, "missing pinned acceptance")
		end
		table.insert(
			if reserve then f.warnings else f.frames,
			{ key = frame.key, now = frame.now, action = frame.action, entry = entry, pose = frame.poseAllowed }
		)
		if (reserve and f.failReserve) or (not reserve and f.fail) then
			return false
		end
		local id = (if reserve then "reserve:" else "primary:") .. frame.key
		local ticket = f.tickets[id]
		if ticket and frame.isCurrent(ticket) then
			return true
		end
		f.live += 1
		local dispose = function()
			f.live -= 1
			f.tickets[id] = nil
		end
		local ok
		if reserve then
			ok = frame.bind("world", dispose)
		else
			ok = frame.bind("world", "world", dispose)
		end
		f.tickets[id] = ok
		return ok ~= nil
	end
	f.state = Dispatch.new(f.inbox, { m = { delivery = "Zone", worldWarning = true } }, policy, function(frame, entry)
		return record(frame, entry, false)
	end, function(frame, entry)
		return record(frame, entry, true)
	end, cursor)
	function f:accept(seq, at, now)
		local a = acceptance(seq, at)
		assert(Inbox.accept(self.inbox, a, now or 0) == "stored")
		return a
	end
	function f:tick(t, server)
		return Dispatch.tick(self.state, t or 0, server or 100)
	end
	function f:stop()
		local token = Dispatch.destroy(self.state)
		assert(token and self.live == 0 and self.state.store.count == 0)
		return token
	end
	return f
end
return {
	["stages immutable metadata once and adopts an owned prediction"] = function()
		local f = fixture()
		assert(Dispatch.predict(f.state, "g:1", acceptance(), 0, 100) == "predict")
		f:accept()
		assert(f:tick())
		local entry = Store.get(f.state.store, "g:1")
		assert(entry and entry.accepted and f.frames[#f.frames].action == "adopt")
		local canonical = entry.accepted
		assert(f:tick(0.1, 100.1))
		assert(Store.get(f.state.store, "g:1").accepted == canonical)
		assert(f.frames[#f.frames].action == "seek")
		f:stop()
	end,
	["future queue drains with canonical metadata and one gate clock"] = function()
		local f = fixture()
		f:accept(1, 100.4)
		assert(f:tick() and #f.frames == 0 and f.state.gate.gate.count == 1)
		local canonical = Store.get(f.state.store, "g:1").accepted
		f:tick(0.5, 100.5)
		assert(#f.frames > 0 and f.frames[1].now == 100.5 and f.frames[1].entry.accepted == canonical)
		assert(f.state.gate.gate.count == 0)
		f:stop()
	end,
	["all due futures with same snapshot terminals cancel before any start"] = function()
		local f = fixture()
		f:accept(1, 100.4)
		f:accept(2, 100.4)
		f:tick()
		assert(f.state.gate.gate.count == 2)
		assert(Inbox.terminal(f.inbox, "g:1", "cancel", 100.4, 0.4) == "stored")
		assert(Inbox.terminal(f.inbox, "g:2", "cancel", 100.4, 0.4) == "stored")
		f:tick(0.4, 100.4)
		assert(#f.frames == 0 and #f.warnings == 0 and f.state.store.count == 0)
		f:stop()
	end,
	["all live terminals cancel before any primary seek or reserve seek"] = function()
		local f = fixture(1)
		f:accept(1)
		f:accept(2)
		f:tick()
		assert(f.live == 2 and #f.warnings > 0)
		local renders = #f.frames + #f.warnings
		Inbox.terminal(f.inbox, "g:1", "cancel", 101, 1)
		Inbox.terminal(f.inbox, "g:2", "cancel", 101, 1)
		f:tick(1, 101)
		assert(#f.frames + #f.warnings == renders and f.live == 0 and f.state.store.count == 0)
		f:stop()
	end,
	["terminal-before-acceptance never renders"] = function()
		local f = fixture()
		Inbox.terminal(f.inbox, "g:1", "cancel", 100, 0)
		assert(Inbox.accept(f.inbox, acceptance(), 0) == "terminal")
		f:tick()
		assert(#f.frames == 0)
		f:stop()
	end,
	["rejection cancels prediction before new predicted work"] = function()
		local f = fixture()
		Dispatch.predict(f.state, "g:1", acceptance(), 0, 100)
		Inbox.disposition(f.inbox, { generation = "g", seq = 1, moveId = "m", status = "rejected", reason = "cost" }, 0)
		Dispatch.predict(f.state, "g:2", acceptance(2), 0, 100)
		assert(Store.get(f.state.store, "g:1") == nil)
		assert(f.state.gate.gate.bridge.presentation.entries["g:1"].kind == "terminal")
		assert(Inbox.accept(f.inbox, acceptance(), 0) == "rejected")
		f:stop()
	end,
	["expired response does not cancel or block genuine late acceptance"] = function()
		local f = fixture()
		Dispatch.predict(f.state, "g:1", acceptance(), 0, 100)
		Inbox.disposition(f.inbox, { generation = "g", seq = 1, moveId = "m", status = "expired", reason = "old" }, 0)
		f:tick()
		assert(Store.get(f.state.store, "g:1"))
		f:accept()
		f:tick()
		assert(f.state.gate.gate.bridge.presentation.entries["g:1"].kind == "accepted")
		f:stop()
	end,
	["acceptance survives reordered disposition"] = function()
		local f = fixture()
		f:accept()
		assert(
			Inbox.disposition(
				f.inbox,
				{ generation = "g", seq = 1, moveId = "m", status = "rejected", reason = "cost" },
				0
			) == "accepted"
		)
		f:tick()
		assert(f.live == 1)
		f:stop()
	end,
	["prunes borrowed inbox before taking a snapshot"] = function()
		local f = fixture()
		f:accept()
		f:tick(11, 111)
		assert(next(f.inbox.acceptances.entries) == nil and #f.frames == 0 and f.state.receipts == 1)
		f:stop()
	end,
	["upstream eviction does not remove owned metadata or replay it"] = function()
		local f = fixture()
		f.inbox.acceptances.policy = table.clone(Config.CastClientReceipt)
		f.inbox.acceptances.policy.capacity = 1
		f:accept()
		f:tick()
		local original = Store.get(f.state.store, "g:1")
		f:accept(2)
		f:tick()
		assert(f.inbox.acceptances.entries["g:1"] == nil and Store.get(f.state.store, "g:1") == original)
		f:tick(5, 105)
		assert(f.live == 0 and f.state.store.count == 0)
		f:stop()
	end,
	["retired tombstone watermark cancels retained metadata after inbox eviction"] = function()
		local f = fixture()
		f.inbox.acceptances.policy = table.clone(Config.CastClientReceipt)
		f.inbox.acceptances.policy.capacity = 1
		f:accept()
		f:tick()
		Inbox.terminal(f.inbox, "g:1", "cancel", 100, 0)
		f:accept(2, 100.1)
		local count = #f.frames
		f:tick()
		assert(#f.frames == count and Store.get(f.state.store, "g:1") == nil and f.live == 0)
		f:stop()
	end,
	["pose retirement leaves accepted world hazards alive"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		assert(Dispatch.retirePose(f.state, "g:1", 0.1, 100.1))
		f:tick(0.2, 100.2)
		assert(f.live == 1 and f.frames[#f.frames].pose == false and Store.get(f.state.store, "g:1"))
		f:stop()
	end,
	["primary failure pins same metadata for reserve and reports degradation"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		local canonical = Store.get(f.state.store, "g:1").accepted
		f.fail = true
		f:tick(0.1, 100.1)
		assert(f.state.gate.fallbacks > 0 and f.live == 1 and f.warnings[#f.warnings].entry.accepted == canonical)
		f:stop()
	end,
	["both renderers failing prune metadata without claiming visible success"] = function()
		local f = fixture()
		f.fail, f.failReserve = true, true
		f:accept()
		assert(f:tick())
		assert(
			f.state.gate.fallbacks > 0
				and f.state.gate.reserve.bridge.renderFailures > 0
				and f.live == 0
				and f.state.store.count == 0
		)
		f:stop()
	end,
	["borrowed inbox shutdown fails closed without owning receipt destruction"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		Inbox.destroy(f.inbox)
		assert(not f:tick() and f.state.closed and f.live == 0)
		f:stop()
	end,
	["destroy leaves borrowed receipts usable and restart skips retained and unpolled records"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		f:accept(2)
		local token = f:stop()
		assert(not f.inbox.acceptances.closed)
		local g = fixture(nil, token, f.inbox)
		g:tick()
		assert(#g.frames == 0)
		g:accept(3, 100.1, 0.1)
		g:tick(0.1, 100.1)
		assert(g.live == 1)
		g:stop()
	end,
	["fresh inbox restart refuses old accepted timestamps"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		local token = f:stop()
		local g = fixture(nil, token)
		g:accept()
		g:tick()
		assert(#g.frames == 0)
		g:accept(2, 100.1, 0.1)
		g:tick(0.1, 100.1)
		assert(g.live == 1)
		g:stop()
	end,
	["bad clocks do not consume observation or mutate live resources"] = function()
		local f = fixture()
		f:accept()
		assert(not f:tick(0, 0 / 0) and f.state.receipts == 0 and f.live == 0)
		assert(f:tick() and f.live == 1)
		assert(not f:tick(-1, 100) and f.live == 1)
		f:stop()
	end,
	["clock jump is bounded and exact expiry removes all metadata"] = function()
		local f = fixture()
		f:accept()
		f:tick()
		f:tick(0.1, 999999)
		assert(f.state.gate.gate.now == 100.1 and f.live == 1)
		f:tick(5, 105)
		assert(f.live == 0 and f.state.store.count == 0)
		f:stop()
	end,
	["bounded overflow never accumulates an observed-key map"] = function()
		local f = fixture(1)
		for i = 1, 100 do
			f:accept(i)
		end
		f:tick()
		assert(f.state.receipts == 100 and f.state.store.count <= 2 and f.live <= 2)
		local renders = #f.frames + #f.warnings
		f:tick()
		assert(#f.frames + #f.warnings <= renders + 2)
		f:stop()
	end,
	["failed mapping is observed once without staging invalid metadata"] = function()
		local f = fixture()
		local a = acceptance()
		a.moveId = "unknown"
		assert(Inbox.accept(f.inbox, a, 0) == "stored")
		f:tick()
		assert(f.state.receipts == 1 and f.state.store.count == 0 and #f.frames == 0)
		f:stop()
	end,
}
