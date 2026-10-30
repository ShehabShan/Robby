-- HUD mock renderer (T-016c, D-068): draws HudLayout.build() as HTML so a headless browser can screenshot it.
-- Usage: `lune run scripts/hud_mock.luau` -> build/hud_<name>.html; scripts/hud_mock.sh turns them into PNGs.

local fs = require("@lune/fs")
local HudLayout = require("../src/shared/HudLayout")

local function rgba(c: { number }, a: number?): string
	return `rgba({c[1]},{c[2]},{c[3]},{a or 1})`
end

local function html(state: any): string
	local parts = {
		`<!doctype html><html><body style="margin:0;width:{state.width}px;height:{state.height}px;overflow:hidden;`,
		`background:linear-gradient(180deg,#6d8fb3 0%,#a9c0d6 45%,#5d7a4c 46%,#3e5534 100%);font-family:Arial,sans-serif">`,
	}
	for _, e in HudLayout.build(state) do
		local s = `position:absolute;left:{e.x}px;top:{e.y}px;width:{e.w}px;height:{e.h}px;box-sizing:border-box;`
		local inner = ""
		if e.kind == "text" then
			local justify = if e.align == "left" then "flex-start" elseif e.align == "right" then "flex-end" else "center"
			s ..= `display:flex;align-items:center;justify-content:{justify};color:{rgba(e.color)};font-size:{e.textSize}px;`
			s ..= "font-weight:bold;text-shadow:0 1px 2px #000;white-space:nowrap;"
			inner = e.text or ""
		elseif e.kind == "slot" then
			s ..= `background:{rgba(e.color, e.alpha)};border:2px solid rgba(255,255,255,0.7);border-radius:10px;`
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
	}
	fs.writeFile(`build/hud_{c.name}.html`, html(state))
	print(`build/hud_{c.name}.html`)
end