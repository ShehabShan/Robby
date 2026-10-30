local PathMarks = require("../src/shared/PathMarks")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["path marks: Marks attribute round trip (T-020f)"] = function()
		local s = PathMarks.encode({ ["path.moon"] = 12.7, ["path.flame"] = 3 })
		eq(s, "path.flame=3,path.moon=12", "encode")
		local m = PathMarks.decode(s)
		eq(m["path.moon"], 12, "moon")
		eq(m["path.flame"], 3, "flame")
		eq(next(PathMarks.decode(nil)), nil, "nil attr")
		eq(PathMarks.encode(nil), "", "no marks")
	end,
}
