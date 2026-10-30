--!strict
-- Weave Loom panel (T-020d, D-110): view model + layout for setting a Weave at a rest spot. Shows the core move,
-- the support (fits, or why not), Qi cost before → after, Path Friction, Marks boost, the last result and the
-- first-time Resonance hint. Pure; the client draws it (T-020e), `scripts/hud_mock.sh` renders it.

local DamageMath = require("./DamageMath")
local HudLayout = require("./HudLayout")
local Loom = require("./Loom")
local PathMarks = require("./PathMarks")

export type State = {
	width: number,
	height: number,
	platform: string, -- "touch" | "pc" | "gamepad"
	core: string, -- display name
	support: string, -- display name
	fits: boolean,
	why: string?,
	qiBefore: number,
	qiAfter: number,
	friction: number, -- 0 or negative (Loom.friction)
	boost: number, -- 0 or positive (DamageMath.marksBoost)
	woven: boolean, -- this Weave is already set (button clears it)
	result: string?, -- `WeaveResult`: "ok" or the reason
	resonance: boolean, -- first time this Weave was made
}

local LoomUi = {}

LoomUi.KEYS = { pc = "L", gamepad = "Left" } :: { [string]: string }
LoomUi.BUTTON_H = { touch = 56, pc = 40, gamepad = 44 } :: { [string]: number }

local WHITE: HudLayout.Rgb = { 245, 245, 250 }
local WARN: HudLayout.Rgb = { 245, 170, 90 }
local GOOD: HudLayout.Rgb = { 120, 220, 140 }
local MOON: HudLayout.Rgb = { 180, 200, 255 }
local PAD = 12
local ROWS = 7

local function pct(x: number): string
	local v = math.floor(math.abs(x) * 100 + 0.5)
	return if x < 0 then `-{v}%` elseif v > 0 then `+{v}%` else "0%"
end

-- "move.crescent_cut" -> "Crescent Cut" (or the record's `name`).
function LoomUi.nice(rec: any): string
	if rec.name then
		return rec.name
	end
	local base = string.gsub(rec.id, "^%a+%.", "")
	local words = {}
	for word in string.gmatch(base, "[^_]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(words, " ")
end

-- Parses the `Weaves` attribute ("core=support+support,...") into core -> support ids.
function LoomUi.parseWeaves(attr: string?): { [string]: { string } }
	local out: { [string]: { string } } = {}
	for part in string.gmatch(attr or "", "[^,]+") do
		local core, sup = string.match(part, "^([^=]+)=(.*)$")
		if core and sup then
			local list = {}
			for x in string.gmatch(sup, "[^+]+") do
				table.insert(list, x)
			end
			out[core] = list
		end
	end
	return out
end

-- View fields for core move + support from the Registry and the player's Marks. nil if either id is unknown.
function LoomUi.view(cfg: any, built: any, coreId: string, supportId: string, marks: { [string]: number }?): any
	local move = built.moves[coreId]
	local s = built.supports and built.supports[supportId]
	if not move or not s then
		return nil
	end
	local ok, why = Loom.fits(move, s)
	local qi = (move.costs and move.costs.qi) or 0
	local after = if ok then Loom.weave(move, { s }, Loom.weaveIdFor(coreId)).costs.qi else qi
	local path = PathMarks.pathOf(move)
	local own = if path and marks then marks[path] or 0 else 0
	return {
		core = LoomUi.nice(move),
		support = LoomUi.nice(s),
		fits = ok,
		why = why,
		qiBefore = qi,
		qiAfter = after,
		friction = Loom.friction(cfg, path, marks),
		boost = DamageMath.marksBoost(own),
	}
end

-- First (core move, support) that fits among the equipped Kith species, in slot order (M1: one support each).
function LoomUi.pickCore(built: any, species: { string }): (string?, string?)
	local sids = {}
	for id in built.supports or {} do
		table.insert(sids, id)
	end
	table.sort(sids)
	for _, sp in species do
		local k = built.kith[sp]
		for _, moveId in (k and k.moves) or {} do
			local move = built.moves[moveId]
			for _, sid in sids do
				if move and Loom.fits(move, built.supports[sid]) then
					return moveId, sid
				end
			end
		end
	end
	return nil, nil
end

function LoomUi.resultText(s: State): (string?, HudLayout.Rgb)
	if s.resonance then
		return "Resonance! New Weave recorded in your journal.", GOOD
	elseif s.result == "ok" then
		return "Weave set.", GOOD
	elseif s.result then
		return `Refused: {s.result}`, WARN
	end
	return nil, WHITE
end

function LoomUi.build(s: State): { HudLayout.Element }
	local out: { HudLayout.Element } = {}
	local w = math.min(420, s.width - 2 * PAD)
	local x0 = (s.width - w) // 2
	local bh = LoomUi.BUTTON_H[s.platform] or 44
	local h = ROWS * 20 + bh + 3 * PAD + 8
	local y0 = math.max(PAD, (s.height - h) // 2)
	local ix, iw = x0 + PAD, w - 2 * PAD
	local key = LoomUi.KEYS[s.platform]
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
	table.insert(out, {
		id = "loomBack",
		kind = "panel",
		x = x0,
		y = y0,
		w = w,
		h = h,
		color = { 20, 24, 40 },
		alpha = 0.88,
	})
	text("loomTitle", 0, "Weave Loom", MOON)
	text("loomCore", 1, `Core: {s.core}`, WHITE)
	if s.fits then
		text("loomSupport", 2, `Support: {s.support}`, WHITE)
	else
		text("loomSupport", 2, `Support: {s.support} ({s.why or "does not fit"})`, WARN)
	end
	text("loomCost", 3, `Qi cost: {s.qiBefore} → {s.qiAfter}`, if s.qiAfter > s.qiBefore then WARN else WHITE)
	text(
		"loomFriction",
		4,
		if s.friction < 0 then `Path Friction: {pct(s.friction)} power` else "Path Friction: none",
		if s.friction < 0 then WARN else WHITE
	)
	text("loomBoost", 5, `Marks boost: {pct(s.boost)} power`, if s.boost > 0 then GOOD else WHITE)
	local rt, rc = LoomUi.resultText(s)
	if rt then
		text("loomResult", 6, rt, rc)
	end
	local label = if not s.fits then "Cannot weave" elseif s.woven then "Unweave" else "Weave"
	table.insert(out, {
		id = "loomButton",
		kind = "button",
		x = ix,
		y = y0 + h - PAD - bh,
		w = iw,
		h = bh,
		color = if s.fits then { 90, 110, 200 } else { 90, 90, 100 },
		alpha = if s.fits then 0.9 else 0.5,
		text = label .. suffix,
		textSize = if s.platform == "touch" then 16 else 14,
	})
	return out
end

return LoomUi
