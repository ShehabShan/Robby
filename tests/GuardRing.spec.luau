local GuardRing = require("../src/shared/Deliveries/GuardRing")
local Config = require("../src/shared/Config")

local P = {
	count = 4,
	radius = 5,
	duration = 3,
	spin = math.pi,
	touchRadius = 1.5,
	damage = 18,
	stunSeconds = 0.3,
	knockback = 30,
	speedMult = 1.3,
	speedSeconds = 1.5,
}

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, msg: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{msg}: expected {expected}, got {actual}`, 2)
	end
end

return {
	["guard ring: valid params need radius > 3 studs and a speed boost >= 1"] = function()
		eq(GuardRing.validParams(P), true, "spec params")
		eq(GuardRing.validParams(table.clone(P) :: any), true, "clone")
		local small = table.clone(P) :: any
		small.radius = 3
		eq(GuardRing.validParams(small), false, "old 3-stud radius refused")
		local slow = table.clone(P) :: any
		slow.speedMult = 0.8
		eq(GuardRing.validParams(slow), false, "slowdown refused")
		eq(GuardRing.validParams(nil), false, "nil")
	end,
	["guard ring: config tuning is valid"] = function()
		eq(GuardRing.validParams(Config.Abilities.GuardRing), true, "Config.Abilities.GuardRing")
		eq(Config.Abilities.GuardRing.damage, Config.Abilities.CrescentCut.baseDamage, "damage = one Cut hit")
	end,
	["guard ring: follows caster (blades centred on the caster's current position)"] = function()
		local s = GuardRing.new(P, 0)
		local a = GuardRing.blades(s, P, 0, 0, 0, 0)
		near(a[1].x, 5, "blade 1 on aim at radius")
		near(a[1].z, 0, "blade 1 z")
		local b = GuardRing.blades(s, P, 100, -40, 0, 0)
		near(b[1].x, 105, "moved with caster x")
		near(b[1].z, -40, "moved with caster z")
		eq(#b, 4, "count blades")
		local c = GuardRing.blades(s, P, 0, 0, 0, 0.5) -- spin pi/s → quarter turn after 0.5 s
		near(c[1].x, 0, "orbit x")
		near(c[1].z, 5, "orbit z")
	end,
	["guard ring: shatters on first touch, once"] = function()
		local s = GuardRing.new(P, 0)
		eq(GuardRing.touch(s, P, 0, 0, { { key = "far", x = 20, z = 0 } }, 0.1), nil, "far enemy does not touch")
		local hit = GuardRing.touch(s, P, 0, 0, { { key = "far", x = 20, z = 0 }, { key = "near", x = 0, z = 6 } }, 0.2)
		assert(hit, "touch shatters")
		eq(hit.key, "near", "nearest in reach")
		eq(hit.damage, 18, "one Cut hit")
		eq(hit.interrupt, true, "interrupts")
		near(hit.pushZ, 30, "knocked away from caster")
		near(hit.pushX, 0, "push x")
		near(hit.speedMult, 1.3, "caster speed boost")
		eq(s.shattered, true, "shattered")
		eq(GuardRing.touch(s, P, 0, 0, { { key = "near", x = 0, z = 6 } }, 0.3), nil, "no second shatter")
	end,
	["guard ring: touch uses the moving centre"] = function()
		local s = GuardRing.new(P, 0)
		eq(GuardRing.touch(s, P, 0, 0, { { key = "e", x = 50, z = 0 } }, 0.1), nil, "enemy far from start")
		assert(GuardRing.touch(s, P, 45, 0, { { key = "e", x = 50, z = 0 } }, 0.2), "caster walked into it")
	end,
	["guard ring: expires after duration without a touch"] = function()
		local s = GuardRing.new(P, 10)
		eq(GuardRing.isOpen(s, 12.9), true, "open before 3 s")
		eq(GuardRing.isOpen(s, 13), false, "closed at 3 s")
		eq(GuardRing.touch(s, P, 0, 0, { { key = "e", x = 0, z = 1 } }, 13.1), nil, "expired ring cannot shatter")
		eq(s.shattered, false, "not shattered")
	end,
}
