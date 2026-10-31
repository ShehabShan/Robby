local Tx = require("../src/shared/CastTransaction")
local Stance = require("../src/shared/Stance")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local built = Registry.build(All.content(Config))
local kit = Stance.kit(built.kith["kith.rimeshard"], built.moves)
local cfg = {
	chain = Config.Abilities.Rimeshard.needle.chain,
	finisherRecovery = Config.Abilities.Rimeshard.needle.finisherRecovery,
}
local function setup(step)
	local s = Stance.new()
	Stance.set(s, true)
	s.chain.step, s.chain.lastAt = step or 0, if step then 100 else -math.huge
	return s, { qi = 100, hp = 100, strain = 0, strainMax = 100, cooldowns = {}, uses = {} }
end
local function snapshot(s, c)
	return {
		on = s.on,
		step = s.chain.step,
		last = s.chain.lastAt,
		finisher = s.finisherAt,
		qi = c.qi,
		hp = c.hp,
		strain = c.strain,
		cooldowns = table.clone(c.cooldowns),
		uses = table.clone(c.uses),
	}
end
local function same(a, b)
	for k, v in a do
		if type(v) == "table" then
			same(v, b[k])
			same(b[k], v)
		else
			assert(v == b[k], k)
		end
	end
end
local function pay(s, c, id, t)
	return Tx.pay(s, cfg, kit, c, built.moves[id], t)
end
return {
	["cooling needle does not advance chain; ready retry does"] = function()
		local s, c = setup()
		c.cooldowns[kit.chain] = 101
		local before = snapshot(s, c)
		local ok, reason = pay(s, c, kit.chain, 100)
		assert(not ok and reason == "cooldown")
		same(before, snapshot(s, c))
		c.cooldowns[kit.chain] = 100
		assert(pay(s, c, kit.chain, 100))
		assert(s.chain.step == 1)
	end,
	["unpaid shot2 special keeps cancel opportunity"] = function()
		local s, c = setup(2)
		c.qi = 0
		local before = snapshot(s, c)
		assert(not pay(s, c, kit.specials[1], 100.01))
		same(before, snapshot(s, c))
		c.qi = 100
		assert(pay(s, c, kit.specials[1], 100.01))
		assert(s.chain.step == 0)
	end,
	["cooldown rejection preserves chain and every resource"] = function()
		local s, c = setup(2)
		c.cooldowns[kit.specials[1]] = 120
		local before = snapshot(s, c)
		local ok, reason = pay(s, c, kit.specials[1], 100.01)
		assert(not ok and reason == "cooldown")
		same(before, snapshot(s, c))
	end,
	["wrong finisher and shot1 cancel leave payment untouched"] = function()
		for _, case in { { 0, kit.finisher, 101 }, { 1, kit.specials[1], 100.01 } } do
			local s, c = setup(case[1])
			local before = snapshot(s, c)
			local ok, reason = pay(s, c, case[2], case[3])
			assert(not ok and reason == "stance")
			same(before, snapshot(s, c))
		end
	end,
	["unpaid finisher preserves step2 and pause; accepted pause unchanged"] = function()
		local s, c = setup(2)
		c.qi = 0
		local before = snapshot(s, c)
		assert(not pay(s, c, kit.finisher, 100.25))
		same(before, snapshot(s, c))
		c.qi = 100
		assert(pay(s, c, kit.finisher, 100.25))
		assert(s.finisherAt == 100.25 and s.chain.step == 0)
		assert(not pay(s, c, kit.chain, 101))
		assert(pay(s, c, kit.chain, 101.46))
	end,
	["all payment failure categories leave nested tables unchanged"] = function()
		for _, kind in { "strain", "hp", "uses", "badCost" } do
			local s, c = setup(2)
			local move = table.clone(built.moves[kit.specials[1]])
			move.costs = if kind == "strain"
				then { strain = 101 }
				elseif kind == "hp" then { hp = 100 }
				elseif kind == "uses" then { uses = 0 }
				else { qi = -1 }
			local before = snapshot(s, c)
			local ok, reason = Tx.pay(s, cfg, kit, c, move, 100.01)
			assert(not ok and reason == kind)
			same(before, snapshot(s, c))
		end
	end,
	["fixed moves do not touch stance and commit all payment fields"] = function()
		local s, c = setup(2)
		local move = table.clone(built.moves["move.wind_step"])
		move.costs = { qi = 3, strain = 4, hp = 5, uses = 2 }
		local cds, uses = c.cooldowns, c.uses
		c.cooldowns.other, c.uses.other = 999, 2
		assert(Tx.pay(nil, nil, nil, c, move, 100))
		assert(s.chain.step == 2 and c.qi == 97 and c.strain == 4 and c.hp == 95)
		assert(c.cooldowns == cds and c.uses == uses)
		assert(c.cooldowns.other == 999 and c.uses.other == 2 and c.uses[move.id] == 1)
	end,
	["invalid internal clock/config fails without mutation"] = function()
		local s, c = setup()
		local before = snapshot(s, c)
		for _, now in { 0 / 0, math.huge, -math.huge } do
			assert(not pay(s, c, kit.chain, now))
		end
		assert(not Tx.pay(s, nil, kit, c, built.moves[kit.chain], 100))
		same(before, snapshot(s, c))
	end,
}
