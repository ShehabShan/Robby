local Volley = require("../src/shared/Deliveries/Volley")
local Zone = require("../src/shared/Deliveries/Zone")
local Burst = require("../src/shared/Deliveries/Burst")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end
local function near(a: number, b: number, msg: string?)
	if math.abs(a - b) > 1e-6 then
		error(`{msg or "value"}: expected ~{b}, got {a}`, 2)
	end
end

local V = { count = 5, spreadDeg = 30, perTargetCap = 2, speed = 100, range = 35, maxHits = 1 }
local Z = { radius = 7, range = 40, delay = 0.6, ticks = 4, duration = 1.0 }
local B = { radius = 25, maxTargets = 8 }

return {
	["volley: params and fan directions"] = function()
		eq(Volley.validParams(V), true)
		eq(
			Volley.validParams({ count = 0, spreadDeg = 30, perTargetCap = 1, speed = 1, range = 1, maxHits = 1 }),
			false
		)
		local dirs = Volley.directions(1, 0, V)
		eq(#dirs, 5)
		near(dirs[3].x, 1, "centre shard on aim")
		near(dirs[3].z, 0)
		near(math.deg(math.atan2(dirs[1].z, dirs[1].x)), -15, "edge at −15°")
		near(math.deg(math.atan2(dirs[5].z, dirs[5].x)), 15, "edge at +15°")
		eq(#Volley.directions(0, 0, V), 0, "no aim → no shards")
	end,
	["volley: per-target cap across shards"] = function()
		local s = Volley.new(V)
		eq(Volley.registerHit(s, 1, "boar", V), true)
		eq(Volley.registerHit(s, 1, "boar", V), false, "shard spent (maxHits 1)")
		eq(Volley.registerHit(s, 2, "boar", V), true)
		eq(Volley.registerHit(s, 3, "boar", V), false, "cap 2 per target")
		eq(Volley.registerHit(s, 3, "fang", V), true, "other target fine")
		eq(Volley.step(s, 1, V), 0, "all shards done after 1 s at speed 100 / range 35")
	end,
	["zone: aim point and tick schedule"] = function()
		eq(Zone.validParams(Z), true)
		eq(Zone.isValidPoint(0, 0, 30, 20, Z), true)
		eq(Zone.isValidPoint(0, 0, 30, 30, Z), false, "beyond 40")
		eq(Zone.isValidPoint(0, 0, 0 / 0, 0, Z), false, "NaN")
		local s = Zone.new(10)
		near(Zone.telegraph(s, 10.3, Z), 0.5, "half way through telegraph")
		eq(Zone.step(s, 10.5, Z), 0, "nothing before delay")
		eq(Zone.step(s, 10.6, Z), 1, "first tick at delay")
		eq(Zone.step(s, 11.0, Z), 1, "second tick at 0.933")
		eq(Zone.step(s, 12.0, Z), 2, "remaining ticks")
		eq(s.done, true)
		eq(Zone.step(s, 13, Z), 0, "finished")
		eq(Zone.contains(0, 0, 5, 4, Z), true)
		eq(Zone.contains(0, 0, 7, 1, Z), false)
	end,
	["burst: only marked targets in radius, nearest first, capped"] = function()
		eq(Burst.validParams(B), true)
		local picked = Burst.select(0, 0, {
			{ id = "far", x = 30, z = 0, marks = 3 },
			{ id = "cold", x = 10, z = 0, marks = 1 },
			{ id = "warm", x = 5, z = 0, marks = 0 },
			{ id = "colder", x = 3, z = 4, marks = 3 },
		}, B)
		eq(#picked, 2)
		eq(picked[1].id, "colder", "nearest first")
		eq(picked[2].id, "cold")
		eq(
			#Burst.select(
				0,
				0,
				{ { id = "a", x = 1, z = 0, marks = 1 }, { id = "b", x = 2, z = 0, marks = 1 } },
				{ radius = 25, maxTargets = 1 }
			),
			1,
			"cap"
		)
	end,
}
