local Config = require("../src/shared/Config")
local Scissor = require("../src/shared/Deliveries/Scissor")
local Volley = require("../src/shared/Deliveries/Volley")
local All = require("../src/shared/Content/All")
local Registry = require("../src/shared/Registry")

local P = { curve = "Scissor", width = 4, crossAt = 20, range = 60, count = 2 }

local function near(actual: number, expected: number, msg: string)
	if math.abs(actual - expected) > 1e-6 then
		error(`{msg}: expected {expected}, got {actual}`, 2)
	end
end

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["scissor: blades launch apart, cross on the aim line, then swap sides"] = function()
		near(Scissor.lateral(-1, 0, P), -4, "left starts left")
		near(Scissor.lateral(1, 0, P), 4, "right starts right")
		near(Scissor.lateral(-1, 20, P), 0, "left crosses")
		near(Scissor.lateral(1, 20, P), 0, "right crosses")
		eq(Scissor.lateral(-1, 30, P) > 0, true, "left ends right")
		eq(Scissor.lateral(1, 30, P) < 0, true, "right ends left")
	end,
	["scissor: the path is smooth through the cross"] = function()
		local s = Scissor.slope(1, 20, P)
		near(Scissor.lateral(1, 20.001, P), s * 0.001, "slope continues past the cross")
		near(Scissor.slope(1, 0, P), 0, "launch runs parallel to the aim")
	end,
	["scissor: point uses the caster's right"] = function()
		-- aim -Z (Roblox forward): right is +X
		local x, z = Scissor.point(1, 0, P, 0, 0, 0, -1)
		near(x, 4, "right blade +X")
		near(z, 0, "at origin")
		local x2, z2 = Scissor.point(-1, 20, P, 10, 5, 0, -1)
		near(x2, 10, "cross on the line")
		near(z2, -15, "20 studs ahead")
	end,
	["scissor: sides and params"] = function()
		eq(Scissor.side(1), -1, "shard 1 left")
		eq(Scissor.side(2), 1, "shard 2 right")
		eq(Scissor.validParams(P), true, "valid")
		eq(
			Scissor.validParams({ curve = "Scissor", width = 4, crossAt = 70, range = 60, count = 2 }),
			false,
			"cross past range"
		)
		eq(Scissor.isScissor({ count = 5 }), false, "plain volley")
	end,
	["scissor: Twin Crescent content is a valid two-blade Scissor volley"] = function()
		local built, errors = Registry.build(All.content(Config))
		eq(#errors, 0, `registry errors: {table.concat(errors, "; ")}`)
		local m = built.moves["move.twin_crescent"]
		eq(m.delivery.kind, "Volley", "kind")
		eq(Volley.validParams(m.delivery.params), true, "volley params")
		eq(Scissor.validParams(m.delivery.params), true, "scissor params")
		eq(m.fx.travel, "fx.twin.travel", "own travel fx")
		local k = built.kith["kith.twin_crescent"]
		eq(k.moves[1], "move.crescent_cut", "keeps Crescent Cut first (left click)")
		eq(k.moves[2], "move.twin_crescent", "Scissor second (Z)")
	end,
	["scissor 3rd blade: both blades reach the cross -> exactly one 3rd blade"] = function()
		local c = Scissor.newCross()
		eq(Scissor.takeThird(c), false, "not before the cross")
		Scissor.reachCross(c, 1)
		eq(Scissor.takeThird(c), false, "one blade is not enough")
		Scissor.reachCross(c, 2)
		eq(Scissor.takeThird(c), true, "both reached")
		eq(Scissor.takeThird(c), false, "only once")
		Scissor.bladeEnded(c, 1) -- ending after the cross changes nothing
		eq(c.blocked, false, "late end does not block")
	end,
	["scissor 3rd blade: one blade blocked -> no 3rd blade"] = function()
		local c = Scissor.newCross()
		Scissor.bladeEnded(c, 2) -- gold blade hit an enemy / wall before the cross
		Scissor.reachCross(c, 1)
		Scissor.reachCross(c, 2)
		eq(Scissor.takeThird(c), false, "blocked blade cancels the 3rd")
		local c2 = Scissor.newCross()
		Scissor.reachCross(c2, 1)
		Scissor.bladeEnded(c2, 2)
		eq(Scissor.takeThird(c2), false, "blocked after the other reached")
	end,
	["scissor 3rd blade: 2x size, 2x travel, 2x damage, no pierce"] = function()
		local built = Registry.build(All.content(Config))
		local m = built.moves["move.twin_crescent"]
		local p = m.delivery.params
		eq(p.maxHits, 1, "scissor blades do not pierce")
		eq(p.stopOnWorld, true, "scissor blades stop on walls")
		local t = Scissor.thirdParams(p, p.third)
		near(t.hitbox.x, p.hitbox.x * 2, "2x hit box x")
		near(t.hitbox.y, p.hitbox.y * 2, "2x hit box y")
		near(t.hitbox.z, p.hitbox.z * 2, "2x hit box z")
		near(t.range, p.range * 2, "2x travel from the cross")
		eq(t.maxHits, 1, "3rd blade does not pierce")
		eq(t.stopOnWorld, true, "3rd blade stops on walls")
		local one = built.effects["effect.twin_crescent.hit"].ops[1].params.base
		local third = built.effects[p.thirdEffect].ops[1].params.base
		near(third, one * 2, "2x damage")
	end,
}
