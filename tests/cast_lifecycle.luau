-- Real server delivery + heartbeat source, pure delivery cores, mocked engine queries/FX/damage.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local L = require("../src/shared/CastLifetime")
local Schedule = require("../src/shared/CastSchedule")
local Registry = require("../src/shared/Registry")
local built = Registry.build(require("../src/shared/Content/All").content(Config))
local V = rb.Vector3
local source = fs.readFile("src/server/Abilities.luau")
local function slice(first, after)
	local a = assert(source:find(first, 1, true), first)
	local b = assert(source:find(after, a + #first, true), after)
	assert(not source:find(first, a + 1, true), "ambiguous source seam")
	return source:sub(a, b - 1)
end
local function harness()
	local h = {
		now = 100,
		pending = {},
		damage = 0,
		hits = 0,
		fx = 0,
		targets = {},
		serial = 0,
		terminals = {},
		contacts = {},
		events = {},
		blocked = false,
	}
	local players = {
		GetPlayerFromCharacter = function()
			return if h.blocked then {} else nil
		end,
	}
	local character = { root = { Position = V.zero }, alive = true }
	local player = { Character = character, Parent = players, Name = "Owner" }
	local env = {
		Vector3 = V,
		CFrame = rb.CFrame,
		Enum = rb.Enum,
		Config = Config,
		Players = players,
		CastLifetime = L,
		CastContacts = require("../src/shared/CastContacts"),
		CastReceipts = require("../src/shared/CastReceipts"),
		terminalReceipts = require("../src/shared/CastReceipts").new(Config.CastTerminal),
		lifetimes = L.new(64),
		Projectile = require("../src/shared/Deliveries/Projectile"),
		Volley = require("../src/shared/Deliveries/Volley"),
		Zone = require("../src/shared/Deliveries/Zone"),
		Burst = require("../src/shared/Deliveries/Burst"),
		shots = {},
		zones = {},
		holders = {},
		pools = {},
		castSessions = {},
		statuses = {},
		DEFAULT_HITBOX = { x = 2, y = 2, z = 2 },
		GROUND_PROBE = 50,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		Frost = {
			stacks = function(holder)
				return holder.stacks
			end,
		},
		Status = {
			blocksHit = function()
				return h.blocked
			end,
		},
		Effects = { tick = function() end },
		hitKey = function(model)
			return model.id
		end,
		aliveRoot = function(c)
			return if c and c.alive then c.root else nil
		end,
		applyOnHit = function()
			h.damage += 1
			return h.amount or 4
		end,
		os = {
			clock = function()
				return h.now
			end,
		},
		task = {
			delay = function(_, fn)
				table.insert(h.pending, fn)
			end,
		},
		Net = {
			CastContact = {
				FireAll = function(v)
					assert(h.damage > #h.contacts, "notification preceded authoritative effects")
					table.insert(h.contacts, v)
					table.insert(h.events, "contact")
				end,
			},
			CastTerminal = {
				FireAll = function(v)
					table.insert(h.terminals, v)
					table.insert(h.events, "terminal")
				end,
			},
			CastFx = {
				FireAll = function()
					h.fx += 1
				end,
			},
			HitFx = {
				FireAll = function()
					h.hits += 1
				end,
			},
		},
		workspace = {
			GetPartBoundsInRadius = function()
				return h.targets
			end,
			Blockcast = function(_, _, _, _, params)
				for _, part in h.targets do
					local model = part:FindFirstAncestorOfClass("Model")
					if not table.find(params.FilterDescendantsInstances, model) then
						return { Instance = part, Position = V.zero }
					end
				end
				return nil
			end,
		},
		RunService = { Heartbeat = {
			Connect = function(_, fn)
				h.heartbeat = fn
			end,
		} },
	}
	local heartbeat = slice("\tRunService.Heartbeat:Connect(function(dt: number)", "\nreturn Abilities")
	-- The source ends the Abilities.start wrapper: supply that wrapper rather than rewriting logic.
	local body = slice("local hitKeys:", "local CastRequest =") .. slice("-- Confirmed contacts", "-- The Kith's Kit")
	local methods = luau.load(
		body
			.. slice("local function sendTerminal", "local function sendDisposition")
			.. "\nlifetimes.onTerminal = recordTerminal\nlocal function boot()\n"
			.. heartbeat
			.. "\nboot()\nreturn { shot=pushShot, volley=volleyCast, zone=zoneCast, burst=burstCast, start=startContactLedger, contact=confirmedContact, ledgers=contactLedgers }",
		{ environment = env, injectGlobals = true }
	)()
	function h:target()
		local model = { id = tostring(#self.targets + 1), Parent = {} }
		local humanoid = { Health = 100, Parent = model }
		local root = {
			Position = V.zero,
			IsA = function(_, name)
				return name == "BasePart"
			end,
		}
		model.FindFirstChildOfClass = function()
			return humanoid
		end
		model.FindFirstChild = function()
			return root
		end
		model.IsA = function(_, name)
			return name == "Model"
		end
		local part = {
			FindFirstAncestorOfClass = function()
				return model
			end,
		}
		table.insert(self.targets, part)
		env.holders[model] = { stacks = 3, active = {} }
		return model, humanoid
	end
	function h:cast(id)
		local move = built.moves[id]
		local schedule = assert(Schedule.offsets(move, built.effects, 10))
		self.serial += 1
		local a = {
			castId = "g:" .. self.serial,
			generation = "g",
			seq = self.serial,
			moveId = id,
			casterUserId = 1,
			characterKey = "old",
			slotRevision = 1,
			acceptedAt = 10000,
			releaseAt = 10000 + schedule.release,
			endsAt = 10000 + schedule.finish,
			aim = { x = 0, y = 0, z = 1 },
			origin = { x = 0, y = 0, z = 0 },
		}
		local n = if move.delivery.kind == "Volley" then move.delivery.params.count else 1
		local handle = L.start(env.lifetimes, a, self.now, n, 1)
		methods.start(handle)
		local kind = move.delivery.kind
		if kind == "Zone" then
			methods.zone(player, character, move, V.zero, V.zAxis, self.now, handle)
		elseif kind == "Burst" then
			methods.burst(player, character, move, V.zAxis, handle)
		elseif kind == "Volley" then
			methods.volley(player, character, move, V.zero, V.zAxis, handle)
		else
			methods.shot(player, character, move, V.zero, V.zAxis, handle)
		end
		return handle, move
	end
	h.env, h.player, h.character, h.methods = env, player, character, methods
	return h
end
local cases = {
	["configured cap bounds notification memory but not zone damage"] = function()
		local h = harness()
		for _ = 1, Config.CastContact.capacity + 3 do
			h:target()
		end
		local handle, move = h:cast("move.rime.fall")
		local ledger = h.methods.ledgers[handle]
		h.now += move.delivery.params.delay
		h.heartbeat(move.delivery.params.delay)
		assert(ledger.count == Config.CastContact.capacity and #h.contacts == ledger.count)
		assert(h.damage == Config.CastContact.capacity + 3 and h.hits == h.damage)
		h.now = 120
		h.heartbeat(20)
		assert(h.damage == (Config.CastContact.capacity + 3) * move.delivery.params.ticks)
		assert(#h.contacts == Config.CastContact.capacity and ledger.closed and next(ledger.entries) == nil)
	end,
	["zero-damage effect contact remains valid"] = function()
		local h = harness()
		h.amount = 0
		h:target()
		h:cast("move.rime.needle")
		h.now += 0.1
		h.heartbeat(0.1)
		assert(h.damage == 1 and h.hits == 1 and #h.contacts == 1 and h.contacts[1].amount == 0)
	end,

	["contacts preserve authoritative payload and close before terminal for every delivery"] = function()
		for _, id in { "move.rime.needle", "move.rime.shard_fan", "move.rime.fall", "move.rime.shatter" } do
			local h = harness()
			h:target()
			local handle, move = h:cast(id)
			local ledger = h.methods.ledgers[handle]
			h.now += 0.5
			if #h.pending > 0 then
				h.pending[1]()
			else
				h.heartbeat(0.5)
			end
			h.now = 120
			h.heartbeat(20)
			assert(#h.contacts == h.damage and h.hits == h.damage and h.damage > 0)
			local seen = {}
			for i, c in h.contacts do
				assert(c.castId == handle.acceptance.castId and c.ordinal == i)
				assert(c.resource >= 1 and c.resource <= handle.resources and c.targetKey ~= "")
				assert(c.amount == 4 and c.at >= 10000.5 and c.at <= 10020)
				assert(typeof(c.position) == "Vector3" and typeof(c.direction) == "Vector3")
				assert(table.isfrozen(c) and not pcall(function()
					c.amount = 99
				end))
				local key = c.resource .. ":" .. c.tick .. ":" .. c.targetKey
				assert(not seen[key])
				seen[key] = true
				if move.delivery.kind ~= "Zone" then
					assert(c.tick == 1)
				end
			end
			assert(ledger.closed and next(ledger.entries) == nil and h.methods.ledgers[handle] == nil)
			assert(h.events[#h.events] == "terminal" and #h.terminals == 1)
			h.heartbeat(0)
			if #h.pending > 0 then
				h.pending[1]()
			end
			assert(#h.contacts == h.damage and #h.terminals == 1)
		end
	end,
	["zone contact ticks never restart across regular and stalled heartbeats"] = function()
		local h = harness()
		h:target()
		h:target()
		local handle, move = h:cast("move.rime.fall")
		local p = move.delivery.params
		h.now = 100 + p.delay
		h.heartbeat(p.delay)
		assert(h.damage == 2 and #h.contacts == 2)
		h.heartbeat(0)
		assert(h.damage == 2)
		h.now = 100 + p.delay + p.duration / (p.ticks - 1)
		h.heartbeat(p.duration / (p.ticks - 1))
		assert(h.damage == 4 and h.contacts[3].tick == 2)
		h.now = 120
		h.heartbeat(20)
		for i, c in h.contacts do
			assert(c.tick == math.ceil(i / 2) and c.resource == 1 and c.ordinal == i)
		end
		assert(#h.contacts == 2 * p.ticks and handle.terminal.reason == "completed")
	end,
	["notification pressure never gates damage or legacy FX in any delivery"] = function()
		for _, id in { "move.rime.needle", "move.rime.shard_fan", "move.rime.fall", "move.rime.shatter" } do
			local h = harness()
			for _ = 1, 5 do
				h:target()
			end
			local handle = h:cast(id)
			local ledger = h.methods.ledgers[handle]
			-- A legitimate prior notification fills the ledger. All subsequent effects still run.
			ledger.capacity = 1
			local C = require("../src/shared/CastContacts")
			assert(C.record(ledger, {
				resource = 1,
				tick = 1,
				targetKey = "prior",
				at = 10000,
				position = { x = 0, y = 0, z = 0 },
				direction = { x = 0, y = 0, z = 1 },
				amount = 4,
			}) == "stored")
			h.now += 0.5
			if #h.pending > 0 then
				h.pending[1]()
			else
				h.heartbeat(0.5)
			end
			h.now = 120
			h.heartbeat(20)
			local control = harness()
			for _ = 1, 5 do
				control:target()
			end
			control:cast(id)
			control.now += 0.5
			if #control.pending > 0 then
				control.pending[1]()
			else
				control.heartbeat(0.5)
			end
			control.now = 120
			control.heartbeat(20)
			assert(h.damage == control.damage and h.damage > 0 and h.hits == control.hits)
			assert(#h.contacts == 0 and ledger.closed and next(h.methods.ledgers) == nil)
		end
	end,
	["actual post-hit callback suppresses duplicates and late work without changing immutable record"] = function()
		local h = harness()
		local target = h:target()
		local handle, move = h:cast("move.rime.fall")
		local ledger = h.methods.ledgers[handle]
		h.now += move.delivery.params.delay
		h.heartbeat(move.delivery.params.delay)
		local first = h.contacts[1]
		h.now += 0.01
		h.methods.contact(handle, 1, 1, target, V.new(9, 9, 9), V.xAxis, 99)
		assert(#h.contacts == 1 and h.damage == 1 and first.amount == 4 and first.position == V.zero)
		L.terminate(h.env.lifetimes, handle, "cancelled", h.now)
		h.methods.contact(handle, 1, 2, target, V.zero, V.zAxis, 4)
		assert(#h.contacts == 1 and h.damage == 1 and ledger.closed)
	end,
	["misses and blocked targets never send confirmed contacts"] = function()
		for _, id in { "move.rime.needle", "move.rime.shard_fan", "move.rime.fall", "move.rime.shatter" } do
			for _, blocked in { false, true } do
				local h = harness()
				if blocked then
					h:target()
					h.blocked = true
				end
				h:cast(id)
				h.now += 0.5
				if #h.pending > 0 then
					h.pending[1]()
				else
					h.heartbeat(0.5)
				end
				h.now = 120
				h.heartbeat(20)
				assert(h.damage == 0 and h.hits == 0 and #h.contacts == 0 and next(h.methods.ledgers) == nil)
			end
		end
	end,
	["target respawns use fresh server identity without changing old contact"] = function()
		local h = harness()
		local old = h:target()
		local handle, move = h:cast("move.rime.fall")
		h.now += move.delivery.params.delay
		h.heartbeat(move.delivery.params.delay)
		local first = h.contacts[1]
		h.targets = {}
		old.Parent = nil
		h:target() -- same mock id/name, new model instance
		h.now = 120
		h.heartbeat(20)
		assert(h.contacts[2].targetKey ~= first.targetKey and h.contacts[2].castId == first.castId)
		assert(h.damage == move.delivery.params.ticks and handle.terminal ~= nil)
	end,

	["zone survives slot/death/leave, applies owed ticks once before single completion"] = function()
		local h = harness()
		h:target()
		local handle, move = h:cast("move.rime.fall")
		h.player.ActiveSlot = 7
		h.character.alive = false
		h.player.Character = { root = { Position = V.new(999, 0, 0) }, alive = true }
		h.player.Parent = nil
		h.now = 120 -- stall beyond deadline: all owed zone ticks precede expiry
		h.heartbeat(20)
		assert(h.damage == move.delivery.params.ticks and h.hits == h.damage)
		assert(#h.env.zones == 0 and h.env.lifetimes.count == 0)
		assert(handle.terminal.reason == "completed" and handle.acceptance.characterKey == "old")
		h.heartbeat(0)
		assert(h.damage == move.delivery.params.ticks and #h.terminals == 1)
		assert(#h.contacts == h.damage)
	end,
	["volley shares identity but all shards retire; per-target cap unchanged"] = function()
		local h = harness()
		h:target()
		local handle, move = h:cast("move.rime.shard_fan")
		for i, shot in h.env.shots do
			assert(shot.lifetime == handle and shot.resource == i)
		end
		h.player.Parent = nil
		h.character.alive = false
		h.now += 0.1
		h.heartbeat(0.1)
		assert(h.damage == move.delivery.params.perTargetCap and handle.terminal == nil)
		h.now += 2
		h.heartbeat(2)
		assert(handle.terminal.reason == "completed" and #h.env.shots == 0)
		local damage = h.damage
		h.heartbeat(2)
		assert(h.damage == damage and #h.terminals == 1 and #h.contacts == damage)
	end,
	["single projectile completes once on hit without duplicate damage"] = function()
		local h = harness()
		h:target()
		local handle = h:cast("move.rime.needle")
		h.now += 0.1
		h.heartbeat(0.1)
		assert(h.damage == 1 and handle.terminal.reason == "completed")
		h.heartbeat(1)
		assert(h.damage == 1 and h.env.lifetimes.count == 0 and #h.terminals == 1)
	end,
	["burst cannot rebound onto respawn, dead or departed original caster"] = function()
		for _, cause in { "respawn", "dead", "leave" } do
			local h = harness()
			h:target()
			local handle = h:cast("move.rime.shatter")
			if cause == "respawn" then
				h.player.Character = { alive = true, root = h.character.root }
			elseif cause == "dead" then
				h.character.alive = false
			else
				h.player.Parent = nil
			end
			h.now += 0.5
			h.pending[1]()
			assert(h.damage == 0 and handle.terminal.reason == "caster_lost")
			h.pending[1]()
			assert(h.damage == 0 and h.env.lifetimes.count == 0 and #h.terminals == 1 and #h.contacts == 0)
		end
	end,
	["burst allows slot switch, successful callback once and ignores late expired callback"] = function()
		local h = harness()
		h:target()
		local handle = h:cast("move.rime.shatter")
		h.player.ActiveSlot = 7
		h.now += 0.5
		h.pending[1]()
		h.pending[1]()
		assert(h.damage == 1 and handle.terminal.reason == "completed" and #h.terminals == 1)
		local late = harness()
		late:target()
		local expired = late:cast("move.rime.shatter")
		late.now = 120
		late.heartbeat(20)
		late.pending[1]()
		assert(late.damage == 0 and expired.terminal.reason == "expired" and #late.terminals == 1)
		local beforeHeartbeat = harness()
		beforeHeartbeat:target()
		local stalled = beforeHeartbeat:cast("move.rime.shatter")
		beforeHeartbeat.now = 120
		beforeHeartbeat.pending[1]()
		assert(beforeHeartbeat.damage == 0 and stalled.terminal.reason == "expired" and #beforeHeartbeat.terminals == 1)
	end,
}
local count = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	count += 1
end
print("cast lifecycle: " .. count .. " real-source cases PASS")
