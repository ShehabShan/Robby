--!strict
-- HUD layout (T-016c, D-036, D-068). Pure: turns HUD state + viewport size into pixel elements.
-- The client (src/client/Hud.luau) and the mock renderer (scripts/hud_mock.luau) draw the same list,
-- so the mock shows exactly what the game shows. List order is draw order (later = on top).

local HudLayout = {}

export type Rgb = { number }
export type Element = {
	id: string,
	kind: string, -- "panel" | "fill" | "slot" | "text" | "dot" | "strain"
	x: number,
	y: number,
	w: number,
	h: number,
	color: Rgb,
	alpha: number?, -- 0..1 opacity, default 1
	text: string?,
	textSize: number?,
	align: string?, -- "left" | "center" | "right" (text only, default center)
}
export type SlotState = {
	role: string?,
	name: string?,
	key: string?, -- input hint (PC / gamepad only)
	strain: number?, -- 0..1, nil = not shown
	satiety: number?, -- 0..1, nil = not shown
	cooldown: number?, -- 0..1 remaining
}
export type State = {
	width: number,
	height: number,
	platform: string, -- "touch" | "pc" | "gamepad"
	health: number,
	healthMax: number,
	qi: number,
	qiMax: number,
	slots: { SlotState },
	gaps: { string },
	version: string?, -- corner label, e.g. "v0.0.17 (Roblox 18)" (T-029); nil = not shown
}

HudLayout.ROLE_CODE = {
	Strike = "STK",
	Guard = "GRD",
	Mend = "MND",
	Carry = "CRY",
	Stride = "STR",
	Seek = "SEK",
} :: { [string]: string }
HudLayout.ROLE_COLOR = {
	Strike = { 200, 70, 60 },
	Guard = { 130, 110, 80 },
	Mend = { 60, 160, 95 },
	Carry = { 175, 140, 50 },
	Stride = { 50, 140, 185 },
	Seek = { 135, 90, 190 },
} :: { [string]: Rgb }
HudLayout.SLOT_SIZE = { touch = 56, pc = 48, gamepad = 52 } :: { [string]: number }
HudLayout.MIN_TOUCH = 44 -- Roblox / platform guideline for touch targets
HudLayout.MIN_TEXT = 12

local GAP = 8
local MARGIN = 12
local JUMP_ZONE = 110 -- bottom-right area kept free for the Roblox touch jump button
local EMPTY: Rgb = { 45, 50, 60 }
local UNKNOWN: Rgb = { 110, 110, 120 }
local WHITE: Rgb = { 245, 245, 250 }

local function clamp01(v: number): number
	return math.clamp(v, 0, 1)
end

local function frac(v: number, max: number): number
	if max <= 0 then
		return 0
	end
	return clamp01(v / max)
end

function HudLayout.slotSize(platform: string): number
	local size = HudLayout.SLOT_SIZE[platform] or 48
	if platform == "touch" then
		size = math.max(size, HudLayout.MIN_TOUCH)
	end
	return size
end

function HudLayout.roleCode(role: string?): string
	if role == nil then
		return "+"
	end
	return HudLayout.ROLE_CODE[role] or "?"
end

function HudLayout.satietyColor(v: number): Rgb
	if v >= 0.5 then
		return { 110, 210, 110 }
	elseif v >= 0.2 then
		return { 240, 190, 70 }
	end
	return { 230, 80, 70 }
end

function HudLayout.gapText(gaps: { string }): string?
	if #gaps == 0 then
		return nil
	end
	return `No {table.concat(gaps, " or ")} Kith equipped`
end

local function bar(
	out: { Element },
	id: string,
	x: number,
	y: number,
	w: number,
	h: number,
	value: number,
	max: number,
	color: Rgb,
	label: string
)
	table.insert(
		out,
		{ id = id .. "Back", kind = "panel", x = x, y = y, w = w, h = h, color = { 20, 24, 32 }, alpha = 0.75 }
	)
	table.insert(out, {
		id = id .. "Fill",
		kind = "fill",
		x = x,
		y = y,
		w = math.floor(w * frac(value, max) + 0.5),
		h = h,
		color = color,
	})
	local text = `{label} {math.floor(value + 0.5)} / {math.floor(max + 0.5)}`
	table.insert(out, {
		id = id .. "Text",
		kind = "text",
		x = x + 6,
		y = y,
		w = w - 12,
		h = h,
		color = WHITE,
		text = text,
		textSize = math.max(HudLayout.MIN_TEXT, h - 4),
		align = "left",
	})
end

