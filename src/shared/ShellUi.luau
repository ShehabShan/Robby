--!strict
-- Core Shell HUD layout (T-018d, D-076): top-right shell icon (colour per Stage shell), "R<rank> <Stage>" label,
-- Stage bar, and a hold-to-Refine button while at a rest spot. Pure; `src/client/ShellHud.luau` draws it,
-- `scripts/hud_mock.sh` renders it. Keys: PC hold H, gamepad hold D-pad Down, touch = button.

local HudLayout = require("./HudLayout")
local Stages = require("./Stages")

export type State = {
	width: number,
	height: number,
	platform: string, -- "touch" | "pc" | "gamepad"
	rank: number,
	stage: number,
	progress: number, -- 0..1 of the current Stage
	ready: boolean, -- full Peak: breakthrough trial ready
	atRest: boolean,
	shards: number,
}

local ShellUi = {}

ShellUi.KEYS = { pc = "H", gamepad = "Down" } :: { [string]: string }
ShellUi.BUTTON_H = { touch = 56, pc = 40, gamepad = 44 } :: { [string]: number }
ShellUi.SHELL_COLOR = {
	mist = { 200, 210, 225 },
	water = { 70, 140, 220 },
	stone = { 150, 130, 105 },
	crystal = { 170, 235, 250 },
} :: { [string]: HudLayout.Rgb }

local MARGIN = 12
local ICON = 28
local WHITE: HudLayout.Rgb = { 245, 245, 250 }

function ShellUi.label(s: State): string
	local name = Stages.NAMES[s.stage] or "?"
	return if s.ready then `R{s.rank} {name} · ready` else `R{s.rank} {name}`
end

function ShellUi.build(s: State): { HudLayout.Element }
	local out: { HudLayout.Element } = {}
	local w = math.min(160, math.floor(s.width * 0.4))
	local x0 = s.width - MARGIN - w
	local stage = math.clamp(math.floor(s.stage), 1, #Stages.NAMES)
	local color = ShellUi.SHELL_COLOR[Stages.SHELL[stage]]
	local bx, bw = x0 + ICON + 6, w - ICON - 6
	table.insert(out, { id = "shellIcon", kind = "dot", x = x0, y = MARGIN, w = ICON, h = ICON, color = color })
	table.insert(out, {
		id = "shellName",
		kind = "text",
		x = bx,
		y = MARGIN,
		w = bw,
		h = 16,
		color = WHITE,
		text = ShellUi.label(s),
		textSize = HudLayout.MIN_TEXT,
		align = "left",
	})
	table.insert(out, {
		id = "shellBack",
		kind = "panel",
		x = bx,
		y = MARGIN + 18,
		w = bw,
		h = 10,
		color = { 20, 24, 32 },
		alpha = 0.75,
	})
	table.insert(out, {
		id = "shellFill",
		kind = "fill",
		x = bx,
		y = MARGIN + 18,
		w = math.floor(bw * math.clamp(s.progress, 0, 1) + 0.5),
		h = 10,
		color = color,
	})
	if s.atRest then
		local key = ShellUi.KEYS[s.platform]
		table.insert(out, {
			id = "shellRefine",
			kind = "button",
			x = x0,
			y = MARGIN + ICON + 8,
			w = w,
			h = ShellUi.BUTTON_H[s.platform] or 44,
			color = { 70, 150, 230 },
			alpha = 0.85,
			text = `Refine ×{s.shards}` .. (if key then ` [{key}]` else ""),
			textSize = if s.platform == "touch" then 16 else 14,
		})
	end
	return out
end

return ShellUi
