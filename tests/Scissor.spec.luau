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
}
