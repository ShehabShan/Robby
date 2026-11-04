--!strict
-- MoveRules (T-059a, D-465): pure movement state machine from `.ai/MOVEMENT_PLAN.md` §2–4 (D-459–D-462).
-- Owns Air / AirDash / Slam / Land, air-dash charges + refresh, coyote time and a one-slot input buffer.
-- Ground speed, slide and the ground Q dash stay in `Movement` / `Dash`; callers report them with `enter`.
-- Numbers come from `Config.MoveRules` (our tuning, not video measurements). No game services here.
local MoveRules = {}

export type Mode = "Ground" | "Slide" | "Dash" | "Air" | "AirDash" | "Slam" | "Land" | "Vault"
export type Action = "jump" | "q" | "slam"
-- What a legal action becomes: a jump, the existing ground Q (slide/dash, decided by `Dash.qAction`),
-- an air dash or a slam.
export type Result = "jump" | "groundQ" | "airDash" | "slam"

export type Tuning = {
	coyoteSeconds: number,
	bufferSeconds: number,
	airDashCharges: number,
	airDashSeconds: number,
	airDashCost: number,
	airDashMinClearance: number,
	airDashToSlam: number,
	slamMinClearance: number,
	slamHover: number,
	slamRecovery: number,
	dashJumpFraction: number,
	carryCap: number,
}

export type State = {
	mode: Mode,
	modeTime: number,
	airTime: number, -- seconds since leaving the ground (Air only)
	jumped: boolean, -- left the ground by jumping (no coyote jump then)
	charges: number,
	buffered: Action?,
	bufferAge: number,
}

export type Context = {
	grounded: boolean,
	clearance: number, -- studs of free space below the character (ground raycast)
	stamina: number,
	dashSeconds: number?, -- length of the active ground dash (Mode "Dash")
}

function MoveRules.new(t: Tuning): State
	return {
		mode = "Ground",
		modeTime = 0,
		airTime = 0,
		jumped = false,
		charges = t.airDashCharges,
		buffered = nil,
		bufferAge = 0,
	}
end

local function copy(s: State): State
	return table.clone(s) :: State
end

local function setMode(s: State, mode: Mode): State
	local n = copy(s)
	n.mode = mode
	n.modeTime = 0
	return n
end

-- What `action` would do right now, or nil when it is not legal (it may still be buffered).
function MoveRules.resolve(t: Tuning, s: State, action: Action, c: Context): Result?
	local m = s.mode
	if action == "jump" then
		if m == "Ground" or m == "Slide" then
			return "jump"
		elseif m == "Dash" then
			if s.modeTime >= t.dashJumpFraction * (c.dashSeconds or 0) then
				return "jump"
			end
		elseif m == "Air" and not s.jumped and s.airTime <= t.coyoteSeconds then
			return "jump"
		end
		return nil
	elseif action == "q" then
		if m == "Ground" then
			return "groundQ"
		elseif m == "Air" then
			if s.charges > 0 and c.clearance >= t.airDashMinClearance and c.stamina >= t.airDashCost then
				return "airDash"
			end
		end
		return nil
	else -- slam
		if c.clearance < t.slamMinClearance then
			return nil
		end
		if m == "Air" or (m == "AirDash" and s.modeTime >= t.airDashToSlam) then
			return "slam"
		end
		return nil
	end
end

local function apply(_t: Tuning, s: State, r: Result): State
	local n
	if r == "jump" then
		n = setMode(s, "Air")
		n.airTime = 0
		n.jumped = true
	elseif r == "airDash" then
		n = setMode(s, "AirDash")
		n.charges -= 1
	elseif r == "slam" then
		n = setMode(s, "Slam")
		n.charges = 0 -- slam locks air dashes until landing
	else
		n = copy(s) -- groundQ: caller enters "Slide" or "Dash"
	end
	n.buffered = nil
	n.bufferAge = 0
	return n
end

