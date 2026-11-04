--!strict
local MoveTrace = require("../src/shared/MoveTrace")
local TestCourse = require("../src/shared/TestCourse")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function row(t: number, grounded: boolean, vx: number, vy: number, consumed: string?): MoveTrace.Row
	return {
		t = t,
		input = if consumed then "jump+" else nil,
		consumed = consumed,
		mode = if grounded then "Ground" else "Air",
		grounded = grounded,
		clearance = if grounded then 0 else 5,
		vx = vx,
		vy = vy,
		vz = 0,
		stamina = 100,
		charges = 2,
		fov = 70,
	}
end

return {
	["move trace ring buffer and dump (T-059b)"] = function()
		local tr = MoveTrace.new(3)
		MoveTrace.record(tr, row(0, true, 3, 0, "jump"))
		MoveTrace.record(tr, row(0.1, false, 4, 10))
		MoveTrace.record(tr, row(0.2, false, 18, -30))
		MoveTrace.record(tr, row(0.3, true, 0, 0))
		eq(tr.dropped, 1, "oldest dropped")
		local o = MoveTrace.ordered(tr)
		eq(#o, 3, "capacity kept")
		eq(o[1].t, 0.1, "oldest first")
		eq(o[3].t, 0.3, "newest last")
		local d = MoveTrace.dump(tr)
		local lines = string.split(d, "\n")
		eq(lines[1], MoveTrace.COLUMNS, "header")
		eq(#lines, 4, "header + 3 rows")
		eq(#string.split(lines[2], ","), #string.split(MoveTrace.COLUMNS, ","), "column count")
		eq(lines[3], "0.200,,,Air,0,5.00,18.00,-30.00,0.00,18.00,100.00,2,70.00", "row format")
		local s = MoveTrace.summary(tr)
		eq(s.maxHSpeed, 18, "max h speed")
		eq(s.maxFall, 30, "max fall")
		assert(math.abs(s.airSeconds - 0.2) < 1e-9, "air seconds")
		assert(string.find(MoveTrace.summaryLine(MoveTrace.new(2)), "rows=0", 1, true) ~= nil, "empty summary")
	end,

	["test course layout (T-059b, plan §6)"] = function()
		local walls, steps, ledge = {}, 0, 0
		for _, b in TestCourse.boxes() do
			if string.sub(b.name, 1, 4) == "Wall" then
				table.insert(walls, TestCourse.top(b))
			elseif string.sub(b.name, 1, 4) == "Step" then
				steps += 1
			elseif b.name == "Ledge" then
				ledge = TestCourse.top(b)
			end
			assert(TestCourse.top(b) >= 0, `{b.name} above floor`)
		end
		eq(table.concat(walls, ","), "4,6,8", "ruler walls")
		eq(steps, TestCourse.STEPS, "stairs")
		eq(ledge, 12, "slam ledge height")
	end,
}
