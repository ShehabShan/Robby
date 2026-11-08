--!strict
local MoveRules = require("../src/shared/MoveRules")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local T: MoveRules.Tuning = Config.MoveRules
local DT = 0.01
local AIR: MoveRules.Context = { grounded = false, clearance = 20, stamina = 100 }
local GROUND: MoveRules.Context = { grounded = true, clearance = 0, stamina = 100 }

local function run(s: MoveRules.State, seconds: number, c: MoveRules.Context): (MoveRules.State, MoveRules.Result?)
	local fired: MoveRules.Result? = nil
	for _ = 1, math.floor(seconds / DT + 0.5) do
		local r
		s, r = MoveRules.step(T, s, DT, c)
		fired = fired or r
	end
	return s, fired
end

local function jumped(): MoveRules.State
	local s, r = MoveRules.press(T, MoveRules.new(T), "jump", GROUND)
	eq(r, "jump", "ground jump")
	return s
end

return {
	["serverAirDash: 2 charges, 3rd refused until landing (T-059d1)"] = function()
		local l = MoveRules.newAirLedger()
		local c = { grounded = false, clearance = 5, stunned = false, now = 1, slack = 0.05 }
		eq(MoveRules.serverAirDash(T, l, c), true, "1st")
		c.now = 1.3
		eq(MoveRules.serverAirDash(T, l, c), true, "2nd")
		c.now = 1.6
		eq(MoveRules.serverAirDash(T, l, c), false, "3rd refused")
		MoveRules.serverLand(l)
		c.now = 2
		eq(MoveRules.serverAirDash(T, l, c), true, "after landing")
	end,
	["serverAirDash: refuses grounded, stunned, low, too soon"] = function()
		local l = MoveRules.newAirLedger()
		local base = { grounded = false, clearance = 5, stunned = false, now = 1, slack = 0.05 }
		eq(MoveRules.serverAirDash(T, l, table.clone(base)), true)
		local soon = table.clone(base)
		soon.now = 1.05
		eq(MoveRules.serverAirDash(T, l, soon), false, "too soon")
		local g = table.clone(base)
		g.now, g.grounded = 3, true
		eq(MoveRules.serverAirDash(T, l, g), false, "grounded")
		local low = table.clone(base)
		low.now, low.clearance = 3, 2
		eq(MoveRules.serverAirDash(T, l, low), false, "low")
		local st = table.clone(base)
		st.now, st.stunned = 3, true
		eq(MoveRules.serverAirDash(T, l, st), false, "stunned")
		eq(l.used, 1, "refusals do not spend charges")
	end,
	["air dash charges and refresh (T-059a, plan §6.1)"] = function()
		local s, r = jumped(), nil
		s, r = MoveRules.press(T, s, "q", AIR)
		eq(r, "airDash", "1st")
		s, r = MoveRules.press(T, s, "q", AIR)
		eq(r, nil, "no dash during dash")
		s = run(s, T.airDashSeconds + 0.05, AIR)
		eq(s.buffered, nil, "early press expired")
		s, r = MoveRules.press(T, s, "q", AIR)
		eq(r, "airDash", "2nd")
		s = run(s, T.airDashSeconds + 0.05, AIR)
		s, r = MoveRules.press(T, s, "q", AIR)
		eq(r, nil, "3rd refused")
		s = run(s, 0.5, AIR)
		eq(s.charges, 0, "no refresh mid-air")
		s = run(s, DT, GROUND)
		eq(s.mode, "Ground", "landed")
		eq(s.charges, T.airDashCharges, "refresh on grounded tick")
		-- vault refresh, clearance and stamina gates
		local v = MoveRules.enter(T, MoveRules.press(T, jumped(), "q", AIR), "Vault")
		eq(v.charges, T.airDashCharges, "vault refresh")
		local _, low = MoveRules.press(T, jumped(), "q", { grounded = false, clearance = 2, stamina = 100 })
		eq(low, nil, "needs clearance")
		local _, tired = MoveRules.press(T, jumped(), "q", { grounded = false, clearance = 20, stamina = 5 })
		eq(tired, nil, "needs stamina")
		local _, g = MoveRules.press(T, MoveRules.new(T), "q", GROUND)
		eq(g, "groundQ", "ground Q delegates")
	end,

	["slam rules (plan §6.2)"] = function()
		local s, r = MoveRules.press(T, jumped(), "slam", { grounded = false, clearance = 5, stamina = 100 })
		eq(r, nil, "too low")
		s, r = MoveRules.press(T, jumped(), "slam", AIR)
		eq(r, "slam", "slam")
		eq(MoveRules.slamHovering(T, s), true, "hover")
		s = run(s, T.slamHover + DT, AIR)
		eq(MoveRules.slamHovering(T, s), false, "falling")
		local _, q = MoveRules.press(T, s, "q", AIR)
		eq(q, nil, "slam is committed / locks air dash")
		s = run(s, 1, AIR)
		eq(s.mode, "Slam", "stays slam until contact")
		s = run(s, DT, GROUND)
		eq(s.mode, "Land", "contact -> recovery")
		s = run(s, T.slamRecovery + DT, GROUND)
		eq(s.mode, "Ground", "recovered")
		-- air dash -> slam only after airDashToSlam
		local d = MoveRules.press(T, jumped(), "q", AIR)
		local _, early = MoveRules.press(T, d, "slam", AIR)
		eq(early, nil, "too early after air dash")
		local _, late = MoveRules.press(T, run(d, T.airDashToSlam + DT, AIR), "slam", AIR)
		eq(late, "slam", "slam after air dash")
	end,

	["slam kinematics from 12 studs, horizontal cap and shake (T-059e, plan §6.2)"] = function()
		-- Start slam at 12 studs clearance with 20 studs/s forward speed
		local s, r = MoveRules.press(T, jumped(), "slam", { grounded = false, clearance = 12, stamina = 100 })
		eq(r, "slam", "slam starts >= 6 studs")
		local hvx, hvy, hvz = MoveRules.slamVelocity(T, s, 20, 0)
		eq(hvx, 6, "horizontal speed kept at 30 %")
		eq(hvy, 0, "hover vy = 0")
		eq(hvz, 0, "hover vz = 0")
		-- Hover lasts 0.08 s
		s = run(s, T.slamHover, { grounded = false, clearance = 12, stamina = 100 })
		local fvx, fvy, _ = MoveRules.slamVelocity(T, s, 20, 0)
		eq(fvx, 6, "horizontal speed still 30 % while falling")
		eq(fvy, -90, "straight-down 90 studs/s after hover")
		-- Simulate drop from 12 studs at 90 studs/s: contact in <= 0.25 s after hover
		local clearance = 12
		local postHover = 0
		while clearance > 0 do
			local _, vy, _ = MoveRules.slamVelocity(T, s, 20, 0)
			clearance = math.max(0, clearance + vy * DT)
			postHover += DT
			s = MoveRules.step(T, s, DT, { grounded = clearance <= 0, clearance = clearance, stamina = 100 })
		end
		eq(postHover <= 0.25, true, "12-stud drop contacts in <= 0.25 s after hover")
		eq(s.mode, "Land", "contact transitions to Land")
		-- Fixed 0.15 s recovery
		s = run(s, T.slamRecovery - DT, GROUND)
		eq(s.mode, "Land", "still recovering before 0.15 s")
		s = run(s, 2 * DT, GROUND)
		eq(s.mode, "Ground", "recovered after 0.15 s")
		-- Contact shake decays cleanly to 0 at 0.20 s
		eq(MoveRules.slamShakeAmplitude(T, 0) > 0, true, "shake starts > 0")
		eq(MoveRules.slamShakeAmplitude(T, 0.2), 0, "shake ends at 0.2 s")
	end,

	["buffer and coyote (plan §6.3, §6.4)"] = function()
		-- jump pressed shortly before slam recovery ends fires on the first legal tick
		local land = run(MoveRules.press(T, jumped(), "slam", AIR), DT, GROUND)
		eq(land.mode, "Land", "recovering")
		local b = MoveRules.press(T, run(land, T.slamRecovery - 0.1, GROUND), "jump", GROUND) -- 0.10 s before
		eq(b.buffered, "jump", "buffered")
		local _, fired = run(b, T.slamRecovery + 2 * DT, GROUND)
		eq(fired, "jump", "buffered jump fired")
		-- buffer expires after bufferSeconds
		local land2 = run(MoveRules.press(T, jumped(), "slam", AIR), DT, GROUND)
		local b2 = MoveRules.press(T, land2, "jump", GROUND)
		local e = run(b2, T.bufferSeconds + DT, { grounded = false, clearance = 0, stamina = 0 })
		eq(e.buffered, nil, "expired")
		-- latest press wins
		local lw = MoveRules.press(T, MoveRules.press(T, land, "jump", GROUND), "q", GROUND)
		eq(lw.buffered, "q", "latest wins")
		-- coyote: walked off an edge
		local edge = run(MoveRules.new(T), DT, AIR)
		eq(edge.mode, "Air", "fell off")
		local _, cj = MoveRules.press(T, run(edge, 0.07, AIR), "jump", AIR)
		eq(cj, "jump", "coyote jump")
		local _, late = MoveRules.press(T, run(edge, 0.15, AIR), "jump", AIR)
		eq(late, nil, "coyote over")
		local _, dj = MoveRules.press(T, jumped(), "jump", AIR)
		eq(dj, nil, "no free double jump")
	end,

	["dash/slide jump and carry (plan §2, §6.5)"] = function()
		local c: MoveRules.Context = { grounded = true, clearance = 0, stamina = 100, dashSeconds = 0.2 }
		local d = MoveRules.enter(T, MoveRules.new(T), "Dash")
		local d2, early = MoveRules.press(T, d, "jump", c)
		eq(early, nil, "dash jump too early")
		local _, fired = run(d2, 0.13, c)
		eq(fired, "jump", "buffered dash jump fires at 60 %")
		local _, sj = MoveRules.press(T, MoveRules.enter(T, MoveRules.new(T), "Slide"), "jump", GROUND)
		eq(sj, "jump", "slide jump")
		local x, z = MoveRules.carry(T, 18, 24) -- 30
		eq(x, 18, "under cap kept")
		eq(z, 24, "under cap kept z")
		local cx, cz = MoveRules.carry(T, 0, -40)
		eq(cx, 0, "direction kept")
		eq(cz, -T.carryCap, "capped")
	end,

	["jump config (T-059c)"] = function()
		eq(Config.Jump.height, 7.2, "explicit Roblox-default height")
	end,
}
