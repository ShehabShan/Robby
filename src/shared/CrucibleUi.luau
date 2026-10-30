--!strict
-- Crucible panel layout (T-019e, D-085): confirm (recipe, odds, consequences shown before fusing), focus (bar,
-- zone, needle, round) and result. Pure; the client draws it, `scripts/hud_mock.sh` renders it.
-- Keys: PC C (F is Parry), gamepad D-pad Right, touch = button.

local HudLayout = require("./HudLayout")

export type State = {
	width: number,
	height: number,
	platform: string, -- "touch" | "pc" | "gamepad"
	phase: string, -- "confirm" | "focus" | "result"
	recipe: string, -- e.g. "Crescent + Crescent → Twin Crescent"
	odds: number, -- 0..1 success chance now
	known: boolean,
	catalyst: number, -- Shards spent either way
	woundHours: number,
	round: number?,
	rounds: number,
	needle: number?, -- 0..1
	zone: number?, -- zone centre 0..1
	zoneWidth: number,
	result: string?, -- "success" | "failed" | "refused"
}

local CrucibleUi = {}

CrucibleUi.KEYS = { pc = "C", gamepad = "Right" } :: { [string]: string }
CrucibleUi.BUTTON_H = { touch = 56, pc = 40, gamepad = 44 } :: { [string]: number }

local WHITE: HudLayout.Rgb = { 245, 245, 250 }
local WARN: HudLayout.Rgb = { 245, 170, 90 }
local GOOD: HudLayout.Rgb = { 120, 220, 140 }
local PAD = 12

local function pct(x: number): string
	return `{math.floor(math.clamp(x, 0, 1) * 100 + 0.5)}%`
end

function CrucibleUi.oddsText(s: State): string
	return if s.known then "Known recipe · safe (100%)" else `Experimental · success {pct(s.odds)}`
end

function CrucibleUi.failText(s: State): (string, string?)
	if s.known then
		return `Costs {s.catalyst} Shards`, nil
	end
	return `Fail: {s.catalyst} Shards lost + Qi Recoil`, `1 Kith Wounded {s.woundHours}h · never destroyed`
end

function CrucibleUi.build(s: State): { HudLayout.Element }
	local out: { HudLayout.Element } = {}
	local w = math.min(420, s.width - 2 * PAD)
	local x0 = (s.width - w) // 2
	local bh = CrucibleUi.BUTTON_H[s.platform] or 44
	local h = 4 * 20 + bh + 3 * PAD + 8
	local y0 = math.max(PAD, (s.height - h) // 2)
	local ix, iw = x0 + PAD, w - 2 * PAD
	local key = CrucibleUi.KEYS[s.platform]
	local suffix = if key then ` [{key}]` else ""
	local function text(id: string, row: number, t: string, color: HudLayout.Rgb)
		table.insert(out, {
			id = id,
			kind = "text",
			x = ix,
			y = y0 + PAD + row * 20,
			w = iw,
			h = 16,
			color = color,
			text = t,
			textSize = HudLayout.MIN_TEXT,
			align = "left",
		})
	end
	local function button(id: string, t: string)
		table.insert(out, {
			id = id,
			kind = "button",
			x = ix,
			y = y0 + h - PAD - bh,
			w = iw,
			h = bh,
			color = { 200, 120, 60 },
			alpha = 0.9,
			text = t .. suffix,
			textSize = if s.platform == "touch" then 16 else 14,
		})
	end
	table.insert(out, {
		id = "crucibleBack",
		kind = "panel",
		x = x0,
		y = y0,
		w = w,
		h = h,
		color = { 20, 24, 32 },
		alpha = 0.85,
	})
	text("crucibleTitle", 0, `Crucible: {s.recipe}`, WHITE)
	if s.phase == "confirm" then
		text("crucibleOdds", 1, CrucibleUi.oddsText(s), if s.known then GOOD else WARN)
		local f1, f2 = CrucibleUi.failText(s)
		text("crucibleFail", 2, f1, WHITE)
		if f2 then
			text("crucibleFail2", 3, f2, WHITE)
		end
		button("crucibleFuse", `Fuse ×{s.catalyst}`)
	elseif s.phase == "focus" then
		text("crucibleOdds", 1, `Focus {s.round or 1}/{s.rounds} · success {pct(s.odds)}`, WARN)
		local by = y0 + PAD + 2 * 20
		table.insert(out, {
			id = "focusBack",
			kind = "panel",
			x = ix,
			y = by,
			w = iw,
			h = 16,
			color = { 50, 56, 70 },
			alpha = 1,
		})
		local zw = math.floor(iw * s.zoneWidth + 0.5)
		local zc = ix + math.floor(iw * math.clamp(s.zone or 0.5, 0, 1) + 0.5)
		table.insert(out, {
			id = "focusZone",
			kind = "fill",
			x = math.clamp(zc - zw // 2, ix, ix + iw - zw),
			y = by,
			w = zw,
			h = 16,
			color = GOOD,
		})
		local nx = ix + math.floor((iw - 6) * math.clamp(s.needle or 0, 0, 1) + 0.5)
		table.insert(out, {
			id = "focusNeedle",
			kind = "fill",
			x = nx,
			y = by - 4,
			w = 6,
			h = 24,
			color = WHITE,
		})
		button("focusPress", "Press")
	else
		local r = s.result or "refused"
		local t = if r == "success"
			then "Fusion succeeded"
			elseif r == "failed" then "Fusion failed · Kith Wounded, Recoil"
			else "Cannot fuse these Kith"
		text("crucibleResult", 1, t, if r == "success" then GOOD else WARN)
		button("crucibleClose", "Close")
	end
	return out
end

-- First two different owned Kith that match a recipe (client picks the pair; the server re-checks everything).
function CrucibleUi.pickPair(cfg: any, owned: { { uid: string, species: string } }): (string?, string?, string?)
	for id, r in cfg.Crucible.recipes do
		local x, y = r.inputs[1], r.inputs[2]
		for i, a in owned do
			if a.species == x then
				for j, b in owned do
					if j ~= i and b.species == y then
						return a.uid, b.uid, id
					end
				end
			end
		end
	end
	return nil, nil, nil
end

local function nice(id: string): string
	local words = {}
	for w in string.gmatch((string.gsub(id, "^kith%.", "")), "[^_]+") do
		table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(words, " ")
end

-- "Crescent + Crescent → Twin Crescent"
function CrucibleUi.recipeLabel(r: any): string
	return `{nice(r.inputs[1])} + {nice(r.inputs[2])} → {nice(r.output)}`
end

return CrucibleUi
