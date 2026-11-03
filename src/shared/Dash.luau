--!strict
-- Basic dash (T-058d, D-435): every player has a short directional dash on Q + WASD, like Rell Seas /
-- Project Slayers 2 / battlegrounds games. Side dash = the dodge (short i-frames, short cooldown);
-- forward/back = positioning (no i-frames, longer shared cooldown). Stamina cost, no dash while stunned,
-- a short recovery at the end so it cannot be chained (anti-Blox-Fruits rules, R-030).
-- Pure: no game services. Numbers come from `Config.Dash` (targets: research/notes/R-030-dash.md).
local Dash = {}

export type Kind = "side" | "forward" | "back"

export type KindTuning = {
	distance: number, -- studs
	seconds: number, -- burst time
	iframeFrom: number, -- i-frame window start (s into the dash); iframeTo <= iframeFrom = none
	iframeTo: number,
	cooldown: number,
}

export type Tuning = {
	side: KindTuning,
	forward: KindTuning,
	back: KindTuning,
	cost: number, -- stamina
	recovery: number, -- seconds after the burst before another dash / attack
	sideAngle: number, -- degrees off facing beyond which a dash counts as side (45 = even split)
	slideMinSpeed: number, -- Q while sprinting forward at ≥ this speed slides instead (D-431)
	serverSlack: number, -- seconds of cooldown slack the server allows for latency
	guardSlack: number, -- speed guard multiplier over the dash speed
}

export type State = {
	kind: Kind?, -- current dash, nil when idle
	elapsed: number, -- seconds into the current dash
	recover: number, -- recovery left after the burst
	sideCd: number,
	linearCd: number, -- shared forward/back cooldown
}

export type Context = {
	stamina: number,
	stunned: boolean,
}

function Dash.new(): State
	return { kind = nil, elapsed = 0, recover = 0, sideCd = 0, linearCd = 0 }
end

-- Classify a wanted move direction against the facing (both flat XZ unit-ish vectors, as {x, z}).
-- No move input dashes back (Deepwoken default roll), so a standing Q is a safe back-step.
function Dash.classify(t: Tuning, fx: number, fz: number, mx: number, mz: number): Kind
	local fm, mm = math.sqrt(fx * fx + fz * fz), math.sqrt(mx * mx + mz * mz)
	if mm < 1e-3 or fm < 1e-3 then
		return "back"
	end
	local dot = (fx * mx + fz * mz) / (fm * mm)
	local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
	if angle <= t.sideAngle then
		return "forward"
	elseif angle >= 180 - t.sideAngle then
		return "back"
	end
	return "side"
end

-- Q decides between slide and dash: sprinting forward fast enough slides (keeps T-058e), else dash.
function Dash.qAction(t: Tuning, sprinting: boolean, speed: number, kind: Kind): "slide" | "dash"
	if sprinting and kind == "forward" and speed >= t.slideMinSpeed then
		return "slide"
	end
	return "dash"
end

local function kt(t: Tuning, kind: Kind): KindTuning
	return if kind == "side" then t.side elseif kind == "forward" then t.forward else t.back
end

function Dash.cooldownLeft(s: State, kind: Kind): number
	return if kind == "side" then s.sideCd else s.linearCd
end

function Dash.canDash(t: Tuning, s: State, kind: Kind, c: Context): boolean
	return s.kind == nil
		and s.recover <= 0
		and not c.stunned
		and c.stamina >= t.cost
		and Dash.cooldownLeft(s, kind) <= 0
end

-- Start a dash. Returns the new state and the stamina to spend (0 if refused; state unchanged).
function Dash.start(t: Tuning, s: State, kind: Kind, c: Context): (State, number)
	if not Dash.canDash(t, s, kind, c) then
		return s, 0
	end
	local cd = kt(t, kind).cooldown
	return {
		kind = kind,
		elapsed = 0,
		recover = 0,
		sideCd = if kind == "side" then cd else s.sideCd,
		linearCd = if kind ~= "side" then cd else s.linearCd,
	},
		t.cost
end

function Dash.speed(t: Tuning, kind: Kind): number
	local k = kt(t, kind)
	return if k.seconds > 0 then k.distance / k.seconds else 0
end

-- Burst speed `elapsed` seconds in: flat burst, last 30 % eases to 40 % so it stops cleanly (no skate).
function Dash.speedAt(t: Tuning, kind: Kind, elapsed: number): number
	local k = kt(t, kind)
	if elapsed >= k.seconds then
		return 0
	end
	local base = Dash.speed(t, kind)
	local ease = k.seconds * 0.7
	if elapsed <= ease then
		return base
	end
	local f = (elapsed - ease) / (k.seconds - ease)
	return base * (1 - 0.6 * f)
end

function Dash.invulnerable(t: Tuning, s: State): boolean
	if s.kind == nil then
		return false
	end
	local k = kt(t, s.kind)
	return k.iframeTo > k.iframeFrom and s.elapsed >= k.iframeFrom and s.elapsed < k.iframeTo
end

-- One frame. Returns a new State; never mutates `s`. A stun cancels the dash (no recovery).
function Dash.step(t: Tuning, s: State, dt: number, stunned: boolean?): State
	dt = math.max(dt, 0)
	local kind: Kind?, elapsed, recover = s.kind, s.elapsed, math.max(s.recover - dt, 0)
	if kind and stunned then
		kind, elapsed = nil, 0
	elseif kind then
		elapsed += dt
		if elapsed >= kt(t, kind).seconds then
			kind, elapsed, recover = nil, 0, t.recovery
		end
	end
	return {
		kind = kind,
		elapsed = elapsed,
		recover = recover,
		sideCd = math.max(s.sideCd - dt, 0),
		linearCd = math.max(s.linearCd - dt, 0),
	}
end

-- Server check for a dash request: time since that kind's last accepted dash must cover its cooldown
-- (minus latency slack), and the player must not be stunned or out of stamina.
function Dash.serverAllows(t: Tuning, kind: Kind, sinceLast: number?, c: Context): boolean
	if c.stunned or c.stamina < t.cost then
		return false
	end
	local k = kt(t, kind)
	return sinceLast == nil or sinceLast >= k.cooldown - t.serverSlack
end

-- Speed guard window (D-204): highest horizontal speed allowed while a dash of `kind` is active.
function Dash.guardSpeed(t: Tuning, kind: Kind): number
	return Dash.speed(t, kind) * t.guardSlack
end

-- Guard window length: burst + slack, so the guard ignores the burst only for its real duration.
function Dash.guardSeconds(t: Tuning, kind: Kind): number
	return kt(t, kind).seconds + t.serverSlack
end

return Dash
