-- Real prepared non-cast listener and real registry; only networking mocked.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local Fx = require("../src/shared/FxRegistry")
local Config = require("../src/shared/Config")
local All = require("../src/shared/Content/All")
local Registry = require("../src/shared/Registry")
local feelSource = fs.readFile("src/client/HitFeel.luau")
local generic = assert(feelSource:match('HitFeel.GENERIC_ID = "([^"]+)"'))
local source = fs.readFile("src/client/CombatContactClient.luau")
local function fixture()
	local f = { callbacks = {}, live = 0, errors = {}, played = {} }
	local fx = Fx.new()
	Fx.register(fx, generic, function(ctx)
		if f.renderFail then
			error("render fault")
		end
		table.insert(f.played, ctx)
	end)
	local net = {
		HitFx = {
			On = function(fn)
				if f.startFail then
					error("subscription fault")
				end
				f.live += 1
				table.insert(f.callbacks, fn)
				return function()
					f.live -= 1
					if f.stopFail then
						error("unsubscribe fault")
					end
				end
			end,
		},
	}
	local modules = { FxRegistry = Fx, HitFeel = { GENERIC_ID = generic }, Net = net }
	f.client = luau.load(source, {
		injectGlobals = true,
		environment = {
			game = {
				GetService = function()
					return { Shared = { FxRegistry = "FxRegistry" } }
				end,
			},
			script = { Parent = { HitFeel = "HitFeel", Net = "Net" } },
			require = function(id)
				return assert(modules[id])
			end,
			warn = function(problem)
				table.insert(f.errors, problem)
			end,
		},
	})()
	f.fx = fx
	return f
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS combat-contact " .. name)
end
test("inert load, singleton, exact sword payload without current-character lookup", function()
	local f = fixture()
	assert(f.live == 0)
	local stop = f.client.start(f.fx)
	assert(f.client.start(Fx.new()) == stop and f.live == 1)
	local value = { fxId = generic, caster = {}, target = {}, pos = {}, dir = {}, amount = 23 }
	f.callbacks[1](value)
	assert(#f.played == 1)
	for _, field in { "caster", "target", "pos", "dir", "amount" } do
		assert(f.played[1][field] == value[field])
	end
	assert(f.played[1].character == nil)
	stop()
	stop()
	assert(f.live == 0)
end)
test("all actual ability FX and unknown lookalikes are refused, never legacy fallback", function()
	local f = fixture()
	local stop = f.client.start(f.fx)
	local built = Registry.build(All.content(Config))
	local checked = 0
	for _, move in built.moves do
		for _, id in move.fx or {} do
			assert(id ~= generic, "cast content reused the reserved non-cast ID")
			Fx.register(f.fx, id, function()
				table.insert(f.played, { forbidden = id })
			end)
			f.callbacks[1]({ fxId = id })
			checked += 1
		end
	end
	for _, id in { "fx.combat.hit.extra", "fx.combat", "fx.unknown.hit", "", 42, false } do
		f.callbacks[1]({ fxId = id })
	end
	assert(checked > 10 and #f.played == 0 and next(f.fx.missing) == nil)
	stop()
end)
test("failed registration retries; renderer and disconnect errors do not poison future lifetime", function()
	local f = fixture()
	f.startFail = true
	assert(not pcall(f.client.start, f.fx) and f.live == 0)
	f.startFail = false
	local stop = f.client.start(f.fx)
	f.renderFail = true
	assert(pcall(f.callbacks[1], { fxId = generic }) and #f.played == 0)
	f.renderFail, f.stopFail = false, true
	stop()
	assert(f.live == 0 and #f.errors == 1)
	f.stopFail = false
	local nextStop = f.client.start(f.fx)
	stop()
	f.callbacks[1](nil) -- old callback must return before accessing a payload
	assert(f.live == 1 and #f.played == 0)
	f.callbacks[2]({ fxId = generic, amount = 0 })
	assert(#f.played == 1 and f.played[1].amount == 0)
	nextStop()
	assert(f.live == 0)
end)
test("one hundred listener replacements preserve only the active registry", function()
	local f = fixture()
	local stale = function() end
	for i = 1, 100 do
		local stop = f.client.start(f.fx)
		stale()
		assert(f.live == 1)
		f.callbacks[i]({ fxId = generic, amount = i })
		assert(#f.played == i)
		stop()
		assert(f.live == 0)
		stale = stop
	end
end)
test("source boundary remains reserved to non-cast combat, prepared adapter not started live", function()
	local combat = fs.readFile("src/server/CombatService.luau")
	assert(combat:find('local HIT_FX = "' .. generic .. '"', 1, true))
	assert(combat:find("fxId = HIT_FX", 1, true))
	assert(not fs.readFile("src/server/Abilities.luau"):find(generic, 1, true))
	local init = fs.readFile("src/client/init.client.luau")
	assert(not init:find("script.CombatContactClient", 1, true))
	assert(not init:find("script.CastPresentationClient", 1, true))
end)
print("COMBAT CONTACT: PASS (" .. count .. " cases)")
