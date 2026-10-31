local W = require("../src/shared/CastWarningGate")
local B = require("../src/shared/CastBridge")
local Config = require("../src/shared/Config")
local function timeline(at)
	return { acceptedAt = at, releaseAt = at + 0.5, endsAt = at + 2, x = 1, y = 2, z = 3 }
end
local function policy(capacity, warnings)
	return {
		presentation = {
			capacity = capacity or 4,
			predictionSeconds = 1,
			tombstoneSeconds = 12,
			maxLifetimeSeconds = 10,
		},
		perCast = 2,
		clock = {
			pendingCapacity = 2,
			futureSeconds = 0.5,
			maxWaitSeconds = 2,
			maxSampleError = 1,
			correctionPerSecond = 0.25,
		},
		warning = { capacity = warnings or 2, predictionSeconds = 1, tombstoneSeconds = 12, maxLifetimeSeconds = 10 },
		warningPerCast = 1,
	}
end
local function setup(mode, capacity, warnings)
	local f = { normal = {}, warnings = {}, clean = 0, warningClean = 0, failSeek = false }
	local s = W.new(policy(capacity, warnings), function(frame)
		table.insert(f.normal, frame)
		if frame.action == "start" or frame.action == "predict" then
			frame.bind("normal", "world", function()
				f.clean += 1
			end)
		end
		if mode == "throw" then
			error("normal failed")
		end
		return mode ~= "fail" and not (f.failSeek and frame.action == "seek")
	end, function(frame)
		table.insert(f.warnings, frame)
		if frame.action == "start" then
			frame.bind("warning", function()
				f.warningClean += 1
			end)
		end
		return mode ~= "both-fail"
	end)
	return s, f
end
local function starts(frames)
	local n = 0
	for _, frame in frames do
		if frame.action == "start" then
			n += 1
		end
	end
	return n
