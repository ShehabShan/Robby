local Stance = require("../src/shared/Stance")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local cfg: Stance.Cfg = { chain = { steps = 3, window = 0.8, recovery = 0.25 }, finisherRecovery = 1.2 }
local NEEDLE, FINISHER = "move.rime.needle", "move.rime.needle_finisher"
local kit: Stance.Kit = {
	chain = NEEDLE,
	finisher = FINISHER,
	specials = { "move.rime.shard_fan", "move.rime.fall", "move.rime.shatter" },
}

local function on(): Stance.State
	local s = Stance.new()
	Stance.toggle(s)
	return s
end

return {
	["kit: the chain move, its _finisher, and the rest as specials"] = function()
		local moves: { [string]: any } = {
			[NEEDLE] = { chain = cfg.chain },
			[FINISHER] = {},
			["move.rime.shard_fan"] = {},
			["move.rime.fall"] = {},
			["move.rime.shatter"] = {},
		}
		local k = Stance.kit(
			{ moves = { NEEDLE, FINISHER, "move.rime.shard_fan", "move.rime.fall", "move.rime.shatter" } },
			moves
		)
		assert(k, "kit")
		eq(k.chain, NEEDLE)
		eq(k.finisher, FINISHER)
		eq(#k.specials, 3, "specials")
		eq(k.specials[1], "move.rime.shard_fan")
		eq(Stance.kit({ moves = { "move.rime.shard_fan" } }, moves), nil, "Kith without a chain move")
	end,
	["off: a press is nil (light chain); toggle turns the Kith chain on"] = function()
		local s = Stance.new()
		eq(s.on, false)
		eq(Stance.press(s, 100, cfg, kit), nil, "off")
		eq(Stance.toggle(s), true)
		eq(Stance.press(s, 100, cfg, kit), NEEDLE)
		eq(Stance.toggle(s), false, "toggle back drops the chain")
		eq(s.chain.step, 0)
	end,
	["on: shots 1-2 are the chain, shot 3 the finisher, then the finisher pause"] = function()
		local s = on()
		eq(Stance.press(s, 100, cfg, kit), NEEDLE, "shot 1")
		eq(Stance.press(s, 100.1, cfg, kit), nil, "recovery")
		eq(Stance.press(s, 100.4, cfg, kit), NEEDLE, "shot 2")
		eq(Stance.press(s, 100.8, cfg, kit), FINISHER, "shot 3")
		eq(Stance.press(s, 101.5, cfg, kit), nil, "finisher pause")
		eq(Stance.press(s, 102.1, cfg, kit), NEEDLE, "chain restarts at shot 1")
		eq(Stance.press(s, 102.5, cfg, kit), NEEDLE, "shot 2 again")
		eq(Stance.press(s, 103.5, cfg, kit), NEEDLE, "window missed: back to shot 1")
	end,
	["specials fire in both stances; non-specials are refused"] = function()
		local s = Stance.new()
		eq(Stance.special(s, 100, cfg, kit, "move.rime.shard_fan"), true, "off")
		eq(Stance.special(s, 100, cfg, kit, NEEDLE), false, "chain move is not a special")
		eq(Stance.special(s, 100, cfg, kit, "move.crescent.cut"), false, "other Kith")
		Stance.toggle(s)
		eq(Stance.special(s, 100, cfg, kit, "move.rime.fall"), true, "on")
	end,
	["shot 2 cancels into a special; shot 1 recovery and the finisher pause do not"] = function()
		local s = on()
		Stance.press(s, 100, cfg, kit)
		eq(Stance.canCancel(s, 100.1, cfg), false, "shot 1")
		eq(Stance.special(s, 100.1, cfg, kit, "move.rime.shatter"), false, "shot 1 recovery")
		Stance.press(s, 100.4, cfg, kit)
		eq(Stance.canCancel(s, 100.5, cfg), true, "shot 2 window")
		eq(Stance.special(s, 100.5, cfg, kit, "move.rime.shatter"), true, "cancel")
		eq(s.chain.step, 0, "chain dropped by the cancel")
		Stance.press(s, 101, cfg, kit)
		Stance.press(s, 101.4, cfg, kit)
		eq(Stance.press(s, 101.8, cfg, kit), FINISHER)
		eq(Stance.special(s, 102.5, cfg, kit, "move.rime.shatter"), false, "finisher pause")
		eq(Stance.special(s, 103.1, cfg, kit, "move.rime.shatter"), true, "pause over")
	end,
	["verify: accepts the machine's move, restores state on a mismatch, passes other Kith moves"] = function()
		local s = on()
		eq(Stance.verify(s, 100, cfg, kit, FINISHER), false, "finisher first is a lie")
		eq(s.chain.step, 0, "state untouched after the lie")
		eq(Stance.verify(s, 100, cfg, kit, NEEDLE), true, "shot 1")
		eq(Stance.verify(s, 100.4, cfg, kit, NEEDLE), true, "shot 2")
		eq(Stance.verify(s, 100.8, cfg, kit, NEEDLE), false, "shot 3 must be the finisher")
		eq(s.chain.step, 2, "still on shot 2")
		eq(Stance.verify(s, 100.8, cfg, kit, FINISHER), true, "finisher")
		eq(Stance.verify(s, 100.9, cfg, kit, "move.crescent.cut"), true, "outside the kit")
		eq(Stance.verify(s, 100.9, cfg, kit, "move.rime.shard_fan"), false, "special during the pause")
		eq(Stance.verify(s, 102.1, cfg, kit, "move.rime.shard_fan"), true, "special after the pause")
	end,
}
