--!strict
-- Binding UI layout (T-017c, D-072): the tug-of-war bar, Channel / Shard buttons, the "Bind" prompt and the
-- result line, as HudLayout-style elements (pure; `src/client/BindingHud.luau` draws them, `scripts/hud_mock.sh`
-- renders them). Keys: PC hold B to channel, G = Shard; gamepad hold RB, D-pad Up = Shard; touch = buttons.

local HudLayout = require("./HudLayout")
local BindingRules = require("./BindingRules")

export type State = {
	width: number,
	height: number,
	platform: string, -- "touch" | "pc" | "gamepad"
	bindState: string, -- "" | "running" | "bound" | "fled"
	progress: number, -- 0..1
	shards: number,
	heart: boolean, -- the finished bind made the Heart Kith
	canBind: boolean, -- a weakened wild Kith is in range
}
export type Candidate = { speciesId: any, hp: number, maxHp: number, dist: number }

local BindingUi = {}

BindingUi.KEYS = {
	pc = { bind = "B", shard = "G" },
	gamepad = { bind = "RB", shard = "Up" },
} :: { [string]: { [string]: string } }
BindingUi.BUTTON_H = { touch = 56, pc = 40, gamepad = 44 } :: { [string]: number }

local MARGIN = 24
local GAP = 8
local BAR_H = 22
local WHITE: HudLayout.Rgb = { 245, 245, 250 }

function BindingUi.progressColor(p: number): HudLayout.Rgb
	if p < 0.33 then
		return { 210, 80, 70 }
	elseif p < 0.75 then
		return { 230, 180, 60 }
	end
	return { 80, 190, 110 }
end

-- Index of the nearest bindable candidate (weakened, in range, known species), or nil.
function BindingUi.pickTarget(cfg: any, built: any, cands: { Candidate }): number?
	local best: number?, bestDist = nil, math.huge
	for i, c in cands do
		if BindingRules.canStart(cfg, built, c.speciesId, c.hp, c.maxHp, c.dist) and c.dist < bestDist then
			best, bestDist = i, c.dist
		end
	end
	return best
end

function BindingUi.build(s: State): { HudLayout.Element }
	local out: { HudLayout.Element } = {}
	local touch = s.platform == "touch"
	local keys = BindingUi.KEYS[s.platform]
	local bh = BindingUi.BUTTON_H[s.platform] or 44
	local textSize = if touch then 16 else 14
	local function hint(k: string): string
		return if keys then ` [{keys[k]}]` else ""
	end
	local function button(id: string, text: string, x: number, y: number, w: number, color: HudLayout.Rgb)
		table.insert(out, {
			id = id,
			kind = "button",
			x = x,
			y = y,
			w = w,
			h = bh,
			color = color,
			alpha = 0.85,
			text = text,
			textSize = textSize,
		})
	end
	local function line(id: string, text: string, y: number, color: HudLayout.Rgb, size: number)
		table.insert(out, {
			id = id,
			kind = "text",
			x = MARGIN,
			y = y,
			w = s.width - 2 * MARGIN,
			h = size + 6,
			color = color,
			text = text,
			textSize = size,
		})
	end

	local top = math.floor(s.height * 0.24)
	if s.bindState == "running" then
		local w = math.min(s.width - 2 * MARGIN, 420)
		local x = math.floor((s.width - w) / 2)
		local p = math.clamp(s.progress, 0, 1)
		line("bindTitle", "Binding: hold Channel", top - 28, WHITE, textSize)
		table.insert(
			out,
			{ id = "bindBack", kind = "panel", x = x, y = top, w = w, h = BAR_H, color = { 20, 24, 32 }, alpha = 0.8 }
		)
		table.insert(out, {
			id = "bindFill",
			kind = "fill",
			x = x,
			y = top,
			w = math.floor(w * p + 0.5),
			h = BAR_H,
			color = BindingUi.progressColor(p),
		})
		table.insert(out, {
			id = "bindPct",
			kind = "text",
			x = x,
			y = top,
			w = w,
			h = BAR_H,
			color = WHITE,
			text = `{math.floor(p * 100 + 0.5)}%`,
			textSize = HudLayout.MIN_TEXT + 2,
		})
		local bw = math.min(150, math.floor((w - GAP) / 2))
		local by = top + BAR_H + 14
		local cx = math.floor(s.width / 2)
		button("bindChannel", "Channel" .. hint("bind"), cx - bw - GAP // 2, by, bw, { 70, 150, 230 })
		local shardColor: HudLayout.Rgb = if s.shards >= 1 then { 135, 90, 190 } else { 90, 90, 100 }
		button("bindShard", `Shard ×{s.shards}` .. hint("shard"), cx + GAP // 2, by, bw, shardColor)
		return out
	end

	if s.bindState == "bound" then
		local text = if s.heart then "Bound! It is your Heart Kith." else "Bound! A new Kith joins you."
		line("bindResult", text, top, { 120, 230, 140 }, textSize + 2)
	elseif s.bindState == "fled" then
		line("bindResult", "It fled. Weaken it and try again.", top, { 255, 170, 90 }, textSize + 2)
	end
	if s.canBind then
		local bw = 140
		button("bindStart", "Bind" .. hint("bind"), math.floor((s.width - bw) / 2), math.floor(s.height * 0.45), bw, {
			135,
			90,
			190,
		})
	end
	return out
end

return BindingUi