-- A player pressed `action`. Returns the new state and what happened (nil = buffered, latest press wins).
function MoveRules.press(t: Tuning, s: State, action: Action, c: Context): (State, Result?)
	local r: Result? = MoveRules.resolve(t, s, action, c)
	if r then
		return apply(t, s, r), r
	end
	local n = copy(s)
	n.buffered = action
	n.bufferAge = 0
	return n, nil
end

-- The caller started/ended a mode it owns (Slide, Dash, Vault, or back to Ground). Vault refreshes charges.
function MoveRules.enter(t: Tuning, s: State, mode: Mode): State
	local n = setMode(s, mode)
	if mode == "Vault" or mode == "Ground" then
		n.charges = t.airDashCharges
	end
	return n
end

-- One tick. Returns the new state and a buffered action that fired this tick (if any). Never mutates `s`.
function MoveRules.step(t: Tuning, s0: State, dt: number, c: Context): (State, Result?)
	local s = copy(s0)
	s.modeTime += dt
	if s.mode == "Air" then
		s.airTime += dt
	end
	if s.buffered then
		s.bufferAge += dt
	end

	local m = s.mode
	if m == "AirDash" and s.modeTime >= t.airDashSeconds then
		local a = setMode(s, "Air")
		a.airTime = s.airTime
		s = a
		m = "Air"
	elseif m == "Dash" and s.modeTime >= (c.dashSeconds or 0) then
		s = setMode(s, if c.grounded then "Ground" else "Air")
		s.airTime = 0
		s.jumped = false
		m = s.mode
	elseif m == "Land" and s.modeTime >= t.slamRecovery then
		s = setMode(s, "Ground")
		m = "Ground"
	end

	if c.grounded then
		if m == "Air" or m == "AirDash" then
			s = setMode(s, "Ground")
		elseif m == "Slam" then
			s = setMode(s, "Land") -- recovery starts on contact, not on effect spawn
		end
		s.charges = t.airDashCharges -- refresh needs a grounded tick
	elseif m == "Ground" or m == "Slide" then
		s = setMode(s, "Air") -- left an edge (or slid off): coyote window opens
		s.airTime = 0
		s.jumped = false
	end

	if s.buffered then
		local r: Result? = MoveRules.resolve(t, s, s.buffered :: Action, c)
		if r then
			return apply(t, s, r), r
		end
		if s.bufferAge > t.bufferSeconds + 1e-9 then -- tried this tick first, then expires
			s.buffered = nil
			s.bufferAge = 0
		end
	end
	return s, nil
end

-- Slam motion phase: hovering (true) for `slamHover` seconds, then falling.
function MoveRules.slamHovering(t: Tuning, s: State): boolean
	return s.mode == "Slam" and s.modeTime < t.slamHover
end

-- Slide-jump / edge carry: keep the horizontal velocity vector (speed and direction), capped.
function MoveRules.carry(t: Tuning, vx: number, vz: number): (number, number)
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed <= t.carryCap or speed == 0 then
		return vx, vz
	end
	local k = t.carryCap / speed
	return vx * k, vz * k
end

-- Server air-dash ledger (T-059d1, D-472): the server counts accepted air dashes since the last grounded sample.
-- Stamina is client-owned (D-437), so the server checks charges, clearance, stun and a min gap only.
export type AirLedger = { used: number, lastAt: number }
export type AirContext = { grounded: boolean, clearance: number, stunned: boolean, now: number, slack: number }

function MoveRules.newAirLedger(): AirLedger
	return { used = 0, lastAt = -math.huge }
end

-- A grounded sample refreshes the charges.
function MoveRules.serverLand(l: AirLedger)
	l.used = 0
end

-- Accepts (and records) an air dash, or refuses it: grounded, stunned, out of charges, too low, or too soon.
function MoveRules.serverAirDash(t: Tuning, l: AirLedger, c: AirContext): boolean
	if c.grounded or c.stunned or l.used >= t.airDashCharges then
		return false
	end
	if c.clearance < t.airDashMinClearance - c.slack then
		return false
	end
	if c.now - l.lastAt < t.airDashSeconds - c.slack then
		return false
	end
	l.used += 1
	l.lastAt = c.now
	return true
end

return MoveRules
