local HudLayout = require("../src/shared/HudLayout")
local CrucibleUi = require("../src/shared/CrucibleUi")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function st(platform: string, w: number, h: number, phase: string): any
	return {
		width = w,
		height = h,
		platform = platform,
		phase = phase,
		recipe = "Crescent + Crescent → Twin Crescent",
		odds = 0.55,
		known = false,
		catalyst = 200,
		woundHours = 24,
		round = 2,
		rounds = 3,
		needle = 0.3,
		zone = 0.7,
		zoneWidth = 0.18,
		result = "failed",
	}
end

local function byId(els: { any }): { [string]: any }
	local m = {}
	for _, e in els do
		m[e.id] = e
	end
	return m
end

return {
	["crucible ui: odds and consequences shown before confirm"] = function()
		local s = st("pc", 1280, 720, "confirm")
		local m = byId(CrucibleUi.build(s))
		eq(m.crucibleOdds.text, "Experimental · success 55%", "odds")
		eq(string.find(m.crucibleFail.text, "200 Shards lost", 1, true) ~= nil, true, "catalyst")
		eq(string.find(m.crucibleFail2.text, "Wounded 24h", 1, true) ~= nil, true, "consequence")
		eq(string.find(m.crucibleFail2.text, "never destroyed", 1, true) ~= nil, true, "never destroyed")
		eq(m.crucibleFuse.text, "Fuse ×200 [F]", "pc fuse")
		s.known = true
		eq(byId(CrucibleUi.build(s)).crucibleOdds.text, "Known recipe · safe (100%)", "known")
	end,
	["crucible ui: focus bar, zone and needle; result text"] = function()
		local m = byId(CrucibleUi.build(st("touch", 360, 640, "focus")))
		eq(m.focusPress.text, "Press", "touch press")
		eq(m.focusZone.w, math.floor(m.focusBack.w * 0.18 + 0.5), "zone width")
		eq(m.focusNeedle.x < m.focusZone.x, true, "needle left of zone")
		eq(m.crucibleOdds.text, "Focus 2/3 · success 55%", "round")
		eq(
			byId(CrucibleUi.build(st("pc", 1280, 720, "result"))).crucibleResult.text,
			"Fusion failed · Kith Wounded, Recoil",
			"fail"
		)
	end,
	["crucible ui: on screen, readable, touch targets on all platforms"] = function()
		for _, c in { { "touch", 360, 640 }, { "pc", 1280, 720 }, { "gamepad", 1280, 720 } } do
			for _, phase in { "confirm", "focus", "result" } do
				for _, e in CrucibleUi.build(st(c[1], c[2], c[3], phase)) do
					local ok = e.x >= 0 and e.y >= 0 and e.x + e.w <= c[2] and e.y + e.h <= c[3]
					eq(ok, true, `{c[1]} {phase} {e.id} on screen`)
					if e.textSize then
						eq(e.textSize >= HudLayout.MIN_TEXT, true, `{e.id} text`)
					end
					if e.kind == "button" and c[1] == "touch" then
						eq(e.h >= HudLayout.MIN_TOUCH, true, "touch target")
					end
				end
			end
		end
	end,
}
