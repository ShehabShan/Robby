local P = require("../src/shared/CastPresentation")
local function fresh(capacity)
	return P.new({ capacity = capacity or 8, predictionSeconds = 0.5, tombstoneSeconds = 3, maxLifetimeSeconds = 3 })
end
local function timeline()
	return { acceptedAt = 10, releaseAt = 10.6, endsAt = 11.6, x = 4, y = 0, z = 8 }
end
local function eq(a, b)
	assert(a == b, `expected {tostring(b)}, got {tostring(a)}`)
end
return {
	["overflow cancellation suppresses delayed resurrection with bounded watermark"] = function()
		local s = fresh(1)
		P.predict(s, "g:1", 10)
		eq(P.cancel(s, "g:2", 10.1).action, "refuse")
		P.tick(s, 10.5)
		eq(P.accept(s, "g:2", timeline(), 10.7).action, "ignore")
		eq(next(s.entries), nil)
	end,
	["lifetime bound prevents valid acceptance outliving cancel tombstone"] = function()
		local s = fresh()
		local t = timeline()
		t.endsAt = 14
		eq(P.accept(s, "g:1", t, 10).action, "refuse")
		t = timeline()
		eq(P.accept(s, "g:1", t, 9).action, "refuse")
	end,
	["destroyed reducer refuses reuse"] = function()
		local s = fresh()
		P.destroy(s)
		eq(P.predict(s, "g:1", 10).action, "refuse")
		eq(P.accept(s, "g:1", timeline(), 10).action, "refuse")
	end,
	["prediction adopts accepted centre without double start"] = function()
		local s = fresh()
		eq(P.predict(s, "g:1", 10).action, "predict")
		eq(P.predict(s, "g:1", 10).action, "ignore")
		local t = timeline()
		local r = P.accept(s, "g:1", t, 10.1)
		eq(r.action, "adopt")
		eq(r.timeline.y, 0)
		t.y = 100
		eq(r.timeline.y, 0)
		assert(table.isfrozen(r.timeline))
		eq(P.accept(s, "g:1", t, 10.2).action, "ignore")
	end,
	["observer starts once and seeks remaining phase"] = function()
		local s = fresh()
		eq(P.accept(s, "g:1", timeline(), 10.9).action, "start")
		local phase, fraction = P.phase(timeline(), 10.9)
		eq(phase, "active")
		assert(math.abs(fraction - 0.3) < 1e-6)
		eq(P.accept(s, "g:1", timeline(), 11).action, "ignore")
	end,
	["timeout clears prediction but late acceptance may start remaining phase"] = function()
		local s = fresh()
		P.predict(s, "g:1", 10)
		eq(#P.tick(s, 10.49), 0)
		eq(#P.tick(s, 10.5), 1)
		eq(P.accept(s, "g:1", timeline(), 10.9).action, "start")
	end,
	["reject prediction clears once and ignores late acceptance"] = function()
		local s = fresh()
		P.predict(s, "g:1", 10)
		eq(P.cancel(s, "g:1", 10.1).action, "clear")
		eq(P.cancel(s, "g:1", 10.2).action, "ignore")
		eq(P.accept(s, "g:1", timeline(), 10.3).action, "ignore")
		eq(#P.tick(s, 13.1), 0)
		eq(s.entries["g:1"], nil)
	end,
	["cancel before accept prevents resurrection"] = function()
		local s = fresh()
		eq(P.cancel(s, "g:1", 10).action, "ignore")
		eq(P.accept(s, "g:1", timeline(), 10.1).action, "ignore")
		eq(P.predict(s, "g:1", 10.2).action, "ignore")
	end,
	["accepted expiry clears once then retains bounded tombstone"] = function()
		local s = fresh()
		P.accept(s, "g:1", timeline(), 10)
		eq(#P.tick(s, 11.59), 0)
		eq(#P.tick(s, 11.6), 1)
		eq(#P.tick(s, 11.7), 0)
		eq(s.entries["g:1"].kind, "terminal")
		P.tick(s, 14.6)
		eq(s.entries["g:1"], nil)
		eq(P.accept(s, "g:1", timeline(), 14.7).action, "ignore") -- already expired even after TTL
	end,
	["late expired acceptance clears prediction without a flash"] = function()
		local s = fresh()
		P.predict(s, "g:1", 11.4)
		eq(P.accept(s, "g:1", timeline(), 11.7).action, "clear")
		eq(P.accept(s, "g:2", timeline(), 11.7).action, "ignore")
	end,
	["capacity refuses newcomers rather than dropping active telegraphs"] = function()
		local s = fresh(1)
		P.accept(s, "g:1", timeline(), 10)
		eq(P.predict(s, "g:2", 10.1).action, "refuse")
		eq(P.accept(s, "g:2", timeline(), 10.1).action, "refuse")
		eq(P.cancel(s, "g:2", 10.1).action, "refuse")
		eq(s.entries["g:1"].kind, "accepted")
		eq(P.cancel(s, "g:1", 10.2).action, "clear")
		P.tick(s, 13.2)
		eq(P.predict(s, "g:2", 13.2).action, "predict")
	end,
	["destroy emits cleanup for all active owners but not tombstones"] = function()
		local s = fresh()
		P.predict(s, "g:1", 10)
		P.accept(s, "g:2", timeline(), 10)
		P.cancel(s, "g:3", 10)
		eq(#P.destroy(s), 2)
		eq(next(s.entries), nil)
	end,
	["phase boundaries avoid divisions by zero and old impact replay"] = function()
		local t = timeline()
		eq(P.phase(t, 9), "waiting")
		eq(P.phase(t, 10), "warning")
		eq(P.phase(t, 10.6), "active")
		eq(P.phase(t, 11.6), "expired")
		t.releaseAt = t.acceptedAt
		eq(P.phase(t, 10), "active")
		t.endsAt = t.acceptedAt
		eq(P.phase(t, 10), "expired")
	end,
	["bad clocks or nonfinite coordinates cannot create active entries"] = function()
		local s = fresh()
		P.tick(s, 10)
		for _, bad in { 9, math.huge, 0 / 0 } do
			eq(P.predict(s, "g:1", bad).action, "refuse")
			eq(P.accept(s, "g:1", timeline(), bad).action, "refuse")
			eq(P.cancel(s, "g:1", bad).action, "refuse")
			eq(P.tick(s, bad), nil)
		end
		local t = timeline()
		t.y = 0 / 0
		eq(P.accept(s, "g:1", t, 10).action, "refuse")
		eq(P.phase(t, 10), "invalid")
		t = timeline()
		t.releaseAt = 12
		eq(P.accept(s, "g:1", t, 10).action, "refuse")
		eq(next(s.entries), nil)
	end,
}
