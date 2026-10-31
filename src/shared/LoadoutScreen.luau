--!strict
-- Loadout screen (T-016d, D-069). Pure: a selection model plus a layout that turns screen state + viewport
-- into pixel elements. Buttons carry an `action`; the client (src/client/LoadoutScreen.luau) makes them
-- clickable/tappable and gamepad-selectable and sends `reduce`'s request over the Blink `Equip` remote.
-- The server re-checks every request (LoadoutService, D-064).

local HudLayout = require("./HudLayout")
local KithCare = require("./KithCare")

local LoadoutScreen = {}

export type Action = { kind: string, slot: number?, uid: string? } -- "slot" | "pick" | "unequip" | "close"
export type Owned = { uid: string, species: string }
export type Request = { slot: number, uid: string }
export type Model = { open: boolean, selected: number }
export type State = {
	width: number,
	height: number,
	platform: string,
	slots: { HudLayout.SlotState }, -- current loadout (role, name)
	slotUids: { string? },
	owned: { Owned },
	roles: { [string]: string }, -- species id -> role
	selected: number,
	refine: number?, -- Refine multiplier from equipped utility Kith (Refining.multiplier, T-025b2)
	care: { [string]: Care }?, -- uid -> care state (published as `OwnedCare`, T-039a)
}
export type Care = { state: string, satiety: number } -- KithCare state, satiety 0..100 %

