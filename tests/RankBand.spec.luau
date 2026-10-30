local RankBand = require("../src/shared/RankBand")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["rank band: gap picks the colour"] = function()
		eq(RankBand.of(1, 1).name, "even", "same")
		eq(RankBand.of(1, 2).name, "warn", "+1")
		eq(RankBand.of(1, 3).name, "danger", "+2")
		eq(RankBand.of(3, 1).name, "weak", "below")
	end,
	["rank band: missing ranks count as Rank 1"] = function()
		eq(RankBand.of(nil, nil).name, "even", "nil")
		eq(RankBand.of("x", 2).name, "warn", "bad viewer")
	end,
}
