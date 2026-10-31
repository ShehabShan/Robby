local LoadoutScreen = require("../src/shared/LoadoutScreen")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local ROLES = { ["kith.crescent"] = "Strike", ["kith.stone"] = "Guard", ["kith.wind"] = "Stride" }

local function state(platform: string, w: number, h: number, n: number): any
	local slots, uids = {}, {}
	for i = 1, n do
		slots[i] = if i == 1 then { role = "Strike", name = "kith.crescent" } else {}
		uids[i] = if i == 1 then "u1" else nil
	end
	return {
		width = w,
		height = h,
		platform = platform,
		slots = slots,
		slotUids = uids,
		owned = LoadoutScreen.parseOwned("u2=kith.stone,u1=kith.crescent,u3=kith.wind"),
		roles = ROLES,
		selected = 2,
	}
end

local function byId(els: { any }): { [string]: any }
	local m = {}
	for _, e in els do
		m[e.id] = e
	end
	return m
end

return {
	["screen: owned list round-trips and sorts"] = function()
		local owned = LoadoutScreen.parseOwned(
			LoadoutScreen.encodeOwned({ b = { speciesId = "kith.wind" }, a = { speciesId = "kith.stone" } })
		)
		eq(#owned, 2, "count")
		eq(owned[1].uid, "a", "sorted")
		eq(owned[2].species, "kith.wind", "species")
		eq(#LoadoutScreen.parseOwned(nil), 0, "nil")
	end,
	["screen: pick sends Equip for the selected slot"] = function()
		local m = LoadoutScreen.new()
		m = LoadoutScreen.reduce(m, { kind = "toggle" }, 3)
		eq(m.open, true, "open")
		m = LoadoutScreen.reduce(m, { kind = "slot", slot = 3 }, 3)
		local _, req = LoadoutScreen.reduce(m, { kind = "pick", uid = "u2" }, 3)
		eq(req and req.slot, 3, "slot")
		eq(req and req.uid, "u2", "uid")
	end,
	["screen: unequip sends an empty uid; closed screen sends nothing"] = function()
		local m = LoadoutScreen.reduce(LoadoutScreen.new(), { kind = "toggle" }, 3)
		local _, req = LoadoutScreen.reduce(m, { kind = "unequip" }, 3)
		eq(req and req.uid, "", "unequip")
		local _, none = LoadoutScreen.reduce(LoadoutScreen.new(), { kind = "pick", uid = "u1" }, 3)
		eq(none, nil, "closed")
	end,
	["screen: slot selection is clamped to the slot count"] = function()
		local m = LoadoutScreen.reduce(LoadoutScreen.new(), { kind = "toggle" }, 3)
		m = LoadoutScreen.reduce(m, { kind = "slot", slot = 9 }, 3)
		eq(m.selected, 3, "clamped")
	end,
	["screen: phone layout fits 360x640 with >= 44 px buttons"] = function()
		for _, e in LoadoutScreen.build(state("touch", 360, 640, 7)) do
			eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= 360 and e.y + e.h <= 640, true, `{e.id} inside`)
			if e.kind == "button" then
				eq(e.w >= 44 and e.h >= 44, true, `{e.id} touch size`)
			end
		end
	end,
	["screen: buttons carry actions; equipped Kith are tagged"] = function()
		local m = byId(LoadoutScreen.build(state("pc", 1280, 720, 3)))
		eq(m.slot2.action.slot, 2, "slot action")
		eq(m.kith1.action.uid, "u1", "pick action")
		eq(m.kith1.text, "Crescent · Strike (slot 1)", "equipped tag")
		eq(m.kith2.text, "Stone · Guard", "label")
		eq(m.unequip.action.kind, "unequip", "unequip")
		eq(m.selected ~= nil, true, "selection outline")
	end,
	["loadout: select hint on every platform"] = function()
		for _, p in { "touch", "pc", "gamepad" } do
			local m = byId(LoadoutScreen.build(state(p, 1280, 720, 3)))
			assert(m.selectHint ~= nil and m.selectHint.text == LoadoutScreen.selectHint(p), `{p} select hint`)
		end
		assert(LoadoutScreen.selectHint("touch"):find("Tap") ~= nil, "touch says tap")
	end,
	["inventory: care state per Kith with a plain help line (T-039a)"] = function()
		local cfg = { Upkeep = { satietyMax = 100, strainMax = 100, hungryAt = 30 } }
		local kith = {
			a = { speciesId = "kith.crescent", satiety = 80, strain = 0 },
			b = { speciesId = "kith.stone", satiety = 10, strain = 0 },
			c = { speciesId = "kith.wind", satiety = 0, strain = 0, dormant = true },
			d = { speciesId = "kith.wind", satiety = 50, strain = 100, exhaustedUntil = 20 },
		}
		local care = LoadoutScreen.parseCare(LoadoutScreen.encodeCare(kith, cfg, 10))
		eq(care.a.state, "Ready", "ready")
		eq(care.a.satiety, 80, "pct")
		eq(care.b.state, "Hungry", "hungry")
		eq(care.c.state, "Dormant", "dormant")
		eq(care.d.state, "Exhausted", "exhausted")
		eq(LoadoutScreen.careText(care.d), "Tired 50%", "tired word")
		eq(LoadoutScreen.careText(nil), nil, "no data")
		local s = state("touch", 360, 640, 3)
		s.care = { u1 = { state = "Ready", satiety = 80 }, u2 = { state = "Dormant", satiety = 0 } }
		local list = LoadoutScreen.build(s)
		local m = byId(list)
		eq(m.kith1.text, "Crescent · Strike (slot 1) · Ready 80%", "ready row")
		eq(m.kith2.text, "Stone · Guard · Dormant 0%", "dormant row")
		eq(m.careHelp.text, LoadoutScreen.CARE_HELP, "help line")
		for _, e in list do
			eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= 360 and e.y + e.h <= 640, true, `{e.id} inside`)
		end
	end,
	["loadout: Refine hint shows only with a bonus"] = function()
		assert(LoadoutScreen.refineText(1.5) == "Refine ×1.5", "1.5")
		assert(LoadoutScreen.refineText(1) == nil and LoadoutScreen.refineText(nil) == nil, "no bonus")
	end,
}
