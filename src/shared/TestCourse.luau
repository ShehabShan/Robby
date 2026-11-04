--!strict
-- TestCourse (T-059b, D-467): pure layout of the movement test course from `.ai/MOVEMENT_PLAN.md` §6:
-- flat run strip, stairs, a ledge (for slam/air-dash height), ruler walls 4/6/8 studs, distance marks.
-- Boxes are { name, size, offset } relative to the course origin (floor top at y = 0). No game services here.
local TestCourse = {}

export type Box = { name: string, size: { number }, offset: { number }, color: string }

TestCourse.WALL_HEIGHTS = { 4, 6, 8 }
TestCourse.LEDGE_HEIGHT = 12 -- slam test height (plan §6.2)
TestCourse.STEP_RISE = 1
TestCourse.STEPS = 8

local function box(
	name: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: string
): Box
	return { name = name, size = { sx, sy, sz }, offset = { x, y, z }, color = color }
end

function TestCourse.boxes(): { Box }
	local out: { Box } = {}
	-- floor slab 80 x 120, top at y = 0
	table.insert(out, box("Floor", 80, 2, 120, 0, -1, 0, "floor"))
	-- flat run strip with a mark every 10 studs along -z (distance read-out for dash/carry tests)
	for i = 0, 10 do
		table.insert(
			out,
			box(`Mark{i * 10}`, 6, 0.1, 0.4, -30, 0.05, 50 - i * 10, if i % 5 == 0 then "accent" else "mark")
		)
	end
	-- ruler walls 4 / 6 / 8 studs, 2 thick, 8 wide
	for i, h in TestCourse.WALL_HEIGHTS do
		table.insert(out, box(`Wall{h}`, 8, h, 2, -12 + (i - 1) * 12, h / 2, 30, "wall"))
	end
	-- stairs: STEPS steps of STEP_RISE, 2 deep, 8 wide, climbing toward -z
	for i = 1, TestCourse.STEPS do
		local h = i * TestCourse.STEP_RISE
		table.insert(out, box(`Step{i}`, 8, h, 2, 12, h / 2, 10 - i * 2, "wall"))
	end
	-- ledge platform (top at LEDGE_HEIGHT) with a ladder-like 4-stud staircase is not needed: the 8-stud stairs
	-- top out next to a 12-stud tower reached by a vault/climb; the tower drops onto open floor for slam tests.
	local lh = TestCourse.LEDGE_HEIGHT
	table.insert(out, box("Ledge", 12, lh, 12, 26, lh / 2, -20, "ledge"))
	table.insert(out, box("LedgeStep", 8, 6, 4, 26, 3, -12, "wall"))
	return out
end

-- Highest top surface (studs) of any box; used by specs and the builder.
function TestCourse.top(b: Box): number
	return b.offset[2] + b.size[2] / 2
end

return TestCourse