-- Player-facing care words (T-039a, D-224): "Exhausted" reads as "Tired" (owner's word).
LoadoutScreen.STATE_LABEL = { Ready = "Ready", Hungry = "Hungry", Dormant = "Dormant", Exhausted = "Tired" }
LoadoutScreen.CARE_HELP = "Hungry = weaker. Dormant = starved, can't fight: feed it a rare meal. "
	.. "Tired = worn out, can't fight: wait to recover."

-- "uid=State:pct,..." for every owned Kith (server publishes it as `OwnedCare`).
function LoadoutScreen.encodeCare(kith: { [string]: any }, cfg: any, now: number): string
	local parts = {}
	for uid, inst in kith do
		if type(inst) == "table" then
			local _, satiety, state = KithCare.view(inst, cfg, now)
			table.insert(parts, `{uid}={state}:{math.floor(satiety * 100 + 0.5)}`)
		end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function LoadoutScreen.parseCare(raw: any): { [string]: Care }
	local out: { [string]: Care } = {}
	if type(raw) ~= "string" then
		return out
	end
	for _, pair in string.split(raw, ",") do
		local uid, state, pct = string.match(pair, "^([^=]+)=(%a+):(%d+)$")
		if uid and state and pct then
			out[uid] = { state = state, satiety = tonumber(pct) :: number }
		end
	end
	return out
end

-- "Ready 80%" / "Tired 40%" for a Kith row, nil without data.
function LoadoutScreen.careText(c: Care?): string?
	if not c then
		return nil
	end
	return `{LoadoutScreen.STATE_LABEL[c.state] or c.state} {c.satiety}%`
end

LoadoutScreen.MIN_TOUCH = HudLayout.MIN_TOUCH

-- "Refine ×1.5" when an equipped utility Kith (e.g. Mist Lotus) boosts Refine, else nil (T-025b2, D-159).
-- Text that tells the player how to select the live slot (T-036b, D-219).
function LoadoutScreen.selectHint(platform: string): string
	if platform == "touch" then
		return "Tap a slot on the HUD to use its Kith"
	elseif platform == "gamepad" then
		return "Y: next slot — its Kith's moves go live"
	end
	return "1–7: select a slot — its Kith's moves go live"
end

function LoadoutScreen.refineText(mult: number?): string?
	if typeof(mult) ~= "number" or mult <= 1.001 then
		return nil
	end
	return string.format("Refine ×%.1f", mult)
end
local WHITE = { 245, 245, 250 }
local MARGIN = 12
local GAP = 8

-- "uid=species,uid=species" (published by LoadoutService as `OwnedKith`) -> sorted list.
function LoadoutScreen.parseOwned(raw: any): { Owned }
	local out: { Owned } = {}
	if type(raw) ~= "string" then
		return out
	end
	for _, pair in string.split(raw, ",") do
		local uid, species = string.match(pair, "^([^=]+)=(.+)$")
		if uid and species then
			table.insert(out, { uid = uid, species = species })
		end
	end
	table.sort(out, function(a, b)
		return a.uid < b.uid
	end)
	return out
end

function LoadoutScreen.encodeOwned(kith: { [string]: any }): string
	local parts = {}
	for uid, inst in kith do
		table.insert(parts, `{uid}={inst.speciesId}`)
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

function LoadoutScreen.new(): Model
	return { open = false, selected = 1 }
end

-- Applies a UI action. Returns the new model and, when something should change, an Equip request.
function LoadoutScreen.reduce(m: Model, a: Action, slotCount: number): (Model, Request?)
	local n = math.max(slotCount, 1)
	local sel = math.clamp(m.selected, 1, n)
	if a.kind == "toggle" then
		return { open = not m.open, selected = sel }, nil
	elseif a.kind == "close" then
		return { open = false, selected = sel }, nil
	elseif not m.open then
		return m, nil
	elseif a.kind == "slot" and a.slot then
		return { open = true, selected = math.clamp(a.slot, 1, n) }, nil
	elseif a.kind == "pick" and a.uid and a.uid ~= "" then
		return { open = true, selected = sel }, { slot = sel, uid = a.uid }
	elseif a.kind == "unequip" then
		return { open = true, selected = sel }, { slot = sel, uid = "" }
	end
	return m, nil
end

local function nameOf(species: string): string
	local short = string.gsub(species, "^kith%.", "")
	return (string.gsub(short, "^%l", string.upper))
end

local function button(
	out: { any },
	id: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: { number },
	text: string,
	size: number,
	action: Action,
	alpha: number?
)
	table.insert(out, {
		id = id,
		kind = "button",
		x = x,
		y = y,
		w = w,
		h = h,
		color = color,
		alpha = alpha or 0.92,
		text = text,
		textSize = size,
		action = action,
	})
end

function LoadoutScreen.build(s: State): { any }
	local out: { any } = {}
	local touch = s.platform == "touch"
	local w = math.min(s.width - 2 * MARGIN, 640)
	local h = math.min(s.height - 2 * MARGIN, 460)
	local x0 = math.floor((s.width - w) / 2)
	local y0 = math.floor((s.height - h) / 2)
	table.insert(
		out,
		{ id = "panel", kind = "panel", x = x0, y = y0, w = w, h = h, color = { 18, 22, 30 }, alpha = 0.9 }
	)
	table.insert(out, {
		id = "title",
		kind = "text",
		x = x0 + MARGIN,
		y = y0 + 8,
		w = w - 80,
		h = 28,
		color = WHITE,
		text = "Loadout",
		textSize = 20,
		align = "left",
	})
	local closeSize = if touch then 44 else 32
	button(
		out,
		"close",
		x0 + w - closeSize - 8,
		y0 + 6,
		closeSize,
		closeSize,
		{ 90, 40, 40 },
		"X",
		16,
		{ kind = "close" }
	)

	local refine = LoadoutScreen.refineText(s.refine)
	if refine then
		table.insert(out, {
			id = "refine",
			kind = "text",
			x = x0 + w - closeSize - 8 - 150,
			y = y0 + 12,
			w = 140,
			h = 20,
			color = { 242, 213, 154 },
			text = refine,
			textSize = 14,
			align = "right",
		})
	end

	-- Core slots row (wraps on narrow screens).
	local size = HudLayout.slotSize(s.platform)
	local step = size + GAP
	local cols = math.max(1, math.min(#s.slots, math.floor((w - 2 * MARGIN + GAP) / step)))
	local top = y0 + 48
	table.insert(out, {
		id = "slotsLabel",
		kind = "text",
		x = x0 + MARGIN,
		y = top,
		w = w - 2 * MARGIN,
		h = 16,
		color = { 180, 190, 205 },
		text = "Core slots",
		textSize = 13,
		align = "left",
	})
	top += 20
	for i, slot in s.slots do
		local k = i - 1
		local x = x0 + MARGIN + (k % cols) * step
		local y = top + (k // cols) * step
		local color = if slot.role then (HudLayout.ROLE_COLOR[slot.role] or { 110, 110, 120 }) else { 45, 50, 60 }
		button(
			out,
			`slot{i}`,
			x,
			y,
			size,
			size,
			color,
			HudLayout.roleCode(slot.role),
			math.max(14, math.floor(size * 0.3)),
			{ kind = "slot", slot = i }
		)
		if i == s.selected then
			table.insert(out, {
				id = "selected",
				kind = "outline",
				x = x - 3,
				y = y - 3,
				w = size + 6,
				h = size + 6,
				color = { 255, 215, 90 },
			})
		end
	end
	local rows = math.max(1, math.ceil(#s.slots / cols))
	top += rows * step + 4

	-- Owned Kith list: one row button each, plus Unequip for the selected slot.
	local rowH = if touch then 48 else 36
	table.insert(out, {
		id = "ownedLabel",
		kind = "text",
		x = x0 + MARGIN,
		y = top,
		w = w - 2 * MARGIN,
		h = 16,
		color = { 180, 190, 205 },
		text = `Kith for slot {s.selected}`,
		textSize = 13,
		align = "left",
	})
	top += 20
	if s.care and next(s.care) then
		table.insert(out, {
			id = "careHelp",
			kind = "text",
			x = x0 + MARGIN,
			y = top,
			w = w - 2 * MARGIN,
			h = 30,
			color = { 200, 205, 215 },
			text = LoadoutScreen.CARE_HELP,
			textSize = 12,
			align = "left",
			wrap = true,
		})
		top += 34
	end
	local listW = w - 2 * MARGIN
	local equipped: { [string]: number } = {}
	for i, uid in s.slotUids do
		if uid then
			equipped[uid] = i
		end
	end
	local bottomLimit = y0 + h - MARGIN - rowH - GAP
	for i, o in s.owned do
		local y = top + (i - 1) * (rowH + 4)
		if y + rowH > bottomLimit then
			break -- scrolling comes with more Kith (later task)
		end
		local role = s.roles[o.species]
		local tag = if equipped[o.uid] then ` (slot {equipped[o.uid]})` else ""
		local care = LoadoutScreen.careText(if s.care then s.care[o.uid] else nil)
		if care then
			tag ..= ` · {care}`
		end
		local color = if role then (HudLayout.ROLE_COLOR[role] or { 110, 110, 120 }) else { 110, 110, 120 }
		button(
			out,
			`kith{i}`,
			x0 + MARGIN,
			y,
			listW,
			rowH,
			color,
			`{nameOf(o.species)} · {role or "?"}{tag}`,
			15,
			{ kind = "pick", uid = o.uid },
			if equipped[o.uid] then 0.6 else 0.92
		)
	end
	button(
		out,
		"unequip",
		x0 + MARGIN,
		y0 + h - MARGIN - rowH,
		math.min(listW, 200),
		rowH,
		{ 70, 70, 80 },
		"Unequip slot",
		15,
		{ kind = "unequip" }
	)
	-- How to make a slot's Kith live (T-036b, D-219): same wording as the HUD key hints.
	table.insert(out, {
		id = "selectHint",
		kind = "text",
		x = x0 + MARGIN,
		y = y0 + h - MARGIN - rowH,
		w = 300,
		h = rowH,
		color = { 180, 190, 205 },
		text = LoadoutScreen.selectHint(s.platform),
		textSize = 13,
		align = "left",
	})
	if not touch then
		local hint = if s.platform == "gamepad" then "Back: close" else "Tab: close"
		table.insert(out, {
			id = "hint",
			kind = "text",
			x = x0 + w - 160 - MARGIN,
			y = y0 + h - MARGIN - rowH,
			w = 160,
			h = rowH,
			color = { 180, 190, 205 },
			text = hint,
			textSize = 13,
			align = "right",
		})
	end
	return out
end

return LoadoutScreen
