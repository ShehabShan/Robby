local RankTest = require("../src/shared/RankTest")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local BOSS = { rankTest = "academy" }

return {
	["first kill passes the test once"] = function()
		local data = { trials = {} }
		eq(RankTest.passed(data, "academy"), false, "before")
		eq(RankTest.credit(data, BOSS, 10), true, "first")
		eq(RankTest.passed(data, "academy"), true, "after")
		eq(data.trials.academy.at, 10, "time")
	end,
	["repeat kills count but are not first"] = function()
		local data = { trials = {} }
		RankTest.credit(data, BOSS, 1)
		eq(RankTest.credit(data, BOSS, 2), false, "second")
		eq(data.trials.academy.count, 2, "count")
		eq(data.trials.academy.at, 1, "first time kept")
	end,
	["non-test boss and bad data do nothing"] = function()
		local data = { trials = {} }
		eq(RankTest.credit(data, { name = "x" }, 1), false, "no rankTest")
		eq(next(data.trials), nil, "untouched")
		eq(RankTest.credit(nil, BOSS, 1), false, "nil data")
		eq(RankTest.passed({}, "academy"), false, "no trials")
	end,
	["old save without trials gets the table"] = function()
		local data = {}
		eq(RankTest.credit(data, BOSS, 1), true, "credited")
		eq(RankTest.passed(data, "academy"), true, "passed")
	end,
}
