-- T-043c0b2: actual CastRequest callback with engine/data boundaries mocked.
-- Does not prove Roblox network transport, rendering, hit sweeps or live-device behaviour.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Lifetime = require("../src/shared/CastLifetime")
local Stance = require("../src/shared/Stance")
local built = Registry.build(All.content(Config))
local source = fs.readFile("src/server/Abilities.luau")
local function slice(first, after)
	local a = assert(source:find(first, 1, true), first)
	local b = assert(source:find(after, a + #first, true), after)
	assert(not source:find(first, a + 1, true), "ambiguous source seam")
	return source:sub(a, b - 1)
end
local dispatch = slice("function Abilities.start()", "\nreturn Abilities") .. "\nAbilities.start()"
local authorization = slice("-- T-043c0b3b2a: explicit", "function Abilities.start()")
local groundSource = slice("local function groundCentre(", "-- Geometry and monotonic start")
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
		pending = {},
		acceptedWire = {},
		dispositionWire = {},
		terminalWire = {},
		wireOrder = {},
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
	local changed, slotChanged = signal(), signal()
	local player = {
		UserId = 42,
		Character = character,
		CharacterAdded = signal(),
		CharacterRemoving = signal(),
		GetAttribute = function(_, name)
			return attrs[name]
		end,
		SetAttribute = function(_, name, value)
			attrs[name] = value
		end,
		GetAttributeChangedSignal = function(_, name)
			return if name == "ActiveSlot" then slotChanged else changed
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
		return function(_, _, move, ...)
			local args = { ... }
			table.insert(h.deliveries, { kind = kind, id = move.id, time = h.now, lifetime = args[#args] })
		end
	end
	local guid = 0
	local env = {
		Config = if protocol then setmetatable({ CastProtocol = protocol }, { __index = Config }) else Config,
		Abilities = {},
		Players = players,
		stances = stances,
		Qi = require("../src/shared/Qi"),
		CastAdmission = require("../src/shared/CastAdmission"),
		CastLedger = require("../src/shared/CastLedger"),
		CastReceipts = require("../src/shared/CastReceipts"),
		CastLifetime = Lifetime,
		lifetimes = Lifetime.new(Config.CastLifetime.capacity),
		task = {
			delay = function(seconds, fn)
				table.insert(h.pending, { seconds = seconds, fn = fn })
			end,
		},
		CastSchedule = require("../src/shared/CastSchedule"),
		workspace = {
			GetServerTimeNow = function()
				return 1000000 + h.now
			end,
			Raycast = function()
				h.raycasts = (h.raycasts or 0) + 1
				return if h.noGround then nil else { Position = rb.Vector3.new(0, 0, -10) }
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = rb.Enum,
		GROUND_PROBE = 50,
		RunService = { Heartbeat = {
			Connect = function(_, fn)
				h.heartbeat = fn
			end,
		} },
		zones = {},
		shots = {},
		holders = {},
		tickZone = function(z)
			z.ticks += 1
		end,
		HttpService = {
			GenerateGUID = function()
				guid += 1
				return "server-test-" .. tostring(guid)
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
			CastTerminal = {
				FireAll = function(v)
					table.insert(h.terminalWire, { audience = "all", value = v })
					table.insert(h.wireOrder, "terminal:all")
				end,
				Fire = function(to, v)
					assert(to == player)
					table.insert(h.terminalWire, { audience = "owner", value = v })
					table.insert(h.wireOrder, "terminal:owner")
				end,
			},
			CastAccepted = {
				FireAll = function(v)
					table.insert(h.acceptedWire, { audience = "all", value = v })
					table.insert(h.wireOrder, "accept:all")
				end,
				Fire = function(to, v)
					assert(to == player)
					table.insert(h.acceptedWire, { audience = "owner", value = v })
					table.insert(h.wireOrder, "accept:owner")
				end,
			},
			CastDisposition = {
				Fire = function(to, v)
					assert(to == player)
					table.insert(h.dispositionWire, v)
				end,
			},
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
		groundSource
			.. kitSource
			.. authorization
			.. dispatch
			.. "\nreturn { authorize = authorizeCast, deliver = deliverCast, sessions = castSessions, worldReceipts = terminalReceipts }",
		{ environment = env, injectGlobals = true }
	)()
	h.sessions = seam.sessions
	h.worldReceipts = seam.worldReceipts
	h.qi = env.pools[player]
	h.qi.current = 100
	h.cds = env.cooldowns[player]
	h.stance = stances[player]
	h.stance.chain.step, h.stance.chain.lastAt = step or 0, if step then 100 else -math.huge
	h.published = 0
	h.players, h.changed, h.slotChanged = players, changed, slotChanged
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
local function receipt(h, v)
	return h.env.CastReceipts.get(h.sessions[h.player].receipts, v.generation .. ":" .. tostring(v.seq), h.now)
end
local cases = {
	["world terminal replay stays bounded after departure and expires without new broadcasts"] = function()
		local h = harness()
		h.worldReceipts.policy =
			table.freeze({ capacity = 2, responseSeconds = 10, tombstoneSeconds = 12, maxLifetimeSeconds = 10 })
		h.callback(h.player, packet(h, 1, "move.rime.fall"))
		local first = h.deliveries[1].lifetime
		h.players.PlayerRemoving:Fire(h.player)
		Lifetime.finish(h.env.lifetimes, first, 1, h.now)
		for seq = 2, 4 do
			local a = table.clone(first.acceptance)
			a.seq, a.castId = seq, a.generation .. ":" .. seq
			local handle = Lifetime.start(h.env.lifetimes, a, h.now, 1, 1)
			Lifetime.finish(h.env.lifetimes, handle, 1, h.now)
		end
		local n = 0
		for _, entry in h.worldReceipts.entries do
			n += 1
			assert(entry.acceptance and entry.terminal)
		end
		assert(n == 2 and h.worldReceipts.entries[first.acceptance.castId] == nil and #h.terminalWire == 4)
		h.now += 13
		h.heartbeat(0)
		assert(next(h.worldReceipts.entries) == nil and #h.terminalWire == 4)
	end,

	["terminal broadcasts once, owner replay orders original acceptance before original terminal"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		h.callback(h.player, v)
		local handle = h.deliveries[1].lifetime
		h.now += 2
		assert(Lifetime.finish(h.env.lifetimes, handle, 1, h.now))
		local terminal = h.terminalWire[1]
		assert(terminal.audience == "all" and terminal.value.castId == handle.acceptance.castId)
		assert(terminal.value.at == handle.terminal.at and terminal.value.reason == "completed")
		assert(not Lifetime.terminate(h.env.lifetimes, handle, "expired", h.now))
		table.clear(h.sessions[h.player].receipts.entries) -- world replay survives owner cache eviction
		h.root.Position = rb.Vector3.new(99, 99, 99)
		h.callback(h.player, v)
		assert(#h.terminalWire == 2 and h.terminalWire[2].audience == "owner")
		assert(h.terminalWire[2].value.at == terminal.value.at)
		assert(h.wireOrder[#h.wireOrder - 1] == "accept:owner" and h.wireOrder[#h.wireOrder] == "terminal:owner")
		assert(h.acceptedWire[2].value.origin == h.acceptedWire[1].value.origin)
		assert(#h.deliveries == 1 and h.strain == 1)
	end,
	["departure before completion still broadcasts terminal exactly once to observers"] = function()
		local h = harness()
		local v = packet(h, 1, "move.wind_step")
		h.callback(h.player, v)
		h.players.PlayerRemoving:Fire(h.player)
		h.now += h.pending[1].seconds
		h.pending[1].fn()
		h.pending[1].fn()
		h.heartbeat(0)
		assert(#h.terminalWire == 1 and h.terminalWire[1].audience == "all")
		assert(h.terminalWire[1].value.reason == "completed")
	end,
	["heartbeat expiry emits one terminal; cache timeout cannot cause replay delivery"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		h.callback(h.player, v)
		local handle = h.deliveries[1].lifetime
		h.now = handle.deadline
		h.heartbeat(0)
		assert(#h.terminalWire == 1 and h.terminalWire[1].value.reason == "expired")
		h.callback(h.player, v)
		assert(#h.terminalWire == 2 and h.terminalWire[2].audience == "owner")
		h.now += 13
		h.heartbeat(0)
		h.callback(h.player, v)
		assert(#h.terminalWire == 2 and #h.deliveries == 1)
	end,

	["world capacity rejects before atomic payment; free room admits a fresh sequence only"] = function()
		local h = harness(2)
		h.env.lifetimes.capacity = 1
		local full = {
			castId = "occupied",
			generation = "old",
			seq = 1,
			moveId = "move.test",
			casterUserId = 9,
			characterKey = "old",
			slotRevision = 1,
			acceptedAt = 1000,
			releaseAt = 1000,
			endsAt = 1002,
			aim = { x = 0, y = 0, z = 1 },
			origin = { x = 0, y = 0, z = 0 },
		}
		local handle = Lifetime.start(h.env.lifetimes, full, h.now, 1, 1)
		local v = packet(h, 1, "move.rime.shard_fan")
		h.callback(h.player, v)
		assert(h.qi.current == 100 and h.strain == 0 and h.stance.chain.step == 2 and next(h.cds) == nil)
		assert(#h.deliveries == 0 and h.dispositionWire[#h.dispositionWire].reason == "delivery_capacity")
		Lifetime.finish(h.env.lifetimes, handle, 1, h.now)
		h.callback(h.player, v)
		assert(#h.deliveries == 0) -- cached refusal is never repaid on duplicate
		h.callback(h.player, packet(h, 2, "move.rime.shard_fan"))
		assert(#h.deliveries == 1 and h.env.lifetimes.count == 1 and h.strain == 1)
	end,
	["dispatcher passes original world handle once, retaining acceptance after player cache destruction"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		h.callback(h.player, v)
		local handle = h.deliveries[1].lifetime
		assert(handle == h.env.lifetimes.active[v.generation .. ":1"])
		assert(handle.acceptance.centre.y == h.acceptedWire[1].value.centre.Y)
		h.callback(h.player, v)
		assert(#h.deliveries == 1 and h.env.lifetimes.count == 1)
		local cache = h.sessions[h.player].receipts
		h.players.PlayerRemoving:Fire(h.player)
		assert(cache.closed and next(cache.entries) == nil)
		assert(Lifetime.isActive(h.env.lifetimes, handle) and handle.acceptance.characterKey ~= "")
		Lifetime.finish(h.env.lifetimes, handle, 1, h.now + 2)
		assert(handle.terminal.reason == "completed" and h.env.lifetimes.count == 0)
	end,
	["self delivery schedules actual accepted duration and completes once after departure"] = function()
		local h = harness()
		local v = packet(h, 1, "move.wind_step")
		h.callback(h.player, v)
		local handle = h.env.lifetimes.active[v.generation .. ":1"]
		assert(#h.pending == 1)
		assert(math.abs(h.pending[1].seconds - (handle.acceptance.endsAt - handle.acceptance.acceptedAt)) < 1e-8)
		h.players.PlayerRemoving:Fire(h.player)
		h.now += h.pending[1].seconds
		h.pending[1].fn()
		h.pending[1].fn()
		assert(handle.terminal.reason == "completed" and h.env.lifetimes.count == 0)
	end,

	["reliable fresh acceptance broadcasts once; duplicate returns original only to owner"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		h.callback(h.player, v)
		assert(#h.acceptedWire == 1 and h.acceptedWire[1].audience == "all" and #h.dispositionWire == 0)
		local original = h.acceptedWire[1].value
		h.now += 1
		h.root.Position = rb.Vector3.new(99, 99, 99)
		h.callback(h.player, v)
		assert(#h.acceptedWire == 2 and h.acceptedWire[2].audience == "owner" and #h.deliveries == 1)
		for key, value in original do
			assert(h.acceptedWire[2].value[key] == value, key)
		end
		assert(original.centre == rb.Vector3.new(0, 0, -10))
	end,
	["legitimate rejection is cached owner-only; lost full receipt explicitly expires"] = function()
		local h = harness()
		local v = packet(h, 1)
		h.qi.current = 0
		h.callback(h.player, v)
		h.qi.current = 100
		h.callback(h.player, v)
		assert(#h.acceptedWire == 0 and #h.dispositionWire == 2 and #h.deliveries == 0)
		assert(h.dispositionWire[1].reason == "qi" and h.dispositionWire[2].reason == "qi")
		local paid = packet(h, 2)
		h.callback(h.player, paid)
		table.clear(h.sessions[h.player].receipts.entries)
		h.callback(h.player, paid)
		assert(#h.deliveries == 1 and #h.acceptedWire == 1)
		local disposition = h.dispositionWire[3]
		assert(disposition.status == "expired" and disposition.reason == "receipt_expired" and disposition.seq == 2)
		h.now += 11
		h.callback(h.player, paid)
		assert(#h.deliveries == 1 and #h.acceptedWire == 1 and #h.dispositionWire == 4)
	end,
	["old generation and character race reject owner-only; abusive traffic is silent"] = function()
		local h = harness()
		local v = packet(h, 1)
		h.allowed = false
		h.callback(h.player, v)
		assert(#h.dispositionWire == 0 and #h.acceptedWire == 0)
		h.allowed = true
		v.aim = rb.Vector3.new(0 / 0, 0, 0)
		h.callback(h.player, v)
		assert(#h.dispositionWire == 0 and #h.acceptedWire == 0)
		v = packet(h, 1)
		h.player.CharacterRemoving:Fire(h.player.Character)
		h.callback(h.player, v)
		assert(h.dispositionWire[1].reason == "character")
		h.player.Character = table.clone(h.player.Character)
		h.player.CharacterAdded:Fire(h.player.Character)
		h.callback(h.player, v)
		assert(h.dispositionWire[2].reason == "generation" and #h.acceptedWire == 0 and #h.deliveries == 0)
	end,

	["fresh captured receipt uses server clocks, real centre and original immutable geometry"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		v.point = rb.Vector3.new(0, 6, -10)
		v.aim = rb.Vector3.new(0, 0.6, -0.8)
		h.callback(h.player, v)
		local a = assert(receipt(h, v)).acceptance
		assert(a and a.casterUserId == 42 and a.moveId == v.moveId and a.seq == 1)
		assert(a.acceptedAt == 1000000 + h.now and a.releaseAt == a.acceptedAt + 0.6 and a.endsAt == a.acceptedAt + 1.6)
		assert(a.centre.y == 0 and a.centre.z == -10 and a.aim.z == -1 and a.aim.y == 0)
		assert(h.raycasts == 1 and a.slotRevision == 0 and #a.characterKey > 0)
		local qi, strain = h.qi.current, h.strain
		h.root.Position = rb.Vector3.new(100, 100, 100)
		h.now += 1
		h.callback(h.player, v)
		assert(receipt(h, v).acceptance == a and h.raycasts == 1 and #h.deliveries == 1)
		assert(h.qi.current == qi and h.strain == strain)
	end,
	["zone delivery consumes exact captured point and monotonic start without a second raycast"] = function()
		local h = harness()
		local a = assert(h.authorize(request("move.rime.fall")))
		local env = table.clone(h.env)
		env.zones = {}
		local deliver = luau.load(
			slice("local function zoneCast(", "-- Live humanoids whose root") .. "\nreturn zoneCast",
			{ environment = env, injectGlobals = true }
		)()
		h.now += 0.1
		deliver(h.player, a.character, a.move, a.point, a.dir, a.monotonicAt)
		assert(env.zones[1].center == a.point and env.zones[1].state.startedAt == a.monotonicAt)
		assert(h.raycasts == 1 and a.monotonicAt == 100.01)
	end,
	["current Z receipts are immediate; slot away-back revision is distinct from character identity"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.shard_fan")
		h.callback(h.player, v)
		local a = receipt(h, v).acceptance
		assert(a.releaseAt == a.acceptedAt and math.abs(a.endsAt - a.acceptedAt - 0.35) < 1e-8)
		h.player:SetAttribute("ActiveSlot", 2)
		h.slotChanged:Fire()
		h.player:SetAttribute("ActiveSlot", 1)
		h.slotChanged:Fire()
		h.now += 4
		local v2 = packet(h, 2, "move.rime.shard_fan")
		h.callback(h.player, v2)
		local b = receipt(h, v2).acceptance
		assert(b.slotRevision == 2 and b.characterKey == a.characterKey and a.slotRevision == 0)
	end,
	["full cache survives sequence renewal and respawn but never authorizes old identity"] = function()
		local h = harness(nil, { capacity = 128, maxAdvance = 1, responseSeconds = 10, renewDistance = 2 })
		local v = packet(h, 1)
		h.callback(h.player, v)
		local a = receipt(h, v).acceptance
		h.now += 3
		h.callback(h.player, packet(h, 2))
		h.now += 3
		h.callback(h.player, packet(h, 3)) -- renew after two advances
		local key = h.sessions[h.player].characterKey
		assert(key == a.characterKey and h.snapshot.generation ~= v.generation)
		h.callback(h.player, v)
		assert(#h.deliveries == 3)
		h.player.CharacterRemoving:Fire(h.player.Character)
		h.player.Character = table.clone(h.player.Character)
		h.player.CharacterAdded:Fire(h.player.Character)
		assert(h.sessions[h.player].characterKey ~= key and receipt(h, v).acceptance == a)
		h.callback(h.player, v)
		assert(#h.deliveries == 3)
	end,
	["receipt eviction and heartbeat expiry never repeat delivery; reject has no acceptance"] = function()
		local h = harness()
		h.sessions[h.player].receipts = h.env.CastReceipts.new({
			capacity = 1,
			responseSeconds = 10,
			tombstoneSeconds = 10,
			maxLifetimeSeconds = 10,
		})
		local v = packet(h, 1)
		h.callback(h.player, v)
		h.now += 4
		local v2 = packet(h, 2)
		h.callback(h.player, v2)
		assert(receipt(h, v) == nil and receipt(h, v2))
		h.callback(h.player, v)
		assert(#h.deliveries == 2)
		h.now += 11
		h.heartbeat(0)
		assert(receipt(h, v2) == nil)
		h.callback(h.player, v2)
		assert(#h.deliveries == 2)
		h.qi.current = 0
		local reject = packet(h, 3)
		h.callback(h.player, reject)
		assert(receipt(h, reject) == nil and #h.deliveries == 2)
	end,

	["heartbeat prunes receipts but accepted zones survive renewal respawn and leave"] = function()
		local h = harness()
		local v = packet(h, 1, "move.rime.fall")
		h.callback(h.player, v)
		local admission = h.sessions[h.player].admission
		local lifetime = assert(h.env.lifetimes.active[v.generation .. ":1"])
		local zone = { ticks = 0, state = { done = false }, lifetime = lifetime }
		table.insert(h.env.zones, zone)
		table.clear(admission.ledger.entries) -- replay eviction is not world-resource ownership
		h.now += 0.1
		h.heartbeat(0)
		assert(next(admission.ledger.entries) == nil and zone.ticks == 1)
		h.callback(h.player, v)
		assert(#h.deliveries == 1)
		h.player.CharacterRemoving:Fire(h.player.Character)
		h.player.Character = table.clone(h.player.Character)
		h.player.CharacterAdded:Fire(h.player.Character)
		h.heartbeat(0)
		assert(h.env.zones[1] == zone and zone.ticks == 2)
		h.players.PlayerRemoving:Fire(h.player)
		h.heartbeat(0)
		assert(h.env.zones[1] == zone and zone.ticks == 3)
		zone.state.done = true
		h.heartbeat(0)
		assert(#h.env.zones == 0 and zone.ticks == 4)
	end,
	["rate guard drops sync/cast without allocating or changing epoch"] = function()
		local h = harness()
		local session, snapshot = h.sessions[h.player], h.snapshot
		h.allowed = false
		h.sync()
		h.callback(h.player, packet(h, 1))
		assert(h.snapshot == snapshot and next(session.admission.ledger.entries) == nil)
		assert(#h.deliveries == 0 and h.strain == 0 and h.qi.current == 100)
	end,

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
			h.player.CharacterAdded.count() == 0
				and h.player.CharacterRemoving.count() == 0
				and h.changed.count() == 0
				and h.slotChanged.count() == 0
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
		h.deliver(accepted, {} :: any)
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
