local RateLimit = require("../src/shared/RateLimit")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["burst is allowed, then blocked"] = function()
		local b = RateLimit.new(3, 0)
		for i = 1, 3 do
			eq(RateLimit.allow(b, 0, 1, 3), true, `call {i}`)
		end
		eq(RateLimit.allow(b, 0, 1, 3), false, "over burst")
	end,
	["tokens refill at rate, capped at burst"] = function()
		local b = RateLimit.new(2, 0)
		RateLimit.allow(b, 0, 2, 2)
		RateLimit.allow(b, 0, 2, 2)
		eq(RateLimit.allow(b, 0.25, 2, 2), false, "half token")
		eq(RateLimit.allow(b, 0.5, 2, 2), true, "one token back")
		RateLimit.allow(b, 100, 2, 2)
		eq(b.tokens <= 2, true, "capped")
	end,
	["clock going backwards does not add tokens"] = function()
		local b = RateLimit.new(1, 10)
		RateLimit.allow(b, 10, 1, 1)
		eq(RateLimit.allow(b, 5, 1, 1), false, "no refill")
	end,
}
