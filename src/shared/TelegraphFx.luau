--!strict
-- Beast telegraph FX parameters (T-022c, D-136). Pure: no services, tested under Lune.
-- The server shows a wind-up by setting the `Telegraph` attribute; the client plays `fx.beast.telegraph`
-- on its rising edge. This module turns a beast kind (Config.Beasts.kinds) into what the effect draws:
-- a ground warning ring sized to the attack reach, a front cone or full circle, and how long it lasts.

local TelegraphFx = {}

TelegraphFx.FX_ID = "fx.beast.telegraph"
TelegraphFx.COLOR = { r = 255, g = 60, b = 40 } -- same red as the BeastHud "!"

export type Params = {
	radius: number, -- studs, the attack reach
	seconds: number, -- wind-up length; the ring fills over this time
	allRound: boolean, -- true: full circle (slam); false: front cone (lunge)
	coneDeg: number, -- full cone width in degrees (360 when allRound)
	pitch: number, -- warning sound pitch: heavier beasts sound lower
}

local MIN_SECONDS = 0.4 -- matches Config.Beasts.minTelegraph (ROADMAP T-022)

-- Kind config → effect params. Missing or bad fields fall back to safe values; never throws.
function TelegraphFx.params(kind: any): Params
	local k = if typeof(kind) == "table" then kind else {}
	local range = if typeof(k.range) == "number" and k.range > 0 then k.range else 6
	local seconds = if typeof(k.telegraph) == "number" then math.max(k.telegraph, MIN_SECONDS) else MIN_SECONDS
	local dot = if typeof(k.arcDot) == "number" then math.clamp(k.arcDot, -1, 1) else -1
	local allRound = dot <= -1
	local coneDeg = if allRound then 360 else 2 * math.deg(math.acos(dot))
	local hp = if typeof(k.hp) == "number" and k.hp > 0 then k.hp else 100
	local pitch = math.clamp(1.4 - hp / 200, 0.6, 1.3)
	return { radius = range, seconds = seconds, allRound = allRound, coneDeg = coneDeg, pitch = pitch }
end

-- Attribute edge: "start" when Telegraph turns on, "stop" when it turns off, nil otherwise.
function TelegraphFx.edge(was: unknown, now: unknown): string?
	local a, b = was == true, now == true
	if b and not a then
		return "start"
	elseif a and not b then
		return "stop"
	end
	return nil
end

-- Ring fill (0..1) after `elapsed` seconds of a wind-up of `seconds`.
function TelegraphFx.fill(elapsed: number, seconds: number): number
	if seconds <= 0 then
		return 1
	end
	return math.clamp(elapsed / seconds, 0, 1)
end

return TelegraphFx
