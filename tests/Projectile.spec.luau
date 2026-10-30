local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local Crescent = require("../src/shared/Content/Crescent")
local Projectile = require("../src/shared/Deliveries/Projectile")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local P = { speed = 90, range = 60, maxHits = 2 }

return {
	["projectile: aim validation"] = function()
		eq(Projectile.isValidDirection(1, 0, 0), true)
		eq(Projectile.isValidDirection(0.6, 0, 0.8), true)
		eq(Projectile.isValidDirection(2, 0, 0), false, "not unit")
		eq(Projectile.isValidDirection(0 / 0, 0, 1), false, "NaN")
		eq(Projectile.isValidDirection(math.huge, 0, 0), false, "inf")
		local x, z, ok = Projectile.flatten(3, 4)
		eq(ok, true)
		eq(math.abs(x - 0.6) < 1e-9 and math.abs(z - 0.8) < 1e-9, true)
		local _, _, up = Projectile.flatten(0, 0)
		eq(up, false, "straight up")
	end,

	["projectile: travel stops at range"] = function()
		local s = Projectile.new()
		local a, b = Projectile.step(s, 0.5, P)
		eq(a, 0)
		eq(b, 45)
		local c, d = Projectile.step(s, 0.5, P)
		eq(c, 45)
		eq(d, 60, "clamped")
		eq(s.done, true)
		local e, f = Projectile.step(s, 1, P)
		eq(e, f, "no travel after done")
		local g, h = Projectile.step(Projectile.new(), -1, P)
		eq(g, h, "negative dt")
	end,

	["projectile: hits once per target, stops at maxHits"] = function()
		local s = Projectile.new()
		eq(Projectile.registerHit(s, "a", P), true)
		eq(Projectile.registerHit(s, "a", P), false, "same target")
		eq(Projectile.registerHit(s, "b", P), true)
		eq(s.done, true)
		eq(Projectile.registerHit(s, "c", P), false, "pierce spent")
	end,

	["projectile: params check and Crescent data fit"] = function()
		eq(Projectile.validParams(P), true)
		eq(Projectile.validParams({ speed = 0, range = 60, maxHits = 2 }), false)
		eq(Projectile.validParams({ speed = 90, range = 60 }), false)
		local built = Registry.build(Crescent.content(Config))
		local move = built.moves["move.crescent_cut"]
		eq(move.delivery.kind, "Projectile")
		eq(Projectile.validParams(move.delivery.params), true, "Crescent params")
	end,
}
