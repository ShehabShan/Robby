-- T-043c0b2: actual CastRequest callback with engine/data boundaries mocked.
-- Does not prove Roblox network transport, rendering, hit sweeps or live-device behaviour.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Stance = require("../src/shared/Stance")
local built = Registry.build(All.content(Config))
local source = fs.readFile("src/server/Abilities.luau")
local function slice(first, after)
	local a = assert(source:find(first, 1, true), first)
	local b = assert(source:find(after, a + #first, true), after)
	assert(not source:find(first, a + 1, true), "ambiguous source seam")
	return source:sub(a, b - 1)
end
local dispatch = slice("Net.CastRequest.On(function(player: Player, value)", "\n\tRunService.Heartbeat:Connect")
local authorization = slice("-- T-043c0b3b2a: explicit", "function Abilities.start()")
local kitSource = slice("local function kitFor(", "local function stanceFor(")
local function harness(step)
	local h = {
		now = 100.01,
		qi = { current = 100 },
		cds = {},
		deliveries = {},
		strain = 0,
		fought = 0,
		published = 0,
		allowed = true,
		owns = true,
		usable = true,
	}
	h.stance = Stance.new()
	Stance.set(h.stance, true)
	h.stance.chain.step, h.stance.chain.lastAt = step or 0, if step then 100 else -math.huge
	local root = { Position = rb.Vector3.new(0, 3, 0) }
	local character = {
		FindFirstChildOfClass = function()
			return { Health = h.hp or 100 }
		end,
	}
	local player = {
		Character = character,
		GetAttribute = function()
			return 1
		end,
	}
	local function delivery(kind)
		return function(_, _, move)
			table.insert(h.deliveries, { kind = kind, id = move.id, time = h.now })
		end
	end
	local env = {
		Config = Config,
		built = built,
		Stance = Stance,
		CastRequest = require("../src/shared/CastRequest"),
		CastTransaction = require("../src/shared/CastTransaction"),
		Projectile = require("../src/shared/Deliveries/Projectile"),
		Zone = require("../src/shared/Deliveries/Zone"),
		Vector3 = rb.Vector3,
		CHEST = rb.Vector3.new(0, 0.5, 0),
		pools = { [player] = h.qi },
		cooldowns = { [player] = h.cds },
		Net = { CastRequest = {
			On = function(fn)
				h.callback = fn
			end,
		} },
		RemoteGuard = {
			allow = function()
				return h.allowed
			end,
		},
		DataService = {
			get = function()
				return if h.noData then nil else { loadout = { weaves = {} }, kith = {} }
			end,
		},
		Loadout = {
			canCastLive = function()
				return h.owns
			end,
		},
		Loom = {
			wovenFor = function()
				return nil
			end,
		},
		KithCare = {
			casterOf = function()
				return nil, {}
			end,
			ensure = function() end,
			usable = function()
				return h.usable
			end,
			moveStrain = function()
				return 1
			end,
			addStrain = function()
				h.strain += 1
			end,
		},
		UpkeepService = {
			fought = function()
				h.fought += 1
			end,
		},
		publishQi = function()
			h.published += 1
		end,
		aliveRoot = function()
			return if h.noRoot then nil else root
		end,
		stanceFor = function()
			return h.stance
		end,
		os = {
			clock = function()
				return h.now
			end,
			time = function()
				return 1000
			end,
		},
		selfCast = function(_, move)
			table.insert(h.deliveries, { kind = "Self", id = move.id, time = h.now })
		end,
		burstCast = delivery("Burst"),
		zoneCast = delivery("Zone"),
		volleyCast = delivery("Volley"),
		pushShot = delivery("Projectile"),
		fireCast = function() end,
	}
	local seam = luau.load(
		kitSource .. authorization .. dispatch .. "\nreturn { authorize = authorizeCast, deliver = deliverCast }",
		{ environment = env, injectGlobals = true }
	)()
	h.authorize = function(value)
		return seam.authorize(player, value)
	end
	h.deliver = seam.deliver
	h.player = player
	h.env = env
	h.root = root
	function h:send(id)
		self.callback(
			player,
			{ moveId = id, seq = 1, aim = rb.Vector3.new(0, 0, -1), point = rb.Vector3.new(0, 0, -10) }
		)
	end
	return h
end
local function pristine(h, step)
	assert(#h.deliveries == 0 and h.strain == 0 and h.fought == 0 and h.published == 0)
	assert(h.stance.chain.step == step and h.stance.chain.lastAt == 100)
end
local function request(id)
	return {
		moveId = id or "move.rime.shard_fan",
		seq = 1,
		aim = rb.Vector3.new(0, 0, -1),
		point = rb.Vector3.new(0, 0, -10),
	}
end
local cases = {
	["explicit rejection reasons leave payment and delivery untouched"] = function()
		local rows = {
			{
				"not_ready",
				function(h)
					h.env.pools[h.player] = nil
				end,
			},
			{
				"not_ready",
				function(h)
					h.env.cooldowns[h.player] = nil
				end,
			},
			{
				"invalid_request",
				function(_, v)
					v.moveId = "unknown"
				end,
			},
			{
				"invalid_request",
				function(_, v)
					v.seq = 65536
				end,
			},
			{
				"invalid_request",
				function(_, v)
					v.aim = {}
				end,
			},
			{
				"loadout",
				function(h)
					h.noData = true
				end,
			},
			{
				"loadout",
				function(h)
					h.owns = false
				end,
			},
			{
				"unusable",
				function(h)
					h.usable = false
				end,
			},
			{
				"aim",
				function(_, v)
					v.aim = rb.Vector3.new(0 / 0, 0, 0)
				end,
			},
			{
				"aim",
				function(_, v)
					v.aim = rb.Vector3.new(0, 1, 0)
				end,
			},
			{
				"character",
				function(h)
					h.noRoot = true
				end,
			},
			{
				"character",
				function(h)
					h.player.Character = nil
				end,
			},
			{
				"point",
				function(_, v)
					v.moveId = "move.rime.fall"
					v.point = nil
				end,
			},
			{
				"point",
				function(_, v)
					v.moveId = "move.rime.fall"
					v.point = rb.Vector3.new(1e6, 0, 0)
				end,
			},
			{
				"stance",
				function(_, v)
					v.moveId = "move.rime.needle_finisher"
				end,
			},
			{
				"qi",
				function(h)
					h.qi.current = 0
				end,
			},
			{
				"cooldown",
				function(h)
					h.cds["move.rime.shard_fan"] = 110
				end,
			},
		}
		for _, row in rows do
			local h, v = harness(2), request()
			row[2](h, v)
			local qi, cd = h.qi.current, h.cds[v.moveId]
			local accepted, reason = h.authorize(v)
			assert(accepted == nil and reason == row[1], tostring(reason) .. " vs " .. row[1])
			pristine(h, 2)
			assert(h.qi.current == qi and h.cds[v.moveId] == cd)
		end
	end,
	["authorization completes without yielding or engine work; delivery uses captured geometry"] = function()
		local h = harness(2)
		local job = coroutine.create(h.authorize)
		local ok, accepted, reason = coroutine.resume(job, request())
		assert(ok and accepted and reason == nil and coroutine.status(job) == "dead")
		assert(h.qi.current == 90 and h.strain == 1 and h.stance.chain.step == 0)
		assert(h.fought == 0 and h.published == 0 and #h.deliveries == 0)
		local origin = accepted.origin
		h.root.Position = rb.Vector3.new(100, 100, 100)
		assert(accepted.origin == origin and accepted.character == h.player.Character)
		h.deliver(accepted)
		assert(h.qi.current == 90 and h.strain == 1 and h.fought == 1 and h.published == 1)
		assert(#h.deliveries == 1 and h.deliveries[1].time == h.now)
	end,

	["unpaid shot2 cancel keeps authoritative state; paid retry casts once"] = function()
		local h = harness(2)
		h.qi.current = 0
		h:send("move.rime.shard_fan")
		pristine(h, 2)
		assert(next(h.cds) == nil)
		h.qi.current = 100
		h:send("move.rime.shard_fan")
		assert(h.qi.current == 90 and h.stance.chain.step == 0)
		assert(h.strain == 1 and h.fought == 1 and h.published == 1 and #h.deliveries == 1)
		assert(h.deliveries[1].kind == "Volley" and h.deliveries[1].time == h.now)
	end,
	["cooldown rejection does not consume cancel"] = function()
		local h = harness(2)
		h.cds["move.rime.shard_fan"] = 110
		h:send("move.rime.shard_fan")
		pristine(h, 2)
		assert(h.qi.current == 100 and h.cds["move.rime.shard_fan"] == 110)
	end,
	["invalid chain order leaves Qi cooldown strain untouched"] = function()
		local h = harness(1)
		h:send("move.rime.needle_finisher")
		pristine(h, 1)
		assert(h.qi.current == 100 and next(h.cds) == nil)
	end,
	["preauthorization rejects before transaction"] = function()
		for _, field in { "allowed", "owns", "usable" } do
			local h = harness(2)
			h[field] = false
			h:send("move.rime.shard_fan")
			pristine(h, 2)
			assert(h.qi.current == 100 and next(h.cds) == nil)
		end
	end,
	["fixed move does not reset an active chain"] = function()
		local h = harness(2)
		h:send("move.wind_step")
		assert(h.stance.chain.step == 2 and #h.deliveries == 1 and h.deliveries[1].kind == "Self")
	end,
	["accepted M1 zone and burst retain immediate dispatch"] = function()
		for _, row in
			{ { "move.rime.needle", "Projectile" }, { "move.rime.fall", "Zone" }, { "move.rime.shatter", "Burst" } }
		do
			local h = harness()
			h:send(row[1])
			assert(#h.deliveries == 1 and h.deliveries[1].kind == row[2] and h.deliveries[1].time == h.now)
		end
	end,
}
local passed = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
end
print(`CAST DISPATCH: PASS ({passed} actual-callback cases; mocked engine boundaries)`)
