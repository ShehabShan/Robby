local Config = require("../src/shared/Config")
local BossBrain = require("../src/shared/BossBrain")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local ID = "boss.mistmaw"
local K = Config.Bosses.kinds[ID]

-- Runs one full attack at point-blank range; returns the attack id that struck and the time after recovery.
local function oneAttack(b: any, t: number, hp: number): (string?, number)
	local struck = nil
	for _ = 1, 400 do
		t += 0.05
		local o = BossBrain.step(b, K, { now = t, targetDist = 1, homeDist = 0, hpFrac = hp })
		if o.strike then
			struck = o.attack
		end
		if struck and o.state == "Chase" then
			break
		end
	end
	return struck, t
end

return {
	["bossbrain: config is valid"] = function()
		eq(#BossBrain.validate(Config.Bosses), 0, "errors")
	end,
	["bossbrain: phase 1 follows the pattern in order and loops"] = function()
		local b = BossBrain.new(ID, 0)
		local t = 0
		for i = 1, #K.pattern + 1 do
			local id
			id, t = oneAttack(b, t, 1)
			eq(id, K.pattern[((i - 1) % #K.pattern) + 1], `attack {i}`)
		end
	end,
	["bossbrain: drops to phase 2 at phase2At and restarts with pattern2"] = function()
		local b = BossBrain.new(ID, 0)
		local o = BossBrain.step(b, K, { now = 0, targetDist = 1, homeDist = 0, hpFrac = K.phase2At })
		eq(o.phaseChanged, true, "changed")
		eq(b.phase, 2, "phase")
		local id = oneAttack(b, 0, K.phase2At)
		eq(id, K.pattern2[1], "first phase-2 attack")
	end,
	["bossbrain: every wind-up lasts at least minTelegraph, also in phase 2"] = function()
		for _, hp in { 1, 0.1 } do
			local b = BossBrain.new(ID, 0)
			local t, start = 0, nil
			for _ = 1, 2000 do
				t += 0.01
				local o = BossBrain.step(b, K, { now = t, targetDist = 1, homeDist = 0, hpFrac = hp })
				if o.telegraph and start == nil then
					start = t
				end
				if o.strike then
					eq(t - (start :: number) >= Config.Bosses.minTelegraph - 0.011, true, `hp {hp}`)
					start = nil
				end
			end
		end
	end,
	["bossbrain: stagger cancels the wind-up without skipping the attack"] = function()
		local b = BossBrain.new(ID, 0)
		BossBrain.step(b, K, { now = 0, targetDist = 1, homeDist = 0, hpFrac = 1 })
		BossBrain.step(b, K, { now = 0.05, targetDist = 1, homeDist = 0, hpFrac = 1 })
		eq(b.state, "Windup", "winding")
		BossBrain.stagger(b, 0.1, 1)
		eq(BossBrain.step(b, K, { now = 0.5, targetDist = 1, homeDist = 0, hpFrac = 1 }).telegraph, false, "frozen")
		eq(BossBrain.nextAttack(b, K), K.pattern[1], "same attack next")
	end,
	["bossbrain: leashing home heals and resets to phase 1"] = function()
		local b = BossBrain.new(ID, 0)
		BossBrain.step(b, K, { now = 0, targetDist = 30, homeDist = 0, hpFrac = 0.2 }) -- chasing, out of reach
		BossBrain.step(b, K, { now = 1, targetDist = 30, homeDist = K.leash + 1, hpFrac = 0.2 })
		local o = BossBrain.step(b, K, { now = 2, targetDist = nil, homeDist = 0, hpFrac = 0.2 })
		eq(o.heal, true, "heal")
		eq(b.phase, 1, "phase reset")
	end,
	["bossbrain: validate catches a fast telegraph and unknown attack"] = function()
		local bad = {
			minTelegraph = 0.4,
			kinds = {
				x = { phase2At = 0.5, attacks = { a = { telegraph = 0.1 } }, pattern = { "a" }, pattern2 = { "zz" } },
			},
		}
		eq(#BossBrain.validate(bad), 2, "two errors")
	end,
	["bossbrain: slam hits all round, bite only in front"] = function()
		eq(BossBrain.hits(K.attacks.slam, 5, -1), true, "slam behind")
		eq(BossBrain.hits(K.attacks.bite, 5, -1), false, "bite behind")
	end,
}
