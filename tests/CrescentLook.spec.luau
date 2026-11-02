--!strict
-- Crescent Cut art-blade rules (T-053a3, D-385).
local CrescentLook = require("../src/shared/CrescentLook")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end
local function near(a: number, b: number, msg: string?)
	if math.abs(a - b) > 1e-6 then
		error(`{msg or "value"}: expected ~{b}, got {a}`, 2)
	end
end

local T = Config.Fx.CrescentCut

return {
	["look: art needs the setting and a texture"] = function()
		eq(CrescentLook.choose(T, "rbxassetid://1"), if T.look == "Art" then "Art" else "Classic")
		eq(CrescentLook.choose({ look = "Art" } :: any, nil), "Classic")
		eq(CrescentLook.choose({ look = "Classic" } :: any, "rbxassetid://1"), "Classic")
	end,
	["look: grow-in from 0.6 to 1 over 0.06 s"] = function()
		near(T.growFrom, 0.6)
		near(T.growTime, 0.06)
		near(CrescentLook.scaleAt(T, 0), 0.6)
		near(CrescentLook.scaleAt(T, 0.06), 1)
		near(CrescentLook.scaleAt(T, 5), 1)
		local mid = CrescentLook.scaleAt(T, 0.03)
		assert(mid > 0.8 and mid < 1, "ease-out mid")
		near(CrescentLook.scaleAt(T, 0 / 0), 1, "nan")
	end,
	["look: roll grows with travel"] = function()
		near(CrescentLook.rollAt(T, 0, 60), 0)
		near(CrescentLook.rollAt(T, 60, 60), math.rad(T.rollDeg))
		near(CrescentLook.rollAt(T, 90, 60), math.rad(T.rollDeg), "clamped")
		near(CrescentLook.rollAt(T, 10, 0), 0, "zero range")
	end,
	["look: dissolve fades and widens over 0.12 s"] = function()
		near(T.dissolveTime, 0.12)
		local v0, w0, d0 = CrescentLook.dissolveAt(T, 0)
		near(v0, 1)
		near(w0, 1)
		eq(d0, false)
		local v1, w1, d1 = CrescentLook.dissolveAt(T, 0.12)
		near(v1, 0)
		near(w1, T.dissolveWiden)
		eq(d1, true)
	end,
	["look: blade stops at a closer world hit"] = function()
		eq(CrescentLook.stopDistance(60, 20), 20)
		eq(CrescentLook.stopDistance(60, nil), 60)
		eq(CrescentLook.stopDistance(60, 80), 60)
		eq(CrescentLook.stopDistance(60, 0 / 0), 60)
	end,
	["look: pool caps live blades and reuses"] = function()
		local p = CrescentLook.newPool(2)
		eq(CrescentLook.acquire(p), "new")
		eq(CrescentLook.acquire(p), "new")
		eq(CrescentLook.acquire(p), "full")
		CrescentLook.release(p)
		eq(CrescentLook.acquire(p), "reuse")
		eq(p.live, 2)
		CrescentLook.release(p)
		CrescentLook.release(p)
		CrescentLook.release(p) -- extra release is harmless
		eq(p.live, 0)
		eq(p.free, 2)
		assert(T.maxLive <= 8, "plan: at most 8 live blades")
	end,
}
