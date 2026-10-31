local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local FxRegistry = require("../src/shared/FxRegistry")
local CastRequest = require("../src/shared/CastRequest")
local Crescent = require("../src/shared/Content/Crescent")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function built(): any
	local b = Registry.build(Crescent.content(Config))
	return b
end

local function noop(_ctx: any) end

return {
	["fx: every real content id registers and dispatches (Rimeshard regression)"] = function()
		local All = require("../src/shared/Content/All")
		local content = Registry.build(All.content(Config))
		local reg = FxRegistry.new()
		local ids = FxRegistry.missingFor(reg, content)
		local calls = 0
		for _, id in ids do
			eq(
				FxRegistry.register(reg, id, function()
					calls += 1
				end),
				true,
				id .. " registration"
			)
			eq(FxRegistry.play(reg, id, {}), true, id .. " dispatch")
		end
		eq(calls, #ids, "every effect played")
		eq(#FxRegistry.missingFor(reg, content), 0, "all content covered")
	end,
	["fx: nested ids keep strict segment and length validation"] = function()
		for _, id in { "fx.rime.fan.cast", "fx.rime.fall.rain", "fx.a_b.1.cast", "fx.a." .. string.rep("x", 59) } do
			eq(FxRegistry.isValidId(id), true, id)
		end
		for _, id in
			{
				"fx",
				"fx.only",
				"fx..cast",
				"fx.rime..cast",
				"fx.rime.cast.",
				".fx.rime.cast",
				"fx.rime.cast!",
				"fx.rime.cast/extra",
				"fx.rime.cast extra",
				"FX.rime.cast",
				"fx.a." .. string.rep("x", 60),
			}
		do
			eq(FxRegistry.isValidId(id), false, id)
		end
		eq(FxRegistry.isValidId(nil), false)
		eq(FxRegistry.isValidId(123), false)
	end,
	["fx: play calls the registered handler with ctx"] = function()
		local reg = FxRegistry.new()
		local got = nil
		eq(
			FxRegistry.register(reg, "fx.test.a", function(ctx: any)
				got = ctx.n
			end),
			true,
			"register"
		)
		eq(FxRegistry.play(reg, "fx.test.a", { n = 7 }), true, "play")
		eq(got, 7, "ctx passed")
	end,
	["fx: duplicate and malformed ids are refused"] = function()
		local reg = FxRegistry.new()
		eq(FxRegistry.register(reg, "fx.test.a", noop), true)
		eq(FxRegistry.register(reg, "fx.test.a", noop), false, "duplicate")
		eq(FxRegistry.register(reg, "bad", noop), false, "no prefix")
		eq(FxRegistry.register(reg, "fx.only", noop), false, "two parts")
		eq(FxRegistry.register(reg, "fx.a." .. string.rep("x", 80), noop), false, "too long")
	end,
	["fx: unknown ids are counted, never thrown"] = function()
		local reg = FxRegistry.new()
		eq(FxRegistry.play(reg, "fx.none.x", {}), false)
		eq(FxRegistry.play(reg, "fx.none.x", {}), false)
		eq(reg.missing["fx.none.x"], 2, "missing count")
		eq(FxRegistry.play(reg, 5, {}), false, "non-string id")
		eq(FxRegistry.play(reg, "junk", {}), false)
		eq(reg.missing["junk"], nil, "junk not counted")
	end,
	["fx: a failing handler does not propagate"] = function()
		local reg = FxRegistry.new()
		FxRegistry.register(reg, "fx.test.boom", function(_ctx: any)
			error("boom")
		end)
		eq(FxRegistry.play(reg, "fx.test.boom", {}), false)
	end,
	["fx: Crescent ids are listed until handlers exist"] = function()
		local b = built()
		local reg = FxRegistry.new()
		local missing = FxRegistry.missingFor(reg, b)
		eq(#missing, 3, "count")
		eq(missing[1], "fx.crescent.cast")
		eq(missing[2], "fx.crescent.hit")
		eq(missing[3], "fx.crescent.travel")
		for _, id in missing do
			FxRegistry.register(reg, id, noop)
		end
		eq(#FxRegistry.missingFor(reg, b), 0, "all covered")
	end,
	["cast: decode accepts a known move and u16 seq"] = function()
		local b = built()
		local move, seq = CastRequest.decode("move.crescent_cut", 0, b.moves)
		eq(move ~= nil, true, "move")
		eq(move.id, "move.crescent_cut")
		eq(seq, 0)
		eq(select(2, CastRequest.decode("move.crescent_cut", 65535, b.moves)), 65535)
	end,
	["cast: decode rejects unknown moves and bad seq"] = function()
		local moves = built().moves
		eq(CastRequest.decode("move.nope", 1, moves), nil, "unknown move")
		eq(CastRequest.decode(42, 1, moves), nil, "non-string move")
		eq(CastRequest.decode(string.rep("m", 100), 1, moves), nil, "long id")
		eq(CastRequest.decode("move.crescent_cut", -1, moves), nil, "negative")
		eq(CastRequest.decode("move.crescent_cut", 65536, moves), nil, "over u16")
		eq(CastRequest.decode("move.crescent_cut", 1.5, moves), nil, "fraction")
		eq(CastRequest.decode("move.crescent_cut", 0 / 0, moves), nil, "nan")
		eq(CastRequest.decode("move.crescent_cut", "1", moves), nil, "string seq")
	end,
	["cast: nextSeq wraps at u16"] = function()
		eq(CastRequest.nextSeq(0), 1)
		eq(CastRequest.nextSeq(65535), 0)
	end,
}