end
return {
	["acceptance after failed prediction starts fresh primary resources"] = function()
		local actions = {}
		local cleaned = 0
		local s = W.new(policy(), function(frame)
			table.insert(actions, frame.action)
			if frame.action == "predict" then
				return false
			end
			if frame.action == "start" then
				frame.bind("new", "world", function()
					cleaned += 1
				end)
			end
			return true
		end, function()
			error("healthy start must not fall back")
		end)
		W.predict(s, "a", 0, 100)
		assert(W.accept(s, "a", timeline(100.1), 0.1, 100.1) == "start")
		assert(actions[1] == "predict" and actions[2] == "start")
		assert(s.gate.bridge.resources.count == 1 and s.fallbacks == 0)
		W.destroy(s)
		assert(cleaned == 1)
	end,
	["failed prediction still admits a later accepted essential cue"] = function()
		local s, f = setup("fail")
		assert(W.predict(s, "a", 0, 100) == "failed")
		assert(s.gate.bridge.presentation.entries.a.kind == "predicted")
		assert(#f.warnings == 0)
		assert(W.accept(s, "a", timeline(100.1), 0.1, 100.1) == "failed")
		assert(starts(f.warnings) == 1 and s.fallbacks == 1)
	end,
	["healthy primary cancellations never spend reserve capacity"] = function()
		local s, f = setup(nil, 1, 1)
		W.cancel(s, "rejected", 0, 100)
		assert(next(s.reserve.bridge.presentation.entries) == nil)
		assert(W.accept(s, "fallback", timeline(100.1), 0.1, 100.1) == "refuse")
		assert(starts(f.warnings) == 1 and s.reserve.refusals == 0)
	end,
	["cancelling one future cue preserves a different due failure warning"] = function()
		local s, f = setup("fail")
		W.accept(s, "a", timeline(100.2), 0, 100)
		W.accept(s, "b", timeline(100.2), 0, 100)
		W.cancel(s, "a", 0.2, 100.2)
		assert(starts(f.warnings) == 1 and f.warnings[1].key == "b")
		assert(s.reserve.bridge.resources.count == 1)
	end,
	["immediate false and throw route immutable canonical warning after primary cleanup"] = function()
		for _, mode in { "fail", "throw" } do
			local s, f = setup(mode)
			local t = timeline(100)
			assert(W.accept(s, "a", t, 0, 100) == "failed")
			t.x = 99
			assert(f.clean == 1 and starts(f.warnings) == 1)
			assert(f.warnings[1].timeline.x == 1 and s.fallbacks == 1)
			assert(s.gate.bridge.resources.count == 0 and s.reserve.bridge.resources.count == 1)
			W.accept(s, "a", t, 0.1, 100.1)
			assert(starts(f.warnings) == 1 and starts(f.normal) == 1)
		end
	end,
	["future queue drain failure reaches reserve without another accept call"] = function()
		local s, f = setup("fail")
		assert(W.accept(s, "a", timeline(100.2), 0, 100) == "queued")
		assert(#f.warnings == 0)
		W.tick(s, 0.25, 100.25)
		assert(starts(f.warnings) == 1 and f.warnings[1].phase == "warning")
		assert(s.gate.count == 0 and s.fallbacks == 1)
	end,
	["later seek failure routes remaining active hazard never contact"] = function()
		local s, f = setup()
		W.accept(s, "a", timeline(100), 0, 100)
		f.failSeek = true
		assert(W.tick(s, 1, 101))
		assert(starts(f.warnings) == 1 and f.warnings[1].phase == "active")
		assert(s.gate.bridge.renderFailures == 1 and f.clean == 1)
		W.tick(s, 2, 102)
		assert(f.warningClean == 1 and s.reserve.bridge.resources.count == 0)
	end,
	["normal full uses reserve and recovered capacity cannot duplicate it"] = function()
		local s, f = setup(nil, 1)
		W.predict(s, "occupier", 0, 100)
		assert(W.accept(s, "a", timeline(100), 0, 100) == "refuse")
		assert(starts(f.warnings) == 1)
		W.tick(s, 1.1, 101.1)
		assert(W.accept(s, "a", timeline(100), 1.2, 101.2) == "ignore")
		assert(starts(f.normal) == 0 and starts(f.warnings) == 1)
		assert(W.predict(s, "a", 1.3, 101.3) == "ignore")
	end,
	["reserve overflow reports refusal without evicting existing warning"] = function()
		local s, f = setup("fail", 4, 1)
		W.accept(s, "a", timeline(100), 0, 100)
		W.accept(s, "b", timeline(100), 0, 100)
		assert(s.fallbacks == 2 and s.reserve.refusals == 1)
		assert(starts(f.warnings) == 1 and f.warningClean == 0)
		assert(s.reserve.bridge.resources.count == 1)
	end,
	["cancel before acceptance and at queue readiness never flashes reserve"] = function()
		for _, queued in { false, true } do
			local s, f = setup("fail")
			if queued then
				W.accept(s, "a", timeline(100.2), 0, 100)
			end
			W.cancel(s, "a", 0.2, 100.2)
			W.accept(s, "a", timeline(100.2), 0.3, 100.3)
			assert(starts(f.warnings) == 0 and starts(f.normal) == 0)
		end
	end,
	["terminal arriving on failing seek suppresses fallback before cleanup"] = function()
		local s, f = setup()
		W.accept(s, "a", timeline(100), 0, 100)
		f.failSeek = true
		W.cancel(s, "a", 0.2, 100.2)
		assert(starts(f.warnings) == 0 and s.fallbacks == 0)
		assert(f.clean == 1)
	end,
	["cancel active fallback cleans exactly once and leaves siblings"] = function()
		local s, f = setup("fail")
		W.accept(s, "a", timeline(100), 0, 100)
		W.accept(s, "b", timeline(100), 0, 100)
		W.cancel(s, "a", 0.2, 100.2)
		W.cancel(s, "a", 0.3, 100.3)
		assert(f.warningClean == 1 and s.reserve.bridge.resources.count == 1)
		W.destroy(s)
		assert(f.warningClean == 2)
	end,
	["invalid expired out-of-range and prediction-only offers do not fall back"] = function()
		local s, f = setup("fail")
		W.predict(s, "pred", 0, 100)
		local bad = timeline(100)
		bad.x = 0 / 0
		W.accept(s, "bad", bad, 0, 100)
		W.accept(s, "expired", timeline(90), 0, 100)
		W.accept(s, "future", timeline(110), 0, 100)
		W.accept(s, "backwards", timeline(99), -1, 99)
		assert(#f.warnings == 0 and s.fallbacks == 0)
	end,
	["queued expiry does not create old warning"] = function()
		local s, f = setup("fail")
		W.accept(s, "a", timeline(100.2), 0, 100)
		W.tick(s, 3, 103)
		assert(s.gate.expired == 1 and #f.warnings == 0 and #f.normal == 0)
	end,
	["pose retirement and bad server sample preserve world until monotonic expiry"] = function()
		local s, f = setup("fail")
		W.accept(s, "a", timeline(100), 0, 100)
		W.retirePose(s, "a", 0.1, 100.1)
		assert(f.warningClean == 0)
		W.tick(s, 2, 0 / 0)
		assert(f.warningClean == 1 and s.gate.badSamples == 1)
	end,
	["fallback renderer failure is not reported as successful visible cue"] = function()
		local s, f = setup("both-fail", 1)
		W.predict(s, "full", 0, 100)
		W.accept(s, "a", timeline(100), 0, 100)
		assert(s.reserve.bridge.renderFailures == 1 and f.warningClean == 1)
		W.tick(s, 1.1, 101.1)
		assert(W.accept(s, "a", timeline(100), 1.2, 101.2) == "ignore")
		assert(starts(f.warnings) == 1 and starts(f.normal) == 0)
	end,
	["teardown clears normal fallback and queued ownership and rejects reentry"] = function()
		local s, f = setup(nil, 1)
		W.accept(s, "normal", timeline(100), 0, 100)
		W.accept(s, "fallback", timeline(100), 0, 100)
		W.accept(s, "queued", timeline(100.2), 0, 100)
		assert(W.destroy(s) and W.destroy(s))
		assert(f.clean == 1 and f.warningClean == 1 and s.gate.count == 0)
		assert(W.accept(s, "new", timeline(100), 0, 100) == "refuse")
		assert(not W.tick(s, 1, 101))
	end,
	["renderer reentry cannot mutate wrapper or tear down sibling pool"] = function()
		local s
		s = W.new(policy(), function()
			return false
		end, function(frame)
			assert(W.cancel(s, frame.key, 0, 100) == "refuse")
			assert(not W.destroy(s))
			return true
		end)
		W.accept(s, "a", timeline(100), 0, 100)
		assert(not s.closed and s.refusals >= 2)
		assert(W.destroy(s))
	end,
	["bridge failure hook exception is counted and cannot strand busy state"] = function()
		local b = B.new(policy().presentation, 1, function()
			return false
		end, function()
			error("hook")
		end)
		assert(B.accept(b, "a", timeline(0), 0) == "failed")
		assert(b.callbackFailures == 1 and not b.busy and b.resources.count == 0)
		assert(B.destroy(b))
	end,
	["production budgets cover receipt and future lifetimes without changing gameplay"] = function()
		local p = Config.CastWarning
		assert(p.presentation.maxLifetimeSeconds >= Config.CastClientReceipt.maxLifetimeSeconds)
		assert(p.presentation.tombstoneSeconds >= p.presentation.maxLifetimeSeconds + p.clock.futureSeconds)
		assert(p.warning.capacity < p.presentation.capacity and p.warningPerCast <= p.perCast)
		assert(p.warning.tombstoneSeconds >= p.presentation.tombstoneSeconds)
		local s = W.new(p, function()
			return true
		end, function()
			return true
		end)
		W.destroy(s)
	end,
	["thousand degraded cast lifecycles stay bounded and cleanup without packets"] = function()
		local s, f = setup("fail")
		for i = 1, 1000 do
			local at = i * 20
			W.accept(s, tostring(i), timeline(at), at, at)
			W.tick(s, at + 3, at + 3)
			assert(s.gate.bridge.resources.count == 0 and s.reserve.bridge.resources.count == 0)
			local n = 0
			for _ in s.reserve.bridge.presentation.entries do
				n += 1
			end
			assert(n == 1)
		end
		assert(f.warningClean == 1000 and s.fallbacks == 1000)
		W.destroy(s)
	end,
}
