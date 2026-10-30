local Config = require("../src/shared/Config")
local BeastBrain = require("../src/shared/BeastBrain")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local fang = Config.Beasts.kinds["beast.mistfang"]
local boar = Config.Beasts.kinds["beast.stonehide"]

local function run(b, k, t0, t1, dist, home)
	local out
	local t = t0
	while t <= t1 + 1e-9 do
		out = BeastBrain.step(b, k, { now = t, targetDist = dist, homeDist = home or 0 })
		t += 0.05
	end
	return out
end

return {
	["beasts: two kinds validate, every telegraph >= 0.4 s"] = function()
		eq(#BeastBrain.validate(Config), 0, "errors")
		eq(Config.Beasts.minTelegraph, 0.4, "min")
		local n = 0
		for _ in Config.Beasts.kinds do
			n += 1
		end
		eq(n, 2, "two beasts")
	end,
	["beasts: idle until a target is in aggro, then chases"] = function()
		local b = BeastBrain.new("beast.mistfang", 0)
		eq(BeastBrain.step(b, fang, { now = 0, targetDist = fang.aggro + 5, homeDist = 0 }).state, "Idle", "far")
		local out = BeastBrain.step(b, fang, { now = 0.1, targetDist = fang.aggro - 1, homeDist = 0 })
		eq(out.state, "Chase", "near")
		eq(out.move, "target", "moves")
	end,
	["beasts: wind-up telegraphs before the strike lands"] = function()
		for _, k in { fang, boar } do
			local b = BeastBrain.new("x", 0)
			BeastBrain.step(b, k, { now = 0, targetDist = k.range - 1, homeDist = 0 })
			eq(b.state, "Windup", "windup")
			local out = run(b, k, 0.05, k.telegraph - 0.06, k.range - 1)
			eq(out.telegraph, true, "telegraph shown")
			eq(out.strike, false, "not yet")
			out = run(b, k, k.telegraph, k.telegraph, k.range - 1)
			eq(out.strike, true, "strike after telegraph")
			eq(b.state, "Recover", "recover")
		end
	end,
	["beasts: cooldown between strikes"] = function()
		local b = BeastBrain.new("x", 0)
		local strikes = 0
		local t = 0
		while t < fang.cooldown * 3 do
			if BeastBrain.step(b, fang, { now = t, targetDist = 3, homeDist = 0 }).strike then
				strikes += 1
			end
			t += 0.05
		end
		eq(strikes <= 3 and strikes >= 2, true, `strikes {strikes}`)
	end,
	["beasts: parry stagger cancels the wind-up"] = function()
		local b = BeastBrain.new("x", 0)
		BeastBrain.step(b, boar, { now = 0, targetDist = 2, homeDist = 0 })
		BeastBrain.stagger(b, 0.3, 1)
		local out = BeastBrain.step(b, boar, { now = 0.9, targetDist = 2, homeDist = 0 })
		eq(out.strike or out.telegraph, false, "no strike while staggered")
		eq(out.state, "Staggered", "staggered")
		eq(BeastBrain.step(b, boar, { now = 1.4, targetDist = 2, homeDist = 0 }).state, "Windup", "fresh windup")
	end,
	["beasts: leash returns home and heals"] = function()
		local b = BeastBrain.new("x", 0)
		BeastBrain.step(b, fang, { now = 0, targetDist = 20, homeDist = 0 })
		local out = BeastBrain.step(b, fang, { now = 1, targetDist = 20, homeDist = fang.leash + 1 })
		eq(out.state, "Return", "return")
		eq(out.move, "home", "go home")
		eq(BeastBrain.step(b, fang, { now = 2, targetDist = 10, homeDist = 30 }).move, "home", "ignores target")
		out = BeastBrain.step(b, fang, { now = 3, targetDist = nil, homeDist = 1 })
		eq(out.heal, true, "heal")
		eq(out.state, "Idle", "idle")
	end,
	["beasts: hit check uses reach and arc"] = function()
		eq(BeastBrain.hits(fang, fang.range, 0.9), true, "front")
		eq(BeastBrain.hits(fang, fang.range, -0.9), false, "behind")
		eq(BeastBrain.hits(boar, boar.range, -0.9), true, "slam all round")
		eq(BeastBrain.hits(boar, boar.range + 3, 1), false, "too far")
	end,
}
