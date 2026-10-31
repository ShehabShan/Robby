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
	local h = { now = 100, pending = {}, damage = 0, hits = 0, fx = 0, targets = {}, serial = 0 }
	local players = {
		GetPlayerFromCharacter = function()
			return nil
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
				return false
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
			return 4
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
	local body = slice("-- Sweeps the projectile", "-- The Kith's Kit")
	local methods = luau.load(
		body
			.. "\nlocal function boot()\n"
			.. heartbeat
			.. "\nboot()\nreturn { shot=pushShot, volley=volleyCast, zone=zoneCast, burst=burstCast }",
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
	h.env, h.player, h.character = env, player, character
	return h
end
local cases = {
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
		assert(h.damage == move.delivery.params.ticks)
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
		assert(h.damage == damage)
	end,
	["single projectile completes once on hit without duplicate damage"] = function()
		local h = harness()
		h:target()
		local handle = h:cast("move.rime.needle")
		h.now += 0.1
		h.heartbeat(0.1)
		assert(h.damage == 1 and handle.terminal.reason == "completed")
		h.heartbeat(1)
		assert(h.damage == 1 and h.env.lifetimes.count == 0)
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
			assert(h.damage == 0 and h.env.lifetimes.count == 0)
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
		assert(h.damage == 1 and handle.terminal.reason == "completed")
		local late = harness()
		late:target()
		local expired = late:cast("move.rime.shatter")
		late.now = 120
		late.heartbeat(20)
		late.pending[1]()
		assert(late.damage == 0 and expired.terminal.reason == "expired")
		local beforeHeartbeat = harness()
		beforeHeartbeat:target()
		local stalled = beforeHeartbeat:cast("move.rime.shatter")
		beforeHeartbeat.now = 120
		beforeHeartbeat.pending[1]()
		assert(beforeHeartbeat.damage == 0 and stalled.terminal.reason == "expired")
	end,
}
local count = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	count += 1
end
print("cast lifecycle: " .. count .. " real-source cases PASS")
