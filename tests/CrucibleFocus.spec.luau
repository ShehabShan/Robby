local Config = require("../src/shared/Config")
local CrucibleFocus = require("../src/shared/CrucibleFocus")

local F = Config.Crucible.focus

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(a: number, b: number, msg: string)
	if math.abs(a - b) > 1e-6 then
		error(`{msg}: expected {b}, got {a}`, 2)
	end
end

return {
	["focus: zones stay on the bar; needle ping-pongs"] = function()
		near(CrucibleFocus.zoneFor(Config, 0), F.zoneWidth / 2, "low zone")
		near(CrucibleFocus.zoneFor(Config, 1), 1 - F.zoneWidth / 2, "high zone")
		local f = CrucibleFocus.new(Config, { 0.5, 0.5, 0.5 }, 0)
		near(CrucibleFocus.needle(f, Config, 0), 0, "start")
		near(CrucibleFocus.needle(f, Config, F.sweepSeconds), 1, "end of pass")
		near(CrucibleFocus.needle(f, Config, F.sweepSeconds * 1.5), 0.5, "coming back")
	end,
	["focus: hit = 1, near miss partial, far miss 0"] = function()
		eq(CrucibleFocus.score(Config, 0.5, 0.5), 1, "centre")
		local edge = 0.5 + F.zoneWidth / 2
		near(CrucibleFocus.score(Config, edge + F.nearMiss / 2, 0.5), 0.25, "near miss")
		eq(CrucibleFocus.score(Config, edge + F.nearMiss + 0.01, 0.5), 0, "far miss")
	end,
	["focus: three presses finish; timeouts score 0; result averages"] = function()
		local f = CrucibleFocus.new(Config, { 0.5, 0.5, 0.5 }, 0)
		local t = F.sweepSeconds * 0.5 -- needle at 0.5 = zone centre
		eq(CrucibleFocus.press(f, Config, t), 1, "round 1 hit")
		CrucibleFocus.step(f, Config, t + F.roundSeconds) -- round 2 times out
		eq(f.scores[2], 0, "timeout")
		local t3 = f.roundStart + F.sweepSeconds * 0.5
		eq(CrucibleFocus.press(f, Config, t3), 1, "round 3 hit")
		eq(f.done, true, "done")
		eq(CrucibleFocus.press(f, Config, t3 + 1), nil, "no press after done")
		near(CrucibleFocus.result(f, Config), 2 / 3, "average")
	end,
}
