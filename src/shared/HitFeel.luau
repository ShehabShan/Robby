--!strict
-- Hit feel math (T-014, ART §5 items 2 and 5): hit-stop length, camera-shake envelope, damage-number text.
-- Pure: no services, so it is tested under Lune. Tuning lives in `Config.HitFeel` and is passed in.

export type Tuning = {
	hitStopFrames: number,
	shakeSeconds: number,
	shakeAmplitude: number,
	flashSeconds: number,
	numberSeconds: number,
	numberRise: number,
	sparks: number,
}

local HitFeel = {}

-- Hit-stop is held to 2–4 frames (ART §5 item 2), whatever the tuning says.
function HitFeel.hitStopSeconds(t: Tuning): number
	return math.clamp(math.floor(t.hitStopFrames + 0.5), 2, 4) / 60
end

-- Shake strength decays linearly and is exactly 0 at and after the end (no drift, ART §5 item 5).
function HitFeel.shakeAmplitude(t: Tuning, elapsed: number): number
	if elapsed < 0 or elapsed >= t.shakeSeconds then
		return 0
	end
	return t.shakeAmplitude * (1 - elapsed / t.shakeSeconds)
end

-- Damage numbers are whole and never negative.
function HitFeel.damageText(amount: number): string
	return tostring(math.floor(math.max(amount, 0) + 0.5))
end

return HitFeel
