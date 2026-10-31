-- T-042a: execute real client wiring with mocked engine services, NOT a real-client playtest.
-- Kept outside *.spec.luau: these Lune-only imports cannot run in the cloud spec runner.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Fx = require("../src/shared/FxRegistry")
local Shared = {
	Config = Config,
	FxRegistry = Fx,
	CastRequest = require("../src/shared/CastRequest"),
	Stance = require("../src/shared/Stance"),
	RimeFxPlan = require("../src/shared/RimeFxPlan"),
	Deliveries = {
		Projectile = require("../src/shared/Deliveries/Projectile"),
		Zone = require("../src/shared/Deliveries/Zone"),
	},
}
local built = Registry.build(All.content(Config))
local E, V = rb.Enum, rb.Vector3
local inputSource = fs.readFile("src/client/KithInput.luau")
local abilitySource = fs.readFile("src/client/AbilityInput.luau")
local initSource = fs.readFile("src/client/init.client.luau")
local fxSource = fs.readFile("src/client/RimeFx.luau")
local function eq(a, b, label)
	assert(a == b, `{label or "value"}: expected {tostring(b)}, got {tostring(a)}`)
end

local function harness(initial)
	local h = {
		attrs = { ActiveKith = initial, ActiveSlot = 1, SlotCount = 3, Qi = 100, Slot1State = "Ready" },
		bindings = {},
		sent = {},
		selected = {},
		played = {},
		time = 100,
		health = 100,
	}
	local signals = {}
	local root =
		{ AssemblyLinearVelocity = V.zero, Position = V.new(0, 3, 0), CFrame = { LookVector = V.new(0, 0, -1) } }
	local character = {
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
		FindFirstChildOfClass = function()
			return { Health = h.health }
		end,
	}
	local player = {
		Character = character,
		GetAttribute = function(_, name)
			return h.attrs[name]
		end,
		GetAttributeChangedSignal = function(_, name)
			return {
				Connect = function(_, fn)
					signals[name] = fn
				end,
			}
		end,
	}
	local camera = {
		ViewportPointToRay = function()
			return { Origin = V.new(0, 10, 0), Direction = V.new(0, -1, -1).Unit }
		end,
	}
	local cas = {}
	function cas:BindAction(name, fn, touch, ...)
		h.bindings[name] = { fn = fn, touch = touch, keys = { ... }, priority = 2000 }
	end
	function cas:BindActionAtPriority(name, fn, touch, priority, ...)
		self:BindAction(name, fn, touch, ...)
		h.bindings[name].priority = priority
	end
	function cas:UnbindAction(name)
		h.bindings[name] = nil
	end
	function cas:SetTitle(name, title)
		h.bindings[name].title = title
	end
	local services = {
		ContextActionService = cas,
		Players = { LocalPlayer = player },
		ReplicatedStorage = { Shared = Shared },
		UserInputService = {
			GetMouseLocation = function()
				return { X = 100, Y = 100 }
			end,
		},
		Debris = {},
		RunService = {},
		TweenService = {},
	}
	local env = {
		game = {
			GetService = function(_, name)
				assert(services[name], name)
				return services[name]
			end,
		},
		script = { Parent = { AimDir = {
			look = function()
				return V.new(0, 0, -1)
			end,
		}, HitFeel = {} } },
		require = function(module)
			assert(type(module) == "table")
			return module
		end,
		Vector3 = V,
		Color3 = rb.Color3,
		Enum = E,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		workspace = {
			CurrentCamera = camera,
			Raycast = function()
				return { Position = V.new(0, 0, -10) }
			end,
		},
		os = {
			clock = function()
				return h.time
			end,
		},
	}
	local fx = Fx.new()
	local rimeFx = luau.load(fxSource, { environment = env, injectGlobals = true })()
	rimeFx.register(fx) -- actual registrations, not a fabricated list of Rimeshard IDs
	local rime = built.kith["kith.rimeshard"]
	for _, moveId in rime.moves do
		for _, id in built.moves[moveId].fx do
			assert(fx.handlers[id], "actual RimeFx registration missing: " .. id)
		end
	end
	-- Handler bodies need rendering services; spy on dispatch, not visuals/timing.
	for _, id in Fx.missingFor(Fx.new(), built) do
		fx.handlers[id] = function()
			table.insert(h.played, id)
		end
	end
	local input = luau.load(inputSource, { environment = env, injectGlobals = true })()
	-- Execute the real init.client sender seam; both real input modules share it.
	local startAt = assert(initSource:find("local nextCastSeq =", 1, true))
	local endAt = assert(initSource:find("-- Wind Step stays", startAt, true))
	assert(not initSource:find("Net.CastRequest.Fire", endAt, true), "extra unshared cast sender")
	assert(initSource:find("AbilityInput.start(cast,", 1, true))
	assert(initSource:find("KithInput.start(cast,", 1, true))
	env.CastRequest = Shared.CastRequest
	env.Net = {
		CastRequest = {
			Fire = function(v)
				table.insert(h.sent, { id = v.moveId, aim = v.aim, point = v.point, seq = v.seq })
			end,
		},
		Action = {
			Fire = function(v)
				h.actionValue = v
			end,
		},
	}
	local cast =
		luau.load(initSource:sub(startAt, endAt - 1) .. "\nreturn cast", { environment = env, injectGlobals = true })()
	local actionStart = assert(initSource:find("local function action(", 1, true))
	local actionEnd = assert(initSource:find("CombatInput.start(action)", actionStart, true))
	h.action = luau.load(
		initSource:sub(actionStart, actionEnd - 1) .. "\nreturn action",
		{ environment = env, injectGlobals = true }
	)()
	local ability = luau.load(abilitySource, { environment = env, injectGlobals = true })()
	ability.start(
		cast,
		fx,
		built.moves["move.wind_step"],
		{ name = "WindStep", title = "Step", keys = { E.KeyCode.R } }
	)
	input.start(cast, function(slot)
		table.insert(h.selected, slot)
	end, fx, built)
	function h:respawn()
		player.Character = table.clone(character)
	end
	function h:set(name, value)
		self.attrs[name] = value
		if signals[name] then
			signals[name]()
		end
	end
	function h:press(key, state)
		local list = {}
		for _, b in self.bindings do
			if table.find(b.keys, key) then
				table.insert(list, b)
			end
		end
		table.sort(list, function(a, b)
			return a.priority > b.priority
		end)
		for _, b in list do
			if b.fn("test", state or E.UserInputState.Begin, { KeyCode = key }) == E.ContextActionResult.Sink then
				break
			end
		end
	end
	return h
