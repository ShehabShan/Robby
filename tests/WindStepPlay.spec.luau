local Play = require("../src/shared/WindStepPlay")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["accepts then enforces cooldown"] = function()
		local g = Play.new(1)
		local ok, dx, dz = Play.request(g, 1, 10, 1, 0, 0, 1)
		eq(ok, true, "first")
		eq(dx, 1, "dx")
		eq(dz, 0, "dz")
		local ok2, _, _, why = Play.request(g, 1, 10.5, 1, 0, 0, 1)
		eq(ok2, false, "second")
		eq(why, "cooldown", "reason")
		eq(Play.request(g, 1, 11.1, 1, 0, 0, 1), true, "after cooldown")
	end,
	["falls back to facing when standing still"] = function()
		local g = Play.new(0)
		local ok, dx, dz = Play.request(g, 1, 0, 0, 0, 0, -1)
		eq(ok, true, "ok")
		eq(dx, 0, "dx")
		eq(dz, -1, "dz")
	end,
	["rejects bad payloads without starting cooldown"] = function()
		local g = Play.new(5)
		eq(select(4, Play.request(g, 1, 0, 0 / 0, 0, 0, 1)), "payload", "nan")
		eq(select(4, Play.request(g, 1, 0.01, "x", 0, 0, 1)), "payload", "string")
		eq(select(4, Play.request(g, 1, 0.02, 0, 0, 0, 0)), "direction", "zero")
		eq(Play.request(g, 1, 0.03, 0, 1, 0, 0), true, "valid after rejects")
	end,
	["rate limits spam per player"] = function()
		local g = Play.new(0)
		for i = 1, Play.BURST do
			eq(Play.request(g, 7, i * 0.01, 1, 0, 1, 0), true, "burst " .. i)
		end
		eq(select(4, Play.request(g, 7, 0.1, 1, 0, 1, 0)), "rate", "over burst")
		eq(Play.request(g, 8, 0.1, 1, 0, 1, 0), true, "other player unaffected")
		eq(Play.request(g, 7, 1.2, 1, 0, 1, 0), true, "window passed")
	end,
	["refund and forget clear state"] = function()
		local g = Play.new(3)
		Play.request(g, 1, 0, 1, 0, 1, 0)
		eq(Play.remaining(g, 1, 1), 2, "remaining")
		Play.refund(g, 1)
		eq(Play.remaining(g, 1, 1), 0, "refunded")
		Play.forget(g, 1)
		eq(g.hits[1], nil, "forgotten")
	end,
	["bad cooldown uses default"] = function()
		eq(Play.new(-1).cooldown, Play.COOLDOWN, "negative")
		eq(Play.new(0 / 0).cooldown, Play.COOLDOWN, "nan")
	end,
}
