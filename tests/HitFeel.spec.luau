local Config = require("../src/shared/Config")
local HitFeel = require("../src/shared/HitFeel")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function tuning(overrides: { [string]: number }?): any
	local t = table.clone(Config.HitFeel) :: any
	for k, v in overrides or {} do
		t[k] = v
	end
	return t
end

return {
	["hitfeel: hit-stop is 2-4 frames"] = function()
		eq(HitFeel.hitStopSeconds(tuning()), Config.HitFeel.hitStopFrames / 60, "config")
		eq(HitFeel.hitStopSeconds(tuning({ hitStopFrames = 0 })), 2 / 60, "min")
		eq(HitFeel.hitStopSeconds(tuning({ hitStopFrames = 9 })), 4 / 60, "max")
	end,
	["hitfeel: shake decays to exactly zero"] = function()
		local t = tuning()
		eq(HitFeel.shakeAmplitude(t, 0), t.shakeAmplitude, "start")
		eq(HitFeel.shakeAmplitude(t, t.shakeSeconds / 2) < t.shakeAmplitude, true, "decays")
		eq(HitFeel.shakeAmplitude(t, t.shakeSeconds), 0, "end")
		eq(HitFeel.shakeAmplitude(t, t.shakeSeconds + 1), 0, "after")
		eq(HitFeel.shakeAmplitude(t, -1), 0, "before")
	end,
	["hitfeel: damage text is whole and non-negative"] = function()
		eq(HitFeel.damageText(19.6), "20")
		eq(HitFeel.damageText(6), "6")
		eq(HitFeel.damageText(-3), "0")
	end,
}
