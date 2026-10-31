local V = require("../src/shared/WindStepVisual")
local function eq(a: any, b: any)
	assert(a == b, `expected {tostring(b)}, got {tostring(a)}`)
end
local function snap()
	return assert(V.snapshot({ version = 1, distance = 14, duration = 0.24, brake = 0.08, fade = 0.12 }))
end
return {
	["snapshot copied frozen versioned and bounded"] = function()
		local r = { version = 1, distance = 14, duration = 0.24, brake = 0.08, fade = 0.12 }
		local s = assert(V.snapshot(r))
		r.duration = 4
		eq(s.duration, 0.24)
		eq(table.isfrozen(s), true)
		for _, k in { "version", "distance", "duration", "brake", "fade" } do
			for _, n in { 0 / 0, math.huge, -1 } do
				local bad = table.clone(s)
				bad[k] = n
				eq(V.snapshot(bad), nil)
			end
		end
		r.version = 2
		eq(V.snapshot(r), nil)
		r = table.clone(s)
		r.fade = 0.121
		eq(V.snapshot(r), nil)
		eq(V.snapshot(nil), nil)
		eq(V.snapshot({}), nil)
	end,
	["prediction has only brief reversible outline"] = function()
		local f = V.predicted(0.03)
		eq(f.phase, "anticipation")
		assert(f.outline > 0)
		eq(#f.ribbons, 0)
		eq(#f.motes, 0)
		eq(f.arc, 0)
		for _, t in { -1, 0.06, 1, 0 / 0, math.huge } do
			eq(V.predicted(t).phase, "hidden")
		end
	end,
	["four accepted phases and expiration seek without restart"] = function()
		local s = snap()
		eq(V.sample(s, 0.01, 70, nil, false).phase, "launch")
		eq(V.sample(s, 0.1, 70, nil, false).phase, "travel")
		eq(V.sample(s, 0.2, 35, nil, false).phase, "brake")
		eq(V.sample(s, 0.3, 0, nil, false).phase, "fade")
		eq(V.sample(s, 0.36, 0, nil, false).phase, "hidden")
		eq(V.sample(s, 0.15, 70, nil, false).arc, 0)
	end,
	["observed movement controls ribbon not ideal fourteen stud displacement"] = function()
		local s = snap()
		eq(#V.sample(s, 0.1, 0, nil, false).ribbons, 0)
		eq(V.sample(s, 0.1, 35, nil, false).ribbons[1].length, 2.25)
		assert(V.sample(s, 0.1, 1e6, nil, false).ribbons[1].length <= 4.5)
	end,
	["contact stop shortens lifetime no launch restart"] = function()
		local s = snap()
		local f = V.sample(s, 0.03, 0, 0.02, false)
		eq(f.phase, "fade")
		eq(f.arc, 0)
		assert(f.ribbons[1].length < 0.8)
		eq(V.sample(s, 0.15, 0, 0.02, false).phase, "hidden")
	end,
	["invalid inputs hide not manufacture geometry"] = function()
		local s = snap()
		for _, n in { -1, 0 / 0, math.huge } do
			eq(V.sample(s, n, 70, nil, false).phase, "hidden")
			eq(V.sample(s, 0.1, n, nil, false).phase, "hidden")
			eq(V.sample(s, 0.1, 0, n, false).phase, "hidden")
		end
		eq(V.sample(s, 0.1, 0, 0.2, false).phase, "hidden")
		eq(V.sample(s, 0.4, 0, 0.3, false).phase, "hidden")
	end,
	["fixed budget and reduced mode preserves two directional ribbons"] = function()
		local s = snap()
		for i = 0, 50 do
			local f = V.sample(s, i / 100, 70, nil, false)
			assert(#f.ribbons <= 2 and #f.motes <= 6 and f.arc <= 1)
			for _, r in f.ribbons do
				assert(r.length <= 4.5 and r.width <= 0.32 and r.opacity <= 0.85)
			end
			for _, m in f.motes do
				assert(m.behind <= 4.5 and m.size <= 0.08 and m.opacity <= 0.85)
			end
		end
		local f = V.sample(s, 0.1, 70, nil, true)
		eq(#f.ribbons, 2)
		eq(#f.motes, 0)
		eq(f.ribbons[1].side, -1)
		eq(f.ribbons[2].side, 1)
	end,
	["frames deeply immutable and independent"] = function()
		local f = V.sample(snap(), 0.1, 70, nil, false)
		eq(table.isfrozen(f), true)
		eq(table.isfrozen(f.ribbons), true)
		eq(table.isfrozen(f.motes), true)
		eq(
			pcall(function()
				f.ribbons[1].length = 90
			end),
			false
		)
		eq(
			pcall(function()
				f.motes[1].size = 90
			end),
			false
		)
	end,
	["deterministic seeking same timestamp no random state"] = function()
		local s = snap()
		local a = V.sample(s, 0.12, 45, nil, false)
		V.sample(s, 0.31, 0, nil, false)
		local b = V.sample(s, 0.12, 45, nil, false)
		for i, m in a.motes do
			eq(m.behind, b.motes[i].behind)
			eq(m.opacity, b.motes[i].opacity)
		end
		eq(a.ribbons[1].length, b.ribbons[1].length)
	end,
	["fade shrinks to nothing without exceeding its bound"] = function()
		local s = snap()
		local a = V.sample(s, 0.25, 70, nil, false)
		local b = V.sample(s, 0.35, 70, nil, false)
		assert(b.ribbons[1].length < a.ribbons[1].length and b.ribbons[1].opacity < a.ribbons[1].opacity)
		eq(#V.sample(s, 10, 70, nil, false).ribbons, 0)
	end,
}
