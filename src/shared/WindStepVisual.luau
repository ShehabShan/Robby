--!strict
-- Prepared deterministic cosmetic plan, NOT a receipt listener or physics controller.
-- Caller must prove original-character ownership; positions are local to a sampled root.
local Motion = require("./WindStep")
local Visual = {}
export type Snapshot = {
	version: number,
	distance: number,
	duration: number,
	brake: number,
	fade: number,
}
export type Ribbon = { side: number, length: number, width: number, opacity: number }
export type Mote = { side: number, behind: number, height: number, size: number, opacity: number }
export type Frame = { phase: string, ribbons: { Ribbon }, motes: { Mote }, arc: number, outline: number }
local function finite(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) < math.huge
end
function Visual.snapshot(raw: any): Snapshot?
	if type(raw) ~= "table" or raw.version ~= 1 or not finite(raw.fade) or raw.fade <= 0 or raw.fade > 0.12 then
		return nil
	end
	local motion = Motion.profile({
		distance = raw.distance,
		duration = raw.duration,
		brake = raw.brake,
		iframes = 0,
		skin = 0,
		maxFrame = 0.05,
	})
	if not motion then
		return nil
	end
	return table.freeze({
		version = 1,
		distance = motion.distance,
		duration = motion.duration,
		brake = motion.brake,
		fade = raw.fade,
	})
end
local function pack(phase: string, ribbons: { Ribbon }, motes: { Mote }, arc: number, outline: number): Frame
	return table.freeze({
		phase = phase,
		ribbons = table.freeze(ribbons),
		motes = table.freeze(motes),
		arc = arc,
		outline = outline,
	})
end
local function empty(): Frame
	return pack("hidden", {}, {}, 0, 0)
end
-- Tiny reversible anticipation; never represents an accepted launch or immunity.
function Visual.predicted(elapsed: number): Frame
	if not finite(elapsed) or elapsed < 0 or elapsed >= 0.06 then
		return empty()
	end
	return pack("anticipation", {}, {}, 0, 0.25 * (1 - elapsed / 0.06))
end
-- elapsed is admitted receipt clock minus acceptedAt; never restart at zero on arrival.
-- speed is measured PLANAR speed of the original character, not ideal travel distance.
-- stoppedAt is an observed sticky stop timestamp; caller owns it and its original identity.
function Visual.sample(s: Snapshot, elapsed: number, speed: number, stoppedAt: number?, reduced: boolean): Frame
	if not finite(elapsed) or elapsed < 0 or not finite(speed) or speed < 0 then
		return empty()
	end
	if
		stoppedAt ~= nil and (not finite(stoppedAt) or stoppedAt < 0 or stoppedAt > elapsed or stoppedAt > s.duration)
	then
		return empty()
	end
	local endAt = stoppedAt or s.duration
	if elapsed >= endAt + s.fade then
		return empty()
	end
	local tail = math.clamp((elapsed - endAt) / s.fade, 0, 1)
	local peak = s.distance / (s.duration - s.brake / 2)
	local fraction = math.clamp(speed / peak, 0, 1)
	-- Fading has a small LOCAL wisp even after speed reaches0; never a swept path through walls.
	local length = if elapsed >= endAt then 0.8 * (1 - tail) else 4.5 * fraction
	local alpha = (1 - tail) * 0.85
	local phase = if elapsed >= endAt
		then "fade"
		elseif elapsed < 0.06 then "launch"
		elseif elapsed < s.duration - s.brake then "travel"
		else "brake"
	local ribbons: { Ribbon } = {}
	if length > 0 then
		for _, side in { -1, 1 } do
			table.insert(
				ribbons,
				table.freeze({ side = side, length = length, width = 0.32 * (1 - tail), opacity = alpha })
			)
		end
	end
	local motes: { Mote } = {}
	if not reduced and length > 0 then
		for i = 1, 6 do
			local drift = (elapsed * 4 + i / 7) % 1
			table.insert(
				motes,
				table.freeze({
					side = if i % 2 == 0 then 1 else -1,
					behind = length * drift,
					height = (i % 3 - 1) * 0.15,
					size = 0.08 * (1 - drift),
					opacity = alpha * (1 - drift),
				})
			)
		end
	end
	local arc = if stoppedAt == nil and elapsed < 0.06 then (1 - elapsed / 0.06) * 0.65 else 0
	return pack(phase, ribbons, motes, arc, 0)
end
return Visual
