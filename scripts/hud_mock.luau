-- HUD mock renderer (T-016c, D-068): draws HudLayout.build() as HTML so a headless browser can screenshot it.
-- Usage: `lune run scripts/hud_mock.luau` -> build/hud_<name>.html; scripts/hud_mock.sh turns them into PNGs.

local fs = require("@lune/fs")
local HudLayout = require("../src/shared/HudLayout")
local BindingUi = require("../src/shared/BindingUi")
local ShellUi = require("../src/shared/ShellUi")
local CrucibleUi = require("../src/shared/CrucibleUi")

local function rgba(c: { number }, a: number?): string
	return `rgba({c[1]},{c[2]},{c[3]},{a or 1})`
end

local function html(state: any): string
	local parts = {
		`<!doctype html><html><body style="margin:0;width:{state.width}px;height:{state.height}px;overflow:hidden;`,
		`background:linear-gradient(180deg,#6d8fb3 0%,#a9c0d6 45%,#5d7a4c 46%,#3e5534 100%);font-family:Arial,sans-serif">`,
	}
	local elements = HudLayout.build(state)
	if state.bind then -- Binding UI on top (T-017c, D-072)
		for _, e in BindingUi.build(state.bind) do
			table.insert(elements, e)
		end
	end
	for _, e in ShellUi.build(state.shell) do -- Core Shell (T-018d, D-076)
		table.insert(elements, e)
	end
	if state.crucible then -- Crucible panel (T-019e, D-085)
		for _, e in CrucibleUi.build(state.crucible) do
			table.insert(elements, e)
		end
	end
	for _, e in elements do
		local s = `position:absolute;left:{e.x}px;top:{e.y}px;width:{e.w}px;height:{e.h}px;box-sizing:border-box;`
		local inner = ""
		if e.kind == "text" then
			local justify = if e.align == "left"
				then "flex-start"
				elseif e.align == "right" then "flex-end"
				else "center"
			s ..= `display:flex;align-items:center;justify-content:{justify};color:{rgba(e.color)};font-size:{e.textSize}px;`
			s ..= "font-weight:bold;text-shadow:0 1px 2px #000;white-space:nowrap;"
			inner = e.text or ""
		elseif e.kind == "slot" then
			s ..= `background:{rgba(e.color, e.alpha)};border:2px solid rgba(255,255,255,0.7);border-radius:10px;`
		elseif e.kind == "button" then
			s ..= `background:{rgba(e.color, e.alpha)};border:2px solid rgba(255,255,255,0.8);border-radius:10px;`
			s ..= `display:flex;align-items:center;justify-content:center;color:#fff;font-size:{e.textSize}px;font-weight:bold;`
			inner = e.text or ""
		elseif e.kind == "dot" then
			s ..= `background:{rgba(e.color, e.alpha)};border-radius:50%;border:1px solid #111;`
		else
			s ..= `background:{rgba(e.color, e.alpha)};border-radius:3px;`
		end
		table.insert(parts, `<div style="{s}">{inner}</div>`)
	end
	table.insert(parts, "</body></html>")
	return table.concat(parts)
end

local function slots(platform: string): { any }
	local keys = if platform == "gamepad" then { "X", "Y", "L2" } else { "E", "Q", "R" }
	return {
		{ role = "Strike", name = "Crescent", key = keys[1], strain = 0.35, satiety = 0.8, cooldown = 0.4 },
		{ role = "Stride", name = "Wind", key = keys[2], strain = 0.7, satiety = 0.3 },
		{ role = "Seek", name = "Seek", key = keys[3], satiety = 0.1 },
		{},
	}
end

local cases = {
	{ name = "phone_360x640", platform = "touch", width = 360, height = 640 },
	{ name = "pc_1280x720", platform = "pc", width = 1280, height = 720 },
	{ name = "gamepad_1280x720", platform = "gamepad", width = 1280, height = 720 },
	{ name = "phone_bind_360x640", platform = "touch", width = 360, height = 640, bind = "running" },
	{ name = "pc_trial_1280x720", platform = "pc", width = 1280, height = 720, trial = true },
	{ name = "phone_trial_360x640", platform = "touch", width = 360, height = 640, trial = true },
	{ name = "phone_crucible_confirm_360x640", platform = "touch", width = 360, height = 640, crucible = "confirm" },
	{ name = "pc_crucible_focus_1280x720", platform = "pc", width = 1280, height = 720, crucible = "focus" },
	{ name = "phone_crucible_focus_360x640", platform = "touch", width = 360, height = 640, crucible = "focus" },
	{ name = "pc_bind_1280x720", platform = "pc", width = 1280, height = 720, bind = "running" },
}

if not fs.isDir("build") then
	fs.writeDir("build")
end
for _, c in cases do
	local state = {
		width = c.width,
		height = c.height,
		platform = c.platform,
		health = 72,
		healthMax = 100,
		qi = 38,
		qiMax = 100,
		slots = slots(c.platform),
		gaps = { "Guard" },
		shell = {
			width = c.width,
			height = c.height,
			platform = c.platform,
			rank = 1,
			stage = if c.trial then 4 else 2,
			progress = if c.trial then 1 else 0.45,
			ready = c.trial == true,
			atRest = c.bind == nil,
			trial = if c.trial then { wave = 2, waves = 3, crack = 0.55, timeLeft = 14 } else nil,
			shards = 120,
		},
		crucible = if c.crucible
			then {
				width = c.width,
				height = c.height,
				platform = c.platform,
				phase = c.crucible,
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
			}
			else nil,
		bind = if c.bind
			then {
				width = c.width,
				height = c.height,
				platform = c.platform,
				bindState = c.bind,
				progress = 0.62,
				shards = 2,
				heart = false,
				canBind = false,
			}
			else nil,
	}
	fs.writeFile(`build/hud_{c.name}.html`, html(state))
	print(`build/hud_{c.name}.html`)
end
