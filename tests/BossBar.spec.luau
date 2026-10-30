local BossBar = require("../src/shared/BossBar")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["bossbar: fill and text"] = function()
		local v = BossBar.view(450, 900, 1)
		eq(v.frac, 0.5, "frac")
		eq(v.text, "450 / 900", "text")
		eq(v.enraged, false, "phase 1")
		eq(v.phaseText, "", "no cue")
	end,
	["bossbar: phase 2 shows the enraged cue"] = function()
		local v = BossBar.view(100, 900, 2)
		eq(v.enraged, true, "enraged")
		eq(v.phaseText, "Enraged", "cue")
	end,
	["bossbar: bad input is safe"] = function()
		local v = BossBar.view(nil, 0, nil)
		eq(v.frac, 0, "frac")
		eq(BossBar.view(5000, 900, 1).frac, 1, "clamped")
	end,
	["bossbar: pick nearest in range"] = function()
		eq(BossBar.pick({ 100, 40, 20 }), 3, "nearest")
		eq(BossBar.pick({ 100, 200 }), nil, "none in range")
		eq(BossBar.pick({}), nil, "empty")
	end,
}
