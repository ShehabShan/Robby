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
local dispatch = slice("function Abilities.start()", "\n\tRunService.Heartbeat:Connect") .. "\nend\nAbilities.start()"
local authorization = slice("-- T-043c0b3b2a: explicit", "function Abilities.start()")
local kitSource = slice("local function kitFor(", "local function stanceFor(")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			listeners[fn] = true
			return {
				Disconnect = function()
					listeners[fn] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for fn in listeners do
				fn(...)
			end
		end,
		count = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
end
local function harness(step, protocol)
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
	local attrs = { ActiveSlot = 1, ActiveKith = "kith.rimeshard" }
	local changed = signal()
	local player = {
		Character = character,
		CharacterAdded = signal(),
		CharacterRemoving = signal(),
		GetAttribute = function(_, name)
			return attrs[name]
		end,
		SetAttribute = function(_, name, value)
			attrs[name] = value
		end,
		GetAttributeChangedSignal = function()
			return changed
		end,
	}
	local stances = {}
	local players = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		GetPlayers = function()
			return { player }
		end,
	}
	local function delivery(kind)
		return function(_, _, move)
			table.insert(h.deliveries, { kind = kind, id = move.id, time = h.now })
		end
	end
	local env = {
		Config = if protocol then setmetatable({ CastProtocol = protocol }, { __index = Config }) else Config,
		Abilities = {},
		Players = players,
		stances = stances,
		Qi = require("../src/shared/Qi"),
		CastAdmission = require("../src/shared/CastAdmission"),
		HttpService = {
			GenerateGUID = function()
				return "server-test"
			end,
		},
		Status = {
			clear = function()
				h.cleared = true
			end,
		},
		statuses = {},
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
		Net = {
			CastGeneration = {
				Fire = function(_, v)
					h.snapshot = v
				end,
			},
			CastSync = {
				On = function(fn)
					h.sync = function()
						fn(player)
					end
				end,
			},
			CastRequest = {
				On = function(fn)
					h.callback = fn
				end,
			},
		},
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
			if not stances[player] then
				stances[player] = Stance.new()
			end
			return stances[player]
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
		kitSource
			.. authorization
			.. dispatch
			.. "\nreturn { authorize = authorizeCast, deliver = deliverCast, sessions = castSessions }",
		{ environment = env, injectGlobals = true }
	)()
	h.sessions = seam.sessions
	h.qi = env.pools[player]
	h.qi.current = 100
	h.cds = env.cooldowns[player]
	h.stance = stances[player]
	h.stance.chain.step, h.stance.chain.lastAt = step or 0, if step then 100 else -math.huge
	h.published = 0
	h.players, h.changed = players, changed
	h.authorize = function(value)
		return seam.authorize(player, value)
	end
	h.deliver = seam.deliver
	h.player = player
	h.env = env
	h.root = root
	local seq = 0
	function h:send(id)
		seq += 1
		self.callback(player, {
			moveId = id,
			seq = seq,
			generation = h.snapshot.generation,
			aim = rb.Vector3.new(0, 0, -1),
			point = rb.Vector3.new(0, 0, -10),
		})
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
local function packet(h, seq, move)
	local v = request(move or "move.wind_step")
	v.seq, v.generation = seq, h.snapshot.generation
	return v
end
local cases = {
	["epoch exhaustion cannot reuse generation for another character"] = function()
		local h = harness()
		local v = packet(h, 1)
		local session = h.sessions[h.player]
		session.admission.epoch = 4294967295
		h.player.CharacterRemoving:Fire(h.player.Character)
		assert(session.admission.closed and h.snapshot.character == nil)
		h.player.Character = table.clone(h.player.Character)
		h.player.CharacterAdded:Fire(h.player.Character)
		h.callback(h.player, v)
		assert(#h.deliveries == 0 and h.strain == 0 and h.snapshot.character == nil)
	end,

	["live replay blocks duplicate and changed payload; expiry does not reopen payment"] = function()
		local h = harness()
		local v = packet(h, 1)
		h.callback(h.player, v)
		local qi, cooldown = h.qi.current, h.cds[v.moveId]
		h.callback(h.player, v)
		local changed = table.clone(v)
		changed.aim = rb.Vector3.new(1, 0, 0)
		h.callback(h.player, changed)
		h.now += 11
		h.callback(h.player, v)
		assert(#h.deliveries == 1 and h.strain == 1 and h.fought == 1 and h.published == 1)
		assert(h.qi.current == qi and h.cds[v.moveId] == cooldown)
	end,
	["failed live authorization cached even after resources recover; new request succeeds"] = function()
		local h = harness()
		local v = packet(h, 1)
		h.qi.current = 0
		h.callback(h.player, v)
		h.qi.current = 100
		h.callback(h.player, v)
		assert(#h.deliveries == 0 and h.qi.current == 100)
		h.callback(h.player, packet(h, 2))
		assert(#h.deliveries == 1 and h.strain == 1)
	end,
	["server renewal rejects old inflight traffic; sync never rotates or retries"] = function()
		local h = harness(nil, { capacity = 4, maxAdvance = 2, responseSeconds = 10, renewDistance = 3 })
		local original = h.snapshot.generation
		for seq = 65534, 65537 do
			h.callback(h.player, packet(h, seq % 65536))
			h.now += 10
		end
		assert(#h.deliveries == 4 and h.snapshot.generation ~= original)
		local epoch, generation = h.snapshot.epoch, h.snapshot.generation
		local old = packet(h, 2)
		old.generation = original
		h.callback(h.player, old)
		h.sync()
		h.sync()
		assert(#h.deliveries == 4 and h.snapshot.epoch == epoch and h.snapshot.generation == generation)
		h.callback(h.player, packet(h, 2))
		assert(#h.deliveries == 5 and h.strain == 5)
	end,
	["actual character lifecycle resets stance, binds identity and destroys connections"] = function()
		local h = harness(2)
		local old, oldGeneration = h.player.Character, h.snapshot.generation
		local v = packet(h, 1)
		-- Property changes ahead of the character event: never authorize under old scope.
		local new = table.clone(old)
		h.player.Character = new
		h.callback(h.player, v)
		assert(#h.deliveries == 0)
		h.player.CharacterRemoving:Fire(old)
		assert(h.snapshot.character == nil)
		h.player.CharacterAdded:Fire(new)
		assert(h.snapshot.character == new and h.snapshot.generation ~= oldGeneration)
		assert(h.env.stances[h.player].chain.step == 0 and h.env.stances[h.player].finisherAt == -math.huge)
		h.callback(h.player, v)
		assert(#h.deliveries == 0)
		h.callback(h.player, packet(h, 2, "move.rime.needle"))
		assert(#h.deliveries == 1)
		local session = h.sessions[h.player]
		h.players.PlayerRemoving:Fire(h.player)
		assert(session.admission.closed and next(session.admission.ledger.entries) == nil)
		assert(h.sessions[h.player] == nil and h.env.pools[h.player] == nil and h.env.stances[h.player] == nil)
		assert(
			h.player.CharacterAdded.count() == 0 and h.player.CharacterRemoving.count() == 0 and h.changed.count() == 0
		)
		h.callback(h.player, packet(h, 3))
		assert(#h.deliveries == 1 and h.cleared)
	end,
	["nonfinite optional point rejected before payment even on non-zone move"] = function()
		local h = harness()
		local v = packet(h, 1)
		v.point = rb.Vector3.new(0, 0 / 0, 0)
		h.callback(h.player, v)
		assert(#h.deliveries == 0 and h.strain == 0 and h.qi.current == 100)
	end,

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
