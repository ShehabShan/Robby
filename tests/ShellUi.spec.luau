local HudLayout = require("../src/shared/HudLayout")
local BindingUi = require("../src/shared/BindingUi")
local ShellUi = require("../src/shared/ShellUi")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function st(platform: string, w: number, h: number, atRest: boolean): any
	return {
		width = w,
		height = h,
		platform = platform,
		rank = 1,
		stage = 2,
		progress = 0.45,
		ready = false,
		atRest = atRest,
		shards = 120,
	}
end

local function byId(els: { any }): { [string]: any }
	local m = {}
	for _, e in els do
		m[e.id] = e
	end
	return m
end

local function overlaps(a: any, b: any): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function bind(platform: string, w: number, h: number, bindState: string, canBind: boolean): any
	return {
		width = w,
		height = h,
		platform = platform,
		bindState = bindState,
		progress = 0.5,
		shards = 2,
		heart = false,
		canBind = canBind,
	}
end

return {
	["shell ui: fits, is readable and never covers the HUD or Binding UI"] = function()
		for _, c in { { "touch", 360, 640 }, { "pc", 1280, 720 }, { "gamepad", 1280, 720 } } do
			local p, w, h = c[1], c[2], c[3]
			local others = HudLayout.build({
				width = w,
				height = h,
				platform = p,
				health = 50,
				healthMax = 100,
				qi = 50,
				qiMax = 100,
				slots = { {}, {}, {}, {} },
				gaps = { "Guard" },
			})
			for _, e in BindingUi.build(bind(p, w, h, "running", false)) do
				table.insert(others, e)
			end
			for _, e in BindingUi.build(bind(p, w, h, "", true)) do
				table.insert(others, e)
			end
			for _, e in ShellUi.build(st(p, w, h, true)) do
				eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= w and e.y + e.h <= h, true, `{p} {e.id} on screen`)
				if e.textSize then
					eq(e.textSize >= HudLayout.MIN_TEXT, true, `{p} {e.id} text`)
				end
				if e.kind == "button" and p == "touch" then
					eq(e.h >= HudLayout.MIN_TOUCH, true, "touch target")
				end
				for _, o in others do
					eq(overlaps(e, o), false, `{p} {e.id} vs {o.id}`)
				end
			end
		end
	end,
	["shell ui: shell colour per Stage, fill, label and Refine button"] = function()
		local s = st("pc", 1280, 720, true)
		local m = byId(ShellUi.build(s))
		eq(m.shellIcon.color, ShellUi.SHELL_COLOR.water, "second stage is water")
		eq(m.shellFill.w, math.floor(m.shellBack.w * 0.45 + 0.5), "fill")
		eq(m.shellName.text, "R1 Second", "label")
		eq(m.shellRefine.text, "Refine ×120 [H]", "pc refine")
		eq(byId(ShellUi.build(st("touch", 360, 640, true))).shellRefine.text, "Refine ×120", "touch refine")
		eq(byId(ShellUi.build(st("pc", 1280, 720, false))).shellRefine, nil, "no refine away from rest")
		s.stage, s.ready = 4, true
		m = byId(ShellUi.build(s))
		eq(m.shellIcon.color, ShellUi.SHELL_COLOR.crystal, "peak is crystal")
		eq(string.find(m.shellName.text, "ready", 1, true) ~= nil, true, "ready label")
	end,
}
