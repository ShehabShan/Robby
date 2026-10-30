local Config = require("../src/shared/Config")
local All = require("../src/shared/Content/All")
local HudLayout = require("../src/shared/HudLayout")
local LoomUi = require("../src/shared/LoomUi")
local Registry = require("../src/shared/Registry")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function byId(els: { any }): { [string]: any }
	local m = {}
	for _, e in els do
		m[e.id] = e
	end
	return m
end

local built = Registry.build(All.content(Config))

local function st(platform: string, w: number, h: number, fits: boolean): any
	return {
		width = w,
		height = h,
		platform = platform,
		core = "Crescent Cut",
		support = "Piercing Edge",
		fits = fits,
		why = if fits then nil else "needs Delivery.Melee",
		qiBefore = 10,
		qiAfter = 14,
		friction = -0.12,
		boost = 0.06,
		woven = false,
		result = nil,
		resonance = true,
	}
end

return {
	["loom ui: view from real content (cost, friction, boost)"] = function()
		local v = LoomUi.view(Config, built, "move.crescent_cut", "support.piercing", nil)
		eq(v.core, "Crescent Cut", "core name")
		eq(v.support, "Piercing Edge", "support name")
		eq(v.fits, true, "fits")
		eq(v.qiBefore, Config.Abilities.CrescentCut.cost, "qi before")
		eq(v.qiAfter, math.ceil(Config.Abilities.CrescentCut.cost * Config.Loom.supports.Piercing.costMult), "qi after")
		eq(v.friction, 0, "no friction without Marks")
		eq(v.boost, 0, "no boost without Marks")
		local v2 = LoomUi.view(Config, built, "move.crescent_cut", "support.piercing", {
			["path.moon"] = 30,
			["path.flame"] = 60,
		})
		eq(v2.friction, -0.2, "full friction")
		eq(v2.boost > 0, true, "marks boost")
		eq(LoomUi.view(Config, built, "move.nope", "support.piercing", nil), nil, "unknown core")
	end,
	["loom ui: misfit support shows why, keeps cost"] = function()
		local fake = {
			moves = built.moves,
			supports = { ["support.melee"] = { id = "support.melee", requireTags = { "Delivery.Melee" } } },
		}
		local v = LoomUi.view(Config, fake, "move.crescent_cut", "support.melee", nil)
		eq(v.fits, false, "misfit")
		eq(v.why, "needs Delivery.Melee", "why")
		eq(v.qiAfter, v.qiBefore, "cost unchanged")
		eq(v.support, "Melee", "derived name")
	end,
	["loom ui: pickCore finds the equipped core + fitting support"] = function()
		local core, sup = LoomUi.pickCore(built, { "kith.stone", "kith.crescent" })
		eq(core ~= nil and built.moves[core] ~= nil, true, "core found")
		eq(sup, "support.piercing", "support")
		eq((LoomUi.pickCore(built, {})), nil, "nothing equipped")
		eq((LoomUi.pickCore(built, { "kith.gone" })), nil, "unknown species")
	end,
	["loom ui: parseWeaves"] = function()
		local m = LoomUi.parseWeaves("move.crescent_cut=support.piercing,move.x=support.a+support.b")
		eq(m["move.crescent_cut"][1], "support.piercing", "one")
		eq(#m["move.x"], 2, "two supports")
		eq(next(LoomUi.parseWeaves(nil)), nil, "empty")
	end,
	["loom ui: layout fits phone and PC, readable text, labels"] = function()
		for _, c in { { "touch", 360, 640 }, { "pc", 1280, 720 }, { "gamepad", 1920, 1080 } } do
			local els = LoomUi.build(st(c[1], c[2], c[3], true))
			for _, e in els do
				eq(e.x >= 0 and e.y >= 0 and e.x + e.w <= c[2] and e.y + e.h <= c[3], true, `{e.id} inside {c[1]}`)
				if e.kind == "text" then
					eq((e.textSize or 0) >= HudLayout.MIN_TEXT, true, `{e.id} text size`)
				end
			end
			local m = byId(els)
			eq(m.loomFriction.text, "Path Friction: -12% power", "friction text")
			eq(m.loomBoost.text, "Marks boost: +6% power", "boost text")
			eq(m.loomCost.text, "Qi cost: 10 → 14", "cost text")
			eq(string.find(m.loomResult.text, "Resonance", 1, true) ~= nil, true, "resonance hint")
		end
		local m = byId(LoomUi.build(st("pc", 1280, 720, false)))
		eq(m.loomButton.text, "Cannot weave [L]", "misfit button")
		eq(string.find(m.loomSupport.text, "needs Delivery.Melee", 1, true) ~= nil, true, "why shown")
	end,
}