end

local cases = {
	["fixed and slot inputs share identity across slot change and respawn"] = function()
		local h = harness("kith.rimeshard")
		h:press(E.KeyCode.R)
		h:press(E.KeyCode.X)
		h:set("ActiveKith", "kith.crescent")
		h:press(E.UserInputType.MouseButton1)
		h:respawn()
		h.time += 20
		h:press(E.KeyCode.R)
		eq(#h.sent, 4)
		for i, v in h.sent do
			eq(v.seq, i)
		end
		eq(h.sent[1].id, "move.wind_step")
		eq(h.sent[1].point, nil)
		eq(h.sent[2].point, V.new(0, 0, -10))
		eq(h.sent[3].id, "move.crescent_cut")
		h.action("Attack", nil, 900)
		eq(h.actionValue.seq, 900, "Action channel remains caller-owned")
		h:set("ActiveKith", "kith.rimeshard")
		h:press(E.KeyCode.C)
		eq(h.sent[5].seq, 5, "Action did not consume cast identity")
	end,
	["blocked fixed input consumes no cast sequence"] = function()
		local h = harness("kith.rimeshard")
		h.attrs.Qi = 0
		h:press(E.KeyCode.R)
		h.attrs.Qi = 100
		h:press(E.KeyCode.Z)
		eq(h.sent[1].seq, 1)
		h:press(E.KeyCode.R)
		h:press(E.KeyCode.R)
		eq(#h.sent, 2)
		eq(h.sent[2].seq, 2)
	end,
	["Z/X/C send correct moves and play their cast effects"] = function()
		local h = harness("kith.rimeshard")
		for i, key in { E.KeyCode.Z, E.KeyCode.X, E.KeyCode.C } do
			h:press(key)
			local id = built.kith["kith.rimeshard"].moves[i + 2]
			eq(h.sent[i].id, id)
			eq(h.sent[i].seq, i)
			assert(table.find(h.played, built.moves[id].fx.cast), "missing cast FX")
		end
		eq(h.sent[2].point, V.new(0, 0, -10), "Rime Fall point")
	end,
	["late ActiveKith replication binds all specials"] = function()
		local h = harness(nil)
		eq(h.bindings.KithSpecial1, nil)
		h:set("ActiveKith", "kith.rimeshard")
		h:press(E.KeyCode.C)
		eq(h.sent[1].id, "move.rime.shatter")
	end,
	["switching and empty slots remove stale specials"] = function()
		local h = harness("kith.rimeshard")
		h:set("ActiveKith", "kith.crescent")
		eq(h.bindings.KithSpecial2, nil)
		eq(h.bindings.KithSpecial3, nil)
		h:press(E.UserInputType.MouseButton1)
		eq(h.sent[1].id, "move.crescent_cut")
		h:set("ActiveKith", nil)
		h:press(E.KeyCode.Z)
		eq(#h.sent, 1)
	end,
	["cooldown, release, low Qi and Dormant/Exhausted guards"] = function()
		local h = harness("kith.rimeshard")
		h:press(E.KeyCode.Z, E.UserInputState.End)
		eq(#h.sent, 0)
		h:press(E.KeyCode.Z)
		h:press(E.KeyCode.Z)
		eq(#h.sent, 1)
		h.attrs.Qi = 0
		h:press(E.KeyCode.X)
		eq(#h.sent, 1)
		h.attrs.Qi = 100
		for _, state in { "Dormant", "Exhausted" } do
			h.attrs.Slot1State = state
			h:press(E.KeyCode.C)
			eq(#h.sent, 1)
		end
		h.attrs.Slot1State = "Ready"
		h.health = 0
		h:press(E.KeyCode.C)
		eq(#h.sent, 1)
	end,
	["touch callbacks work with Unknown key and slot keys still select"] = function()
		local h = harness("kith.rimeshard")
		for i = 1, 3 do
			local b = h.bindings["KithSpecial" .. i]
			eq(b.touch, true)
			b.fn("touch", E.UserInputState.Begin, { KeyCode = "Unknown" }) -- Lune omits Unknown; the callback must not inspect it.
		end
		eq(#h.sent, 3)
		h:press(E.KeyCode.Two)
		eq(h.selected[1], 2)
	end,
}
local passed = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
end
print(`CLIENT INPUT: PASS ({passed} mocked wiring cases; not a live playtest)`)
