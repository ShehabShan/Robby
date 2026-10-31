local W = require("../src/shared/WindStep")
local function eq(a: any, b: any)
	assert(a == b, `expected {tostring(b)}, got {tostring(a)}`)
end
local function near(a: number, b: number)
	assert(math.abs(a - b) < 1e-8, `expected {b}, got {a}`)
end
local function state()
	return assert(W.new(W.PROPOSED))
end
local function raw(key: string, value: any)
	local r = table.clone(W.PROPOSED)
	r[key] = value
	return r
end
return {
	["chosen integral and peak are explicit"] = function()
		local p = state().profile
		near(p.peak, 70)
		local d, v = W.sample(p, 0.16)
		near(d, 11.2)
		near(v, 70)
		d, v = W.sample(p, 0.20)
		near(d, 13.3)
		near(v, 35)
		d, v = W.sample(p, 0.24)
		near(d, 14)
		eq(v, 0)
	end,
	["profile is copied and frozen not a mutable alias"] = function()
		local r = table.clone(W.PROPOSED)
		local p = assert(W.profile(r))
		r.distance = 25
		eq(p.distance, 14)
		eq(table.isfrozen(p), true)
		eq(
			pcall(function()
				p.distance = 25
			end),
			false
		)
	end,
	["missing malformed nonfinite config never enters a controller"] = function()
		eq(W.profile(nil), nil)
		eq(W.profile(4), nil)
		eq(W.profile({}), nil)
		for _, k in { "distance", "duration", "brake", "iframes", "skin", "maxFrame" } do
			for _, v in { 0 / 0, math.huge, -math.huge, -1, "bad" } do
				eq(W.profile(raw(k, v)), nil)
			end
			eq(W.profile(raw(k, nil)), nil)
		end
	end,
	["configuration limits reject dangerous finite profiles"] = function()
		for _, pair in
			{
				{ "distance", 0 },
				{ "distance", 33 },
				{ "duration", 0.09 },
				{ "duration", 0.51 },
				{ "brake", 0 },
				{ "brake", 0.24 },
				{ "iframes", 0.25 },
				{ "skin", 1.1 },
				{ "maxFrame", 0 },
				{ "maxFrame", 0.25 },
			}
		do
			eq(W.profile(raw(pair[1], pair[2])), nil)
		end
		local r = raw("distance", 32)
		r.duration = 0.1
		r.brake = 0.08
		eq(W.profile(r), nil) -- finite but excessive peak
	end,
	["zero iframes and skin are valid explicit settings"] = function()
		assert(W.profile(raw("iframes", 0)))
		assert(W.profile(raw("skin", 0)))
	end,
	["movement beats facing in every cardinal and diagonal direction"] = function()
		for _, xy in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, -1 } } do
			local x, z, ok = W.direction(xy[1], xy[2], 0, -1)
			eq(ok, true)
			near(x * x + z * z, 1)
			local m = math.sqrt(xy[1] ^ 2 + xy[2] ^ 2)
			near(x, xy[1] / m)
			near(z, xy[2] / m)
		end
	end,
	["idle analog deadzone falls back to original facing"] = function()
		local x, z, ok = W.direction(0.01, 0.01, -2, 0)
		eq(ok, true)
		eq(x, -1)
		eq(z, 0)
		x, z, ok = W.direction(0.05, 0, 0, -1)
		eq(ok, true)
		eq(x, 1)
		eq(z, 0)
	end,
	["invalid directions fail closed and huge finite direction normalizes"] = function()
		for _, n in { 0 / 0, math.huge, -math.huge } do
			local _, _, ok = W.direction(n, 0, 1, 0)
			eq(ok, false)
			_, _, ok = W.direction(0, 0, n, 1)
			eq(ok, false)
		end
		local _, _, ok = W.direction(0, 0, 0, 0)
		eq(ok, false)
		local x, z, valid = W.direction(1e300, 1e300, 0, 0)
		eq(valid, true)
		near(x * x + z * z, 1)
	end,
	["air allowed but unsafe humanoid states rejected"] = function()
		for _, mode in { "Running", "RunningNoPhysics", "Landed", "Jumping", "Freefall" } do
			eq(W.eligible(100, false, false, mode), true)
		end
		for _, mode in { "Swimming", "Climbing", "Seated", "Dead", "Physics", "FallingDown", "Ragdoll", "unknown" } do
			eq(W.eligible(100, false, false, mode), false)
		end
		eq(W.eligible(100, true, false, "Running"), false)
		eq(W.eligible(100, false, true, "Running"), false)
		for _, hp in { 0, -1, 0 / 0, math.huge } do
			eq(W.eligible(hp, false, false, "Running"), false)
		end
	end,
	["sample before start and beyond end stays bounded"] = function()
		local p = state().profile
		local d, v = W.sample(p, -1)
		eq(d, 0)
		eq(v, 0)
		d, v = W.sample(p, 0)
		eq(d, 0)
		near(v, 70)
		d, v = W.sample(p, 10)
		near(d, 14)
		eq(v, 0)
		d, v = W.sample(p, 0 / 0)
		eq(d, 0)
		eq(v, 0)
	end,
	["normal frame partitions integrate to fourteen without overshoot"] = function()
		for _, hz in { 30, 60, 144 } do
			local s = state()
			local n = math.ceil(s.profile.duration * hz)
			for i = 1, n do
				local f = W.step(s, math.min(i / hz, s.profile.duration), nil, false)
				assert(f.distance >= 0 and f.speed <= 70 + 1e-8)
			end
			near(s.traveled, 14)
			eq(s.done, true)
			eq(s.reason, "complete")
		end
	end,
	["uneven small frames preserve integral"] = function()
		local s = state()
		for _, t in { 0.01, 0.04, 0.06, 0.10, 0.14, 0.18, 0.21, 0.24 } do
			W.step(s, t, nil, false)
		end
		near(s.traveled, 14)
	end,
	["hitch drops old distance and never catches up later"] = function()
		local s = state()
		local f = W.step(s, 0.10, nil, false)
		near(f.distance, 3.5)
		near(f.speed, 70)
		for _, t in { 0.14, 0.18, 0.21, 0.24 } do
			W.step(s, t, nil, false)
		end
		near(s.traveled, 10.5)
		f = W.step(s, 0.25, nil, false)
		eq(f.distance, 0)
		eq(f.speed, 0)
	end,
	["expired first callback does not replay motion"] = function()
		local s = state()
		local f = W.step(s, 1, nil, false)
		eq(f.distance, 0)
		eq(f.done, true)
		eq(s.traveled, 0)
	end,
	["collision keeps skin and stops permanently"] = function()
		local s = state()
		local f = W.step(s, 0.02, 1, false)
		near(f.distance, 0.85)
		near(f.speed, 42.5)
		eq(f.reason, "blocked")
		f = W.step(s, 0.04, nil, false)
		eq(f.distance, 0)
		near(s.traveled, 0.85)
	end,
	["initial overlap or inside skin ends without displacement"] = function()
		for _, clearance in { 0, 0.1, 0.15 } do
			local s = state()
			local f = W.step(s, 0, clearance, false)
			eq(f.distance, 0)
			eq(f.reason, "blocked")
		end
	end,
	["far obstacle does not truncate a clear frame"] = function()
		local s = state()
		local f = W.step(s, 0.02, 10, false)
		near(f.distance, 1.4)
		eq(f.done, false)
	end,
	["cancel and original death replacement end before any new displacement"] = function()
		local s = state()
		W.step(s, 0.01, nil, false)
		local f = W.step(s, 0.02, nil, true)
		eq(f.distance, 0)
		eq(f.reason, "cancelled")
		near(s.traveled, 0.7)
		W.stop(s, "later cleanup")
		eq(s.reason, "cancelled")
	end,
	["terminal reasons cannot be overwritten or restarted"] = function()
		local s = state()
		W.stop(s, "removed")
		local f = W.step(s, 0, nil, false)
		eq(f.reason, "removed")
		eq(f.distance, 0)
		eq(f.done, true)
	end,
	["clock reversal and nonfinite callbacks cancel"] = function()
		for _, now in { 0.01, -1, 0 / 0, math.huge } do
			local s = state()
			W.step(s, 0.02, nil, false)
			local f = W.step(s, now, nil, false)
			eq(f.reason, "invalid")
			eq(f.distance, 0)
		end
	end,
	["invalid clearance never turns into clear sky"] = function()
		for _, n in { -1, 0 / 0, math.huge } do
			local f = W.step(state(), 0.02, n, false)
			eq(f.reason, "invalid")
			eq(f.distance, 0)
		end
	end,
	["duplicate clock does not advance twice"] = function()
		local s = state()
		W.step(s, 0.02, nil, false)
		local f = W.step(s, 0.02, nil, false)
		eq(f.distance, 0)
		eq(f.speed, 0)
		eq(f.done, false)
		near(s.traveled, 1.4)
	end,
	["frame returned to engine is immutable"] = function()
		local f = W.step(state(), 0.02, nil, false)
		eq(table.isfrozen(f), true)
		eq(
			pcall(function()
				f.distance = 100
			end),
			false
		)
	end,
	["travel is bounded fail closed for invalid intervals"] = function()
		local p = state().profile
		for _, ab in { { -1, 0.1 }, { 0.2, 0.1 }, { 0, 1 }, { 0, 0 }, { 0, 0 / 0 } } do
			local d, t = W.travel(p, ab[1], ab[2])
			eq(d, 0)
			eq(t, 0)
		end
		local d, t = W.travel(p, 0, 0.1)
		near(d, 3.5)
		near(t, 0.05)
	end,
}
