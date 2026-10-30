local Config = require("../src/shared/Config")
local FxRegistry = require("../src/shared/FxRegistry")
local TelegraphFx = require("../src/shared/TelegraphFx")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, msg: string?)
	if math.abs(actual - expected) > 1e-3 then
		error(`{msg or "value"}: expected {expected}, got {actual}`, 2)
	end
end

return {
	["telegraphfx: fx id is valid for FxRegistry"] = function()
		eq(FxRegistry.isValidId(TelegraphFx.FX_ID), true, "valid id")
	end,
	["telegraphfx: Mistfang gets a front cone sized to its reach"] = function()
		local p = TelegraphFx.params(Config.Beasts.kinds["beast.mistfang"])
		eq(p.allRound, false, "cone")
		eq(p.radius, 7, "radius")
		near(p.seconds, 0.45, "seconds")
		near(p.coneDeg, 2 * math.deg(math.acos(0.2)), "cone width")
	end,
	["telegraphfx: Stonehide slam is a full circle, lower pitch"] = function()
		local boar = TelegraphFx.params(Config.Beasts.kinds["beast.stonehide"])
		local wolf = TelegraphFx.params(Config.Beasts.kinds["beast.mistfang"])
		eq(boar.allRound, true, "circle")
		eq(boar.coneDeg, 360, "360")
		eq(boar.pitch < wolf.pitch, true, "boar lower")
	end,
	["telegraphfx: every configured beast telegraphs at least minTelegraph"] = function()
		for id, k in Config.Beasts.kinds do
			eq(TelegraphFx.params(k).seconds >= Config.Beasts.minTelegraph, true, id)
		end
	end,
	["telegraphfx: bad input falls back safely"] = function()
		local p = TelegraphFx.params(nil)
		eq(p.allRound, true, "default circle")
		eq(p.seconds >= 0.4, true, "min seconds")
		eq(TelegraphFx.params({ telegraph = 0.1 }).seconds, 0.4, "clamped")
	end,
	["telegraphfx: edge detects start and stop only"] = function()
		eq(TelegraphFx.edge(nil, true), "start", "start")
		eq(TelegraphFx.edge(true, false), "stop", "stop")
		eq(TelegraphFx.edge(true, true), nil, "hold")
		eq(TelegraphFx.edge(false, nil), nil, "idle")
	end,
	["telegraphfx: fill runs 0 to 1"] = function()
		eq(TelegraphFx.fill(0, 0.8), 0, "start")
		near(TelegraphFx.fill(0.4, 0.8), 0.5, "half")
		eq(TelegraphFx.fill(5, 0.8), 1, "clamped")
		eq(TelegraphFx.fill(0, 0), 1, "zero")
	end,
}
