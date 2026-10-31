local W = require("../src/shared/CastWarningReserve")
local B = require("../src/shared/CastBridge")
local function timeline(at)
	return { acceptedAt = at, releaseAt = at + 0.5, endsAt = at + 2, x = 1, y = 2, z = 3 }
end
local function policy(capacity)
	return { capacity = capacity or 4, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 }
end
local function setup(capacity, mode)
	local f = { frames = {}, tickets = {}, cleaned = 0 }
	local w = W.new(policy(capacity), 1, function(frame)
		table.insert(f.frames, frame)
		if frame.action == "start" then
			local ticket = frame.bind("warning", function()
				f.cleaned += 1
				if mode == "bad-dispose" then
					error("disposal failure")
				end
			end)
			table.insert(f.tickets, ticket)
		end
		if mode == "throw" then
			error("renderer failure")
		end
		return mode ~= "false" and not (mode == "seek-fail" and frame.action == "seek")
	end)
	return w, f
end
return {
	["reserve has separate capacity from exhausted normal resources"] = function()
		local normal = B.new(policy(1), 1, function()
			return true
		end)
		assert(B.accept(normal, "normal", timeline(0), 0) == "start")
		assert(B.accept(normal, "fallback", timeline(0), 0) == "refuse")
		local w, f = setup(1)
		assert(W.accept(w, "fallback", timeline(0), 0) == "start")
		assert(normal.resources.count == 1 and w.bridge.resources.count == 1)
		assert(W.accept(w, "overflow", timeline(0), 0) == "refuse")
		assert(w.refusals == 1 and #f.frames == 1 and f.cleaned == 0)
		W.destroy(w)
		B.destroy(normal)
	end,
	["warning preserves accepted centre and duplicate does not restart or extend"] = function()
		local w, f = setup()
		local t = timeline(0)
		W.accept(w, "a", t, 0)
		t.x = 99
		t.endsAt = 9
		assert(W.accept(w, "a", t, 0.2) == "ignore")
		assert(#f.frames == 1 and f.frames[1].timeline.x == 1)
		W.tick(w, 0.25)
		assert(f.frames[2].phase == "warning" and f.frames[2].progress == 0.5)
		W.tick(w, 2)
		assert(f.cleaned == 1 and w.bridge.resources.count == 0)
	end,
	["active world hazard is not a hit or a pose"] = function()
		local w, f = setup()
		W.accept(w, "late", timeline(0), 1)
		local frame = f.frames[1]
		assert(frame.phase == "active" and frame.action == "start")
		assert(frame.poseAllowed == nil and frame.lease == nil)
		assert(B.retirePose(w.bridge, "late", 1.1))
		assert(f.cleaned == 0)
		W.tick(w, 1.5)
		assert(#f.frames == 2 and f.frames[2].action == "seek")
		W.tick(w, 2)
		assert(f.cleaned == 1)
	end,
	["rejection before acceptance suppresses late warning"] = function()
		local w, f = setup()
		W.cancel(w, "a", 0)
		assert(W.accept(w, "a", timeline(0), 0.1) == "ignore")
		assert(#f.frames == 0)
	end,
	["terminal disposes once and never restarts"] = function()
		local w, f = setup()
		W.accept(w, "a", timeline(0), 0)
		W.cancel(w, "a", 0.1)
		W.cancel(w, "a", 0.2)
		assert(f.cleaned == 1)
		assert(W.accept(w, "a", timeline(0), 0.3) == "ignore")
		assert(not f.frames[1].isCurrent(f.tickets[1]))
		W.destroy(w)
		assert(f.cleaned == 1)
	end,
	["invalid future expired and backwards offers never create warnings"] = function()
		local w, f = setup()
		assert(W.accept(w, "future", timeline(1), 0) == "refuse")
		local bad = timeline(0)
		bad.x = 0 / 0
		assert(W.accept(w, "bad", bad, 0) == "refuse")
		assert(W.accept(w, "old", timeline(-3), 0) == "ignore")
		assert(W.accept(w, "back", timeline(-1), -1) == "refuse")
		assert(#f.frames == 0)
	end,
	["partial renderer false and throw dispose every allocation and tombstone"] = function()
		for _, mode in { "false", "throw" } do
			local w, f = setup(4, mode)
			assert(W.accept(w, "a", timeline(0), 0) == "failed")
			assert(f.cleaned == 1 and w.bridge.renderFailures == 1)
			assert(w.bridge.resources.count == 0)
			assert(W.accept(w, "a", timeline(0), 0.1) == "ignore")
			assert(#f.frames == 1)
		end
	end,
	["seek failure is observable and clears remaining warning"] = function()
		local w, f = setup(4, "seek-fail")
		W.accept(w, "a", timeline(0), 0)
		assert(not W.tick(w, 0.2))
		assert(w.bridge.renderFailures == 1 and f.cleaned == 1)
		W.tick(w, 0.3)
		assert(#f.frames == 2)
	end,
	["idle tick expires without packets and stale callback cannot release new lease"] = function()
		local w, f = setup()
		W.accept(w, "a", timeline(0), 0)
		local old, ticket = f.frames[1], f.tickets[1]
		W.tick(w, 2)
		W.tick(w, 14)
		assert(W.accept(w, "a", timeline(14), 14) == "start")
		assert(not old.isCurrent(ticket) and not old.release(ticket))
		assert(not old.release(f.tickets[2]))
		assert(w.bridge.resources.count == 1 and f.cleaned == 1)
		W.destroy(w)
		assert(f.cleaned == 2)
	end,
	["overflow cancellation watermark prevents resurrection once room frees"] = function()
		local w, f = setup(1)
		W.accept(w, "a", timeline(0), 0)
		assert(W.cancel(w, "lost", 0.1) == "refuse")
		W.tick(w, 2)
		W.tick(w, 14)
		assert(W.accept(w, "lost", timeline(0), 14) == "ignore")
		assert(W.accept(w, "fresh", timeline(14), 14) == "start")
		assert(#f.frames == 2)
	end,
	["per warning allocation limit disposes refused resources immediately"] = function()
		local disposed = 0
		local w = W.new(policy(), 1, function(frame)
			assert(frame.bind("one", function()
				disposed += 1
			end))
			assert(not frame.bind("two", function()
				disposed += 1
			end))
			return true
		end)
		W.accept(w, "a", timeline(0), 0)
		assert(disposed == 1 and w.bridge.resourceRefusals == 1)
		W.destroy(w)
		assert(disposed == 2)
	end,
	["teardown is idempotent even with throwing disposer"] = function()
		local w, f = setup(4, "bad-dispose")
		W.accept(w, "a", timeline(0), 0)
		assert(W.destroy(w) and W.destroy(w))
		assert(f.cleaned == 1 and w.bridge.resources.cleanupFailures == 1)
		assert(W.accept(w, "new", timeline(1), 1) == "refuse")
		assert(not W.tick(w, 1) and next(w.bridge.leases) == nil)
	end,
	["reentrant mutation refuses and teardown can be retried by owner"] = function()
		local w
		w = W.new(policy(), 1, function()
			assert(not W.destroy(w))
			assert(W.cancel(w, "a", 0) == "refuse")
			return true
		end)
		assert(W.accept(w, "a", timeline(0), 0) == "start")
		assert(W.destroy(w))
	end,
	["thousand warning lifecycles leave bounded state"] = function()
		local w, f = setup(2)
		for i = 1, 1000 do
			local at = i * 20
			assert(W.accept(w, tostring(i), timeline(at), at) == "start")
			if i % 2 == 0 then
				W.cancel(w, tostring(i), at + 1)
			end
			W.tick(w, at + 3)
			assert(w.bridge.resources.count == 0 and next(w.bridge.leases) == nil)
			local n = 0
			for _ in w.bridge.presentation.entries do
				n += 1
			end
			assert(n == 1)
		end
		assert(f.cleaned == 1000)
		W.destroy(w)
		assert(next(w.bridge.presentation.entries) == nil)
	end,
}
