--!strict
local Dash = require("../src/shared/Dash")
local Config = require("../src/shared/Config")

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

local T: Dash.Tuning = Config.Dash
local ok: Dash.Context = { stamina = 100, stunned = false }

local function run(s: Dash.State, seconds: number): Dash.State
	local n = math.ceil(seconds / 0.01)
	for _ = 1, n do
		s = Dash.step(T, s, 0.01)
	end
	return s
end

return {
	["dash rules (T-058d)"] = function()
		-- classify
		eq(Dash.classify(T, 0, -1, 0, -1), "forward", "same dir")
		eq(Dash.classify(T, 0, -1, 0, 1), "back", "opposite")
		eq(Dash.classify(T, 0, -1, 1, 0), "side", "right")
		eq(Dash.classify(T, 0, -1, -1, 0), "side", "left")
		eq(Dash.classify(T, 0, -1, 0, 0), "back", "no input = back-step")
		eq(Dash.classify(T, 0, -1, 0.3, -1), "forward", "slightly off forward")

		-- Q chooses slide only when sprinting forward fast
		eq(Dash.qAction(T, true, 24, "forward"), "slide", "sprint fwd slides")
		eq(Dash.qAction(T, true, 24, "side"), "dash", "sprint side dashes")
		eq(Dash.qAction(T, false, 18, "forward"), "dash", "jog fwd dashes")
		eq(Dash.qAction(T, true, 10, "forward"), "dash", "slow sprint dashes")

		-- start + cost + cooldowns
		local s, cost = Dash.start(T, Dash.new(), "side", ok)
		eq(s.kind, "side", "started")
		eq(cost, T.cost, "stamina cost")
		near(s.sideCd, T.side.cooldown, "side cd")
		eq(s.linearCd, 0, "linear cd untouched")
		local s2, cost2 = Dash.start(T, s, "forward", ok)
		eq(cost2, 0, "no dash during dash")
		eq(s2, s, "state unchanged on refuse")

		-- refusals
		local _, c3 = Dash.start(T, Dash.new(), "side", { stamina = 100, stunned = true })
		eq(c3, 0, "stunned refuses")
		local _, c4 = Dash.start(T, Dash.new(), "back", { stamina = T.cost - 1, stunned = false })
		eq(c4, 0, "low stamina refuses")

		-- speed: distance over time
		near(Dash.speed(T, "side"), T.side.distance / T.side.seconds, "side speed")
		near(Dash.speedAt(T, "side", 0), Dash.speed(T, "side"), "burst at start")
		eq(Dash.speedAt(T, "side", T.side.seconds), 0, "zero after burst")
		assert(Dash.speedAt(T, "side", T.side.seconds * 0.95) < Dash.speed(T, "side"), "eases at end")
		assert(Dash.speed(T, "side") < 60, "not Blox-Fruits fast")

		-- distance covered is close to tuning (ease loses a little)
		local dist, e = 0, 0
		while e < T.side.seconds do
			dist += Dash.speedAt(T, "side", e) * 0.001
			e += 0.001
		end
		assert(dist > T.side.distance * 0.85 and dist <= T.side.distance + 0.01, `side distance {dist}`)

		-- i-frames: side only, inside window
		local a = Dash.start(T, Dash.new(), "side", ok)
		eq(Dash.invulnerable(T, a), false, "no i-frame at 0")
		a = run(a, 0.1)
		eq(Dash.invulnerable(T, a), true, "i-frame mid side dash")
		local f = run((Dash.start(T, Dash.new(), "forward", ok)), 0.1)
		eq(Dash.invulnerable(T, f), false, "forward has no i-frames")
		eq(Dash.invulnerable(T, Dash.new()), false, "idle not invulnerable")

		-- ends, then recovery blocks a chain, then side cd blocks, other kind ok after recovery
		local b = run((Dash.start(T, Dash.new(), "side", ok)), T.side.seconds + 0.01)
		eq(b.kind, nil, "dash ended")
		assert(b.recover > 0, "recovery after burst")
		eq(Dash.canDash(T, b, "forward", ok), false, "recovery blocks chain")
		b = run(b, T.recovery + 0.01)
		eq(Dash.canDash(T, b, "forward", ok), true, "other kind after recovery")
		eq(Dash.canDash(T, b, "side", ok), false, "side still on cd")
		b = run(b, T.side.cooldown)
		eq(Dash.canDash(T, b, "side", ok), true, "side cd done")

		-- forward and back share a cooldown
		local fb = run((Dash.start(T, Dash.new(), "forward", ok)), 0.5)
		eq(Dash.canDash(T, fb, "back", ok), false, "fwd/back shared cd")
		eq(Dash.canDash(T, fb, "side", ok), true, "side free after fwd")

		-- stun cancels mid-dash
		local st = Dash.step(T, (Dash.start(T, Dash.new(), "side", ok)), 0.05, true)
		eq(st.kind, nil, "stun cancels dash")

		-- server check
		eq(Dash.serverAllows(T, "side", nil, ok), true, "first dash ok")
		eq(Dash.serverAllows(T, "side", T.side.cooldown - T.serverSlack, ok), true, "within slack ok")
		eq(Dash.serverAllows(T, "side", 0.5, ok), false, "spam refused")
		eq(Dash.serverAllows(T, "back", 1, ok), false, "back cd refused")
		eq(Dash.serverAllows(T, "side", nil, { stamina = 100, stunned = true }), false, "server refuses stunned")
		assert(Dash.guardSpeed(T, "side") > Dash.speed(T, "side"), "guard above dash speed")
		near(Dash.guardSeconds(T, "back"), T.back.seconds + T.serverSlack, "guard window")
		assert(T.slideMinSpeed == Config.Movement.slideMinSpeed, "dash/slide threshold in sync")
	end,
}
