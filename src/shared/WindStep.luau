--!strict
-- Prepared Wind Step motion policy (D-304). NOT a physics driver or authorization.
-- Engine callers supply original-character state, elapsed server time and swept clearance.
local WindStep = {}
export type Profile = {
	distance: number,
	duration: number,
	brake: number,
	iframes: number,
	skin: number,
	maxFrame: number,
	peak: number,
}
export type State = {
	profile: Profile,
	elapsed: number,
	traveled: number,
	done: boolean,
	reason: string?,
}
export type Frame = { distance: number, speed: number, done: boolean, reason: string? }
-- Proposed tuning only; Config and live content remain unchanged until atomic activation.
WindStep.PROPOSED =
	table.freeze({ distance = 14, duration = 0.24, brake = 0.08, iframes = 0.18, skin = 0.15, maxFrame = 0.05 })
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function WindStep.profile(raw: any): Profile?
	if type(raw) ~= "table" then
		return nil
	end
	for _, key in { "distance", "duration", "brake", "iframes", "skin", "maxFrame" } do
		if not finite(raw[key]) then
			return nil
		end
	end
	if
		raw.distance <= 0
		or raw.distance > 32
		or raw.duration < 0.1
		or raw.duration > 0.5
		or raw.brake <= 0
		or raw.brake >= raw.duration
		or raw.iframes < 0
		or raw.iframes > raw.duration
		or raw.skin < 0
		or raw.skin > 1
		or raw.maxFrame <= 0
		or raw.maxFrame > raw.duration
	then
		return nil
	end
	local peak = raw.distance / (raw.duration - raw.brake / 2)
	if peak > 160 then
		return nil
	end
	return table.freeze({
		distance = raw.distance,
		duration = raw.duration,
		brake = raw.brake,
		iframes = raw.iframes,
		skin = raw.skin,
		maxFrame = raw.maxFrame,
		peak = peak,
	})
end
-- Nonfinite travel input is rejected, not silently replaced by facing.
-- Normalize by largest component first to avoid overflow/underflow on finite inputs.
function WindStep.direction(mx: number, mz: number, fx: number, fz: number): (number, number, boolean)
	if not finite(mx) or not finite(mz) then
		return 0, 0, false
	end
	local x, z = mx, mz
	if math.max(math.abs(x), math.abs(z)) < 0.05 then
		x, z = fx, fz
	end
	if not finite(x) or not finite(z) then
		return 0, 0, false
	end
	local scale = math.max(math.abs(x), math.abs(z))
	if scale < 1e-6 then
		return 0, 0, false
	end
	x, z = x / scale, z / scale
	local length = math.sqrt(x * x + z * z)
	return x / length, z / length, true
end
-- Conservative allowlist. This predicate does NOT replace loadout/payment/ownership checks.
function WindStep.eligible(health: number, anchored: boolean, seated: boolean, state: string): boolean
	return finite(health)
		and health > 0
		and not anchored
		and not seated
		and (
			state == "Running"
			or state == "RunningNoPhysics"
			or state == "Landed"
			or state == "Jumping"
			or state == "Freefall"
		)
end
-- Exact integral of the proposed constant-speed then linear-brake profile.
function WindStep.sample(p: Profile, elapsed: number): (number, number)
	if not finite(elapsed) or elapsed <= 0 then
		return 0, if elapsed == 0 then p.peak else 0
	end
	if elapsed >= p.duration then
		return p.distance, 0
	end
	local cruise = p.duration - p.brake
	if elapsed <= cruise then
		return p.peak * elapsed, p.peak
	end
	local t = elapsed - cruise
	return p.peak * (cruise + t - t * t / (2 * p.brake)), p.peak * (1 - t / p.brake)
end
-- A hitch drops old travel; never make it up with a teleport/high-speed catch-up.
-- Return requested distance and retained simulation interval for the volume sweep/driver.
function WindStep.travel(p: Profile, from: number, to: number): (number, number)
	if not finite(from) or not finite(to) or from < 0 or to <= from or to > p.duration then
		return 0, 0
	end
	local start = math.max(from, to - p.maxFrame)
	local a = WindStep.sample(p, start)
	local b = WindStep.sample(p, to)
	return math.max(0, b - a), to - start
end
function WindStep.new(raw: any): State?
	local p = WindStep.profile(raw)
	if not p then
		return nil
	end
	return { profile = p, elapsed = 0, traveled = 0, done = false, reason = nil }
end
function WindStep.stop(s: State, reason: string)
	if not s.done then
		s.done, s.reason = true, reason
	end
end
local function frame(s: State, distance: number, seconds: number): Frame
	return table.freeze({
		distance = distance,
		speed = if seconds > 0 then distance / seconds else 0,
		done = s.done,
		reason = s.reason,
	})
end
-- Clearance is a collision distance from the current body, not remaining ideal-path distance.
-- nil means a successful clear sweep. An engine query failure MUST cancel, not pass nil.
function WindStep.step(s: State, elapsed: number, clearance: number?, cancelled: boolean): Frame
	if s.done then
		return frame(s, 0, 0)
	end
	if cancelled then
		WindStep.stop(s, "cancelled")
	elseif
		not finite(elapsed)
		or elapsed < s.elapsed
		or (clearance ~= nil and (not finite(clearance) or clearance < 0))
	then
		WindStep.stop(s, "invalid")
	elseif elapsed > s.profile.duration then
		WindStep.stop(s, "complete") -- late callbacks never replay the expired dash
	end
	if s.done then
		return frame(s, 0, 0)
	end
	local requested, seconds = WindStep.travel(s.profile, s.elapsed, elapsed)
	local allowed = if clearance ~= nil then math.max(0, clearance - s.profile.skin) else requested
	local distance = math.min(requested, allowed)
	s.elapsed = elapsed
	s.traveled += distance
	if clearance ~= nil and (clearance <= s.profile.skin or allowed < requested) then
		WindStep.stop(s, "blocked")
	elseif elapsed >= s.profile.duration then
		WindStep.stop(s, "complete")
	end
	return frame(s, distance, seconds)
end
return WindStep
