local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local HudLayout = require("../src/shared/HudLayout")
local BindingUi = require("../src/shared/BindingUi")

local built = Registry.build(All.content(Config))

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function state(platform: string, w: number, h: number, bindState: string): any
	return {
		width = w,
		height = h,
		platform = platform,
		bindState = bindState,
		progress = 0.62,
		shards = 2,
		heart = false,
		canBind = false,
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

return {
	["bind ui: phone duel is readable and fits the screen"] = function()
		local s = state("touch", 360, 640, "running")
		local els = BindingUi.build(s)
		local m = byId(els)
		eq(m.bindChannel ~= nil and m.bindShard ~= nil, true, "buttons")
		for _, e in els do
			eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= 360 and e.y + e.h <= 640, true, `{e.id} on screen`)
			if e.textSize then
				eq(e.textSize >= HudLayout.MIN_TEXT, true, `{e.id} text size`)
			end
			if e.kind == "button" then
				eq(e.h >= HudLayout.MIN_TOUCH and e.w >= HudLayout.MIN_TOUCH, true, `{e.id} touch target`)
			end
		end
		eq(overlaps(m.bindChannel, m.bindShard), false, "buttons apart")
		eq(m.bindFill.w, math.floor(m.bindBack.w * 0.62 + 0.5), "fill width")
		eq(string.find(m.bindChannel.text, "[", 1, true), nil, "no key hint on touch")
	end,
	["bind ui: duel and prompt never cover the HUD"] = function()
		for _, c in { { "touch", 360, 640 }, { "pc", 1280, 720 }, { "gamepad", 1280, 720 } } do
			local hud = HudLayout.build({
				width = c[2],
				height = c[3],
				platform = c[1],
				health = 50,
				healthMax = 100,
				qi = 50,
				qiMax = 100,
				slots = { {}, {}, {}, {} },
				gaps = { "Guard" },
			})
			local s = state(c[1], c[2], c[3], "running")
			local idle = state(c[1], c[2], c[3], "")
			idle.canBind = true
			for _, els in { BindingUi.build(s), BindingUi.build(idle) } do
				for _, e in els do
					for _, h in hud do
						eq(overlaps(e, h), false, `{c[1]} {e.id} vs {h.id}`)
					end
				end
			end
		end
	end,
	["bind ui: key hints, prompt and results"] = function()
		local pc = byId(BindingUi.build(state("pc", 1280, 720, "running")))
		eq(pc.bindChannel.text, "Channel [B]", "pc channel")
		eq(pc.bindShard.text, "Shard ×2 [G]", "pc shard")
		local pad = byId(BindingUi.build(state("gamepad", 1280, 720, "running")))
		eq(pad.bindChannel.text, "Channel [RB]", "pad channel")
		eq(#BindingUi.build(state("pc", 1280, 720, "")), 0, "nothing when idle")
		local idle = state("pc", 1280, 720, "")
		idle.canBind = true
		eq(byId(BindingUi.build(idle)).bindStart.text, "Bind [B]", "prompt")
		local won = state("pc", 1280, 720, "bound")
		won.heart = true
		eq(string.find(byId(BindingUi.build(won)).bindResult.text, "Heart", 1, true) ~= nil, true, "heart")
		local fled = byId(BindingUi.build(state("pc", 1280, 720, "fled")))
		eq(string.find(fled.bindResult.text, "fled", 1, true) ~= nil, true, "fled")
	end,
	["bind ui: picks the nearest bindable wild Kith"] = function()
		local i = BindingUi.pickTarget(Config, built, {
			{ speciesId = "kith.stone", hp = 100, maxHp = 100, dist = 2 }, -- healthy
			{ speciesId = "kith.stone", hp = 20, maxHp = 100, dist = 10 },
			{ speciesId = "kith.stone", hp = 10, maxHp = 100, dist = 6 },
			{ speciesId = "kith.stone", hp = 10, maxHp = 100, dist = 999 }, -- far
		})
		eq(i, 3, "nearest weakened")
		eq(BindingUi.pickTarget(Config, built, {}), nil, "none")
	end,
}