local function slot(out: { Element }, i: number, s: SlotState, x: number, y: number, size: number, platform: string)
	local role = s.role
	local filled = s.name ~= nil or role ~= nil
	local color = if role == nil then EMPTY else (HudLayout.ROLE_COLOR[role] or UNKNOWN)
	table.insert(out, {
		id = `slot{i}`,
		kind = "slot",
		x = x,
		y = y,
		w = size,
		h = size,
		color = color,
		alpha = if filled then 0.92 else 0.55,
	})
	local cd = s.cooldown
	if cd ~= nil and cd > 0 then
		local h = math.floor(size * clamp01(cd) + 0.5)
		table.insert(
			out,
			{ id = `slot{i}Cd`, kind = "fill", x = x, y = y, w = size, h = h, color = { 0, 0, 0 }, alpha = 0.55 }
		)
	end
	table.insert(out, {
		id = `slot{i}Role`,
		kind = "text",
		x = x,
		y = y,
		w = size,
		h = size,
		color = WHITE,
		text = HudLayout.roleCode(role),
		textSize = math.max(HudLayout.MIN_TEXT + 2, math.floor(size * 0.3)),
	})
	if s.key ~= nil and platform ~= "touch" then
		table.insert(out, {
			id = `slot{i}Key`,
			kind = "text",
			x = x + 4,
			y = y + 2,
			w = size - 8,
			h = 14,
			color = { 225, 230, 240 },
			text = s.key,
			textSize = HudLayout.MIN_TEXT,
			align = "left",
		})
	end
	local strain = s.strain
	if strain ~= nil then
		-- D-036 draws Strain as an arc on the button; the layout gives a bottom strip that a ring image can replace.
		local w = math.floor(size * clamp01(strain) + 0.5)
		table.insert(
			out,
			{ id = `slot{i}Strain`, kind = "strain", x = x, y = y + size - 5, w = w, h = 5, color = { 245, 120, 50 } }
		)
	end
	local sat = s.satiety
	if sat ~= nil then
		table.insert(out, {
			id = `slot{i}Sat`,
			kind = "dot",
			x = x + size - 12,
			y = y + 4,
			w = 8,
			h = 8,
			color = HudLayout.satietyColor(sat),
		})
	end
end

function HudLayout.build(state: State): { Element }
	local out: { Element } = {}
	local platform = state.platform
	local touch = platform == "touch"

	-- Health + Qi bars, top-left (D-036: the only bars on the phone HUD).
	local barW = math.min(math.floor(state.width * 0.5), 280)
	local barH = if touch then 18 else 16
	bar(out, "health", MARGIN, MARGIN, barW, barH, state.health, state.healthMax, { 200, 60, 60 }, "HP")
	bar(out, "qi", MARGIN, MARGIN + barH + 4, barW, barH, state.qi, state.qiMax, { 70, 150, 230 }, "Qi")

	-- Slot bar: touch = right-aligned grid above the jump button; PC/gamepad = centered bottom row.
	local n = #state.slots
	local size = HudLayout.slotSize(platform)
	local step = size + GAP
	local cols: number
	if touch then
		cols = math.floor((state.width * 0.62 + GAP) / step)
	else
		cols = math.floor((state.width - 2 * MARGIN + GAP) / step)
	end
	cols = math.max(1, math.min(math.max(n, 1), cols))
	local rows = math.ceil(n / cols)
	local blockW = cols * step - GAP
	local left = if touch then state.width - MARGIN - blockW else math.floor((state.width - blockW) / 2)
	local bottom = if touch then state.height - JUMP_ZONE else state.height - MARGIN
	local top = bottom - (rows * step - GAP)
	for i, s in state.slots do
		local k = i - 1
		local x = left + (k % cols) * step
		local y = top + (k // cols) * step
		slot(out, i, s, x, y, size, platform)
	end

	if state.version ~= nil then
		local h = 16
		table.insert(out, {
			id = "version",
			kind = "text",
			x = state.width - MARGIN - 180,
			y = MARGIN,
			w = 180,
			h = h,
			color = { 150, 155, 165 },
			alpha = 0.8,
			text = state.version,
			textSize = HudLayout.MIN_TEXT,
			align = "right",
		})
	end

	local warn = HudLayout.gapText(state.gaps)
	if warn ~= nil then
		local h = 20
		table.insert(out, {
			id = "gapWarn",
			kind = "text",
			x = MARGIN,
			y = top - h - 6,
			w = state.width - 2 * MARGIN,
			h = h,
			color = { 255, 195, 90 },
			text = warn,
			textSize = 14,
			align = if touch then "right" else "center",
		})
	end
	return out
end

return HudLayout
