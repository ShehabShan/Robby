local HudLayout = require("../src/shared/HudLayout")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function state(platform: string, w: number, h: number, roles: { string | false }, gaps: { string }): any
	local slots = {}
	for _, r in roles do
		table.insert(
			slots,
			{ role = if r then r else nil, name = if r then "k" else nil, key = "E", selected = #slots == 1 }
		)
	end
	return {
		width = w,
		height = h,
		platform = platform,
		health = 50,
		healthMax = 100,
		qi = 25,
		qiMax = 100,
		slots = slots,
		gaps = gaps,
	}
end

local function byId(els: { any }): { [string]: any }
	local m = {}
	for _, e in els do
		m[e.id] = e
	end
	return m
end

local SEVEN = { "Strike", "Guard", "Mend", "Carry", "Stride", "Seek", false }

return {
	["hud: all elements fit a 360x640 phone with 7 slots"] = function()
		for _, e in HudLayout.build(state("touch", 360, 640, SEVEN, { "Strike" })) do
			eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= 360 and e.y + e.h <= 640, true, `{e.id} inside viewport`)
		end
	end,
	["hud: touch slots are at least 44 px and do not overlap"] = function()
		local m = byId(HudLayout.build(state("touch", 360, 640, SEVEN, {})))
		for i = 1, 7 do
			eq(m[`slot{i}`].w >= HudLayout.MIN_TOUCH, true, `slot{i} size`)
		end
		local a, b = m.slot1, m.slot2
		eq(a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y, true, "no overlap")
	end,
	["hud: touch slots keep the jump button zone free"] = function()
		for _, e in HudLayout.build(state("touch", 360, 640, SEVEN, {})) do
			if e.kind == "slot" then
				eq(e.y + e.h <= 640 - 100, true, `{e.id} above jump zone`)
			end
		end
	end,
	["hud: text is readable (>= 12 px)"] = function()
		for _, e in HudLayout.build(state("touch", 360, 640, SEVEN, { "Guard" })) do
			if e.kind == "text" then
				eq((e.textSize or 0) >= HudLayout.MIN_TEXT, true, `{e.id} text size`)
			end
		end
	end,
	["hud: bar fill follows the value"] = function()
		local m = byId(HudLayout.build(state("pc", 1280, 720, {}, {})))
		eq(m.qiFill.w, math.floor(m.qiBack.w * 0.25 + 0.5), "qi fill")
		eq(m.healthFill.w, math.floor(m.healthBack.w * 0.5 + 0.5), "health fill")
		eq(m.qiText.text, "Qi 25 / 100", "qi text")
	end,
	["hud: role codes, empty and unknown slots"] = function()
		local m = byId(HudLayout.build(state("pc", 1280, 720, { "Guard", false, "Tank" }, {})))
		eq(m.slot1Role.text, "GRD", "guard")
		eq(m.slot2Role.text, "+", "empty")
		eq(m.slot3Role.text, "?", "unknown")
		eq(m.slot1Key.text, "E", "pc key hint")
	end,
	["hud: gap warning only when a role is missing"] = function()
		eq(byId(HudLayout.build(state("pc", 1280, 720, { "Strike" }, {}))).gapWarn, nil, "no gap")
		local m = byId(HudLayout.build(state("pc", 1280, 720, { "Stride" }, { "Strike", "Guard" })))
		eq(m.gapWarn.text, "No Strike or Guard Kith equipped", "gap text")
	end,
	["hud: pc row is centered and touch hides key hints"] = function()
		local m = byId(HudLayout.build(state("pc", 1280, 720, { "Strike", "Guard", "Stride" }, {})))
		local left, right = m.slot1.x, m.slot3.x + m.slot3.w
		eq(math.abs(left - (1280 - right)) <= 1, true, "centered")
		eq(byId(HudLayout.build(state("touch", 360, 640, { "Strike" }, {}))).slot1Key, nil, "no key on touch")
	end,
	["hud: strain strip, satiety dot and cooldown overlay"] = function()
		local s = state("touch", 360, 640, { "Strike" }, {})
		s.slots[1].strain = 0.5
		s.slots[1].satiety = 0.1
		s.slots[1].cooldown = 1
		local m = byId(HudLayout.build(s))
		eq(m.slot1Strain.w, math.floor(m.slot1.w * 0.5 + 0.5), "strain width")
		eq(m.slot1Sat.color[1], 230, "low satiety is red")
		eq(m.slot1Cd.h, m.slot1.w, "full cooldown")
	end,
}
