-- T-043c1: deterministic characterization of REAL source slices, not a replacement implementation.
-- Lune-only (excluded from cloud specs). Default asserts today's defects; --contract intentionally fails
-- until c2/c3 land. Remove/update these characterization assertions when implementing those fixes.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local process = require("@lune/process")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Zone = require("../src/shared/Deliveries/Zone")
local Fx = require("../src/shared/FxRegistry")
local V = rb.Vector3
local built = Registry.build(All.content(Config))
local fan = built.moves["move.rime.shard_fan"]
local fall = built.moves["move.rime.fall"]
local finisher = built.moves["move.rime.needle_finisher"]

local function eq(a, b, message)
	assert(a == b, `{message}: expected {tostring(b)}, got {tostring(a)}`)
end
local function near(a, b, message)
	assert(math.abs(a - b) < 1e-6, `{message}: expected {b}, got {a}`)
end
local function slice(path, first, after)
	local source = fs.readFile(path)
	local start = assert(string.find(source, first, 1, true), `missing seam: {first}`)
	local finish = assert(string.find(source, after, start + #first, true), `missing seam: {after}`)
	assert(not string.find(source, first, start + 1, true), `ambiguous seam: {first}`)
	return string.sub(source, start, finish - 1)
end
local serverSource = slice("src/server/Abilities.luau", "local function fireCast(", "-- Live humanoids whose root")
local rainSource = slice("src/client/RimeFx.luau", "local function rain(ctx", "local function hit(ctx")
local receiveSource = slice("src/client/init.client.luau", "Net.CastFx.On(function(v)", "Net.HitFx.On(function(v)")

local function clock()
	local c = { now = 100, pending = {}, serial = 0 }
	function c.delay(dt, fn)
		assert(dt >= 0)
		c.serial += 1
		table.insert(c.pending, { at = c.now + dt, fn = fn, order = c.serial })
	end
	function c.advance(t)
		assert(t >= c.now)
		while true do
			table.sort(c.pending, function(a, b)
				return if a.at == b.at then a.order < b.order else a.at < b.at
			end)
			if #c.pending == 0 or c.pending[1].at > t + 1e-8 then
				break
			end
			local event = table.remove(c.pending, 1)
			c.now = event.at
			event.fn()
		end
		c.now = t
	end
	return c
end
local function server(c, accepted)
	local shots, zones, sent = {}, {}, {}
	local env = {
		shots = shots,
		zones = zones,
		GROUND_PROBE = 50,
		Projectile = require("../src/shared/Deliveries/Projectile"),
		Volley = require("../src/shared/Deliveries/Volley"),
		Zone = Zone,
		Net = {
			CastFx = {
				FireAll = function(value)
					table.insert(sent, { at = c.now, value = value })
				end,
			},
		},
		Vector3 = V,
		Enum = rb.Enum,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		workspace = {
			Raycast = function()
				return { Position = accepted }
			end,
		},
		os = {
			clock = function()
				return c.now
			end,
		},
		task = { delay = c.delay },
	}
	local exports = luau.load(serverSource .. "\nreturn {volley = volleyCast, zone = zoneCast}", {
		environment = env,
		injectGlobals = true,
	})()
	exports.shots, exports.zones, exports.sent = shots, zones, sent
	return exports
end
local function client(c, me, caster)
	local events = { starts = {}, drops = {}, impacts = {} }
	local function record(list, pos)
		table.insert(list, { at = c.now, pos = pos })
	end
	local env = {
		R = Config.Abilities.Rimeshard,
		RimeFxPlan = require("../src/shared/RimeFxPlan"),
		Players = { LocalPlayer = me },
		task = { delay = c.delay },
		Vector3 = V,
		CFrame = rb.CFrame,
		Enum = rb.Enum,
		ICE = rb.Color3.fromRGB(168, 230, 255),
		workspace = {},
		TweenInfo = {
			new = function(seconds)
				return { seconds = seconds }
			end,
		},
		take = function()
			return {}
		end,
		give = function() end,
		puff = function(pos)
			record(events.impacts, pos)
		end,
		disc = function(pos)
			record(events.starts, pos)
		end,
		snow = function() end,
		crack = function() end,
		TweenService = {
			Create = function(_, shard, info)
				local completed
				return {
					Completed = {
						Once = function(_, fn)
							completed = fn
						end,
					},
					Play = function()
						record(events.drops, shard.CFrame.Position)
						c.delay(info.seconds, function()
							if completed then
								completed()
							end
						end)
					end,
				}
			end,
		},
	}
	local rain = luau.load(rainSource .. "\nreturn rain", { environment = env, injectGlobals = true })()
	local fx = Fx.new()
	Fx.register(fx, fall.fx.travel, rain)
	Fx.register(fx, fall.fx.cast, function() end) -- warning rendering is outside this timing probe
	local receive
	luau.load(receiveSource, {
		environment = {
			Net = { CastFx = {
				On = function(fn)
					receive = fn
				end,
			} },
			player = me,
			fx = fx,
			FxRegistry = Fx,
		},
		injectGlobals = true,
	})()
	events.receive = receive
	events.predict = function(point)
		rain({ caster = caster, point = point })
	end
	return events
end
local desired = {}
local function probe(name, actual, expected)
	table.insert(desired, { name = name, actual = actual, expected = expected })
end

-- Actual volley helper queues all shards before any clock advance, ignoring the declared warning.
do
	local c = clock()
	local s = server(c, V.zero)
	s.volley({}, {}, fan, V.zero, V.zAxis)
	eq(fan.telegraph, 0.2, "Z declared warning")
	eq(#s.shots, 5, "Z shards at acceptance (known defect)")
	eq(#s.sent, 2, "Z cast and travel broadcast together")
	near(s.sent[1].at, s.sent[2].at, "Z has no release delay")
	probe("Z no damaging shots before +0.20", #s.shots, 0)
	local before = #s.shots
	s.volley({}, {}, finisher, V.zero, V.zAxis)
	eq(#s.shots - before, 2, "M1 paired finisher must remain immediate")
end

local function scenario(up, down)
	local c = clock()
	local caster, observer = { Character = {} }, {}
	local predicted, accepted = V.new(5, 6, -10), V.new(5, 0, -10)
	local localFx, remoteFx = client(c, caster, caster), client(c, observer, caster)
	local s = server(c, accepted)
	localFx.predict(predicted) -- KithInput dispatches cast/travel before sending, tested in client_input.
	c.advance(100 + up)
	s.zone(caster, caster.Character, fall, predicted, V.zAxis)
	eq(s.zones[1].center, accepted, "server raycast accepted centre")
	c.advance(100 + up + down)
	for _, event in s.sent do
		localFx.receive(event.value)
		remoteFx.receive(event.value)
	end
	c.advance(103)
	eq(#localFx.starts, 1, "own echo discarded, not reconciled")
	eq(#remoteFx.starts, 1, "observer starts once")
	near(localFx.starts[1].at, 100.6, "caster waits relative to input")
	near(remoteFx.starts[1].at, 100 + up + down, "observer rains at receipt")
	eq(localFx.starts[1].pos, predicted, "caster retains unaccepted prediction")
	eq(remoteFx.starts[1].pos, accepted, "observer uses server centre")
	eq(#localFx.drops, 8, "eight decorative drops, not four damage beats")
	eq(#remoteFx.impacts, 8, "observer decorative contacts")
	near(remoteFx.impacts[1].at, 100 + up + down + 0.22, "observer first decorative contact")
	return localFx, remoteFx, s
end
local localFx, remoteFx = scenario(0, 0)
probe("X zero-latency observer waits for warning", remoteFx.starts[1].at, localFx.starts[1].at)
probe("X caster corrects to accepted centre", localFx.starts[1].pos, remoteFx.starts[1].pos)
local delayedLocal, delayedRemote = scenario(0.08, 0.04)
probe("X latency uses acceptance epoch, not input", delayedLocal.starts[1].at, 100.68)
probe("X latency observer uses acceptance epoch, not receipt", delayedRemote.starts[1].at, 100.68)

-- Real Zone.step: exactly four authoritative beats, no early tick or duplicate catch-up damage.
do
	local p = fall.delivery.params
	local z = Zone.new(100)
	eq(Zone.step(z, 100.599, p), 0, "no warning damage")
	for i = 1, 4 do
		local at = 100 + Zone.tickAt(i, p)
		near(at, 100.6 + (i - 1) / 3, "X beat")
		eq(Zone.step(z, at, p), 1, "one damage beat")
		eq(Zone.step(z, at, p), 0, "same heartbeat cannot duplicate beat")
	end
	eq(Zone.step(z, 200, p), 0, "completed zone")
	local delayed = Zone.new(100)
	eq(Zone.step(delayed, 103, p), 4, "lagged heartbeat catches up four existing ticks")
	eq(Zone.step(delayed, 103, p), 0, "no extra lag damage")
end
print(
	"CHARACTERIZATION: PASS (Z immediate; X 0.60/0.00 and 0.60/0.12; centres diverge; four real Zone beats; M1 immediate)"
)
if table.find(process.args, "--contract") then
	local failed = 0
	for _, p in desired do
		if p.actual ~= p.expected then
			failed += 1
			print(`EXPECTED-CONTRACT FAIL: {p.name} | actual={p.actual} expected={p.expected}`)
		end
	end
	assert(failed == 0, `{failed} known contract violations; preparatory probes only, see T-043c1 note`)
end
