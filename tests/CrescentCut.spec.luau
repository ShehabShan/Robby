local CrescentCut = require("../src/shared/Kith/CrescentCut")
local Config = require("../src/shared/Config")

local C = Config.Abilities.CrescentCut

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, msg: string?)
	if math.abs(actual - expected) > 1e-6 then
		error(`{msg or "value"}: expected {expected}, got {actual}`, 2)
	end
end

return {
	["damage scales with rank and clamps"] = function()
		near(CrescentCut.damageFor(1, C), 20)
		near(CrescentCut.damageFor(2, C), 25)
		near(CrescentCut.damageFor(9, C), 60)
		near(CrescentCut.damageFor(0, C), 20, "below 1")
		near(CrescentCut.damageFor(99, C), 60, "above 9")
	end,

	["first cast allowed with enough qi"] = function()
		local ok, reason = CrescentCut.tryCast(10, nil, 100, true, C)
		eq(ok, true)
		eq(reason, nil)
	end,

	["cast refused while dead"] = function()
		local _, reason = CrescentCut.tryCast(10, nil, 100, false, C)
		eq(reason, "dead")
	end,

	["cast refused during cooldown, allowed after"] = function()
		local ok, reason = CrescentCut.tryCast(10.5, 10, 100, true, C)
		eq(ok, false)
		eq(reason, "cooldown")
		eq((CrescentCut.tryCast(11.25, 10, 100, true, C)), true, "after cooldown")
	end,

	["cast refused without qi"] = function()
		local _, reason = CrescentCut.tryCast(10, nil, 9, true, C)
		eq(reason, "qi")
	end,

	["direction validation"] = function()
		eq(CrescentCut.isValidDirection(1, 0, 0), true)
		eq(CrescentCut.isValidDirection(0.6, 0, 0.8), true)
		eq(CrescentCut.isValidDirection(5, 0, 0), false, "not unit")
		eq(CrescentCut.isValidDirection(0 / 0, 0, 1), false, "nan")
		eq(CrescentCut.isValidDirection(math.huge, 0, 0), false, "inf")
	end,

	["flatten normalises and rejects vertical"] = function()
		local x, z, ok = CrescentCut.flatten(3, 4)
		eq(ok, true)
		near(x, 0.6)
		near(z, 0.8)
		local _, _, okUp = CrescentCut.flatten(0, 0)
		eq(okUp, false, "vertical")
	end,

	["projectile travels at speed and stops at range"] = function()
		local p = CrescentCut.newProjectile()
		local from, to = CrescentCut.stepProjectile(p, 0.5, C)
		near(from, 0)
		near(to, 45)
		eq(p.done, false)
		from, to = CrescentCut.stepProjectile(p, 0.5, C)
		near(from, 45)
		near(to, 60, "capped at range")
		eq(p.done, true)
		from, to = CrescentCut.stepProjectile(p, 0.5, C)
		near(to - from, 0, "no travel after done")
	end,

	["each target hit once, pierces up to maxHits"] = function()
		local p = CrescentCut.newProjectile()
		eq(CrescentCut.registerHit(p, "a", C), true)
		eq(CrescentCut.registerHit(p, "a", C), false, "same target")
		eq(p.done, false)
		eq(CrescentCut.registerHit(p, "b", C), true)
		eq(p.done, true, "done after 2")
		eq(CrescentCut.registerHit(p, "c", C), false, "third target")
	end,
}
