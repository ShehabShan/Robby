--!strict
-- TestCourseBuilder (T-059b, D-467): builds the movement test course (`Shared.TestCourse`) at
-- `Config.TestCourse.origin`, only in Studio unless `Config.TestCourse.always` is true. Thin wiring.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TestCourse = require(Shared:WaitForChild("TestCourse"))

local COLORS: { [string]: string } = {
	floor = "#5b6470",
	mark = "#e8e8e8",
	accent = "#f2c14e",
	wall = "#8a96a3",
	ledge = "#6f7f8f",
}

local TestCourseBuilder = {}

function TestCourseBuilder.start()
	local cfg = Config.TestCourse
	if not (cfg.always or RunService:IsStudio()) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MoveTestCourse"
	local o = cfg.origin
	for _, b in TestCourse.boxes() do
		local part = Instance.new("Part")
		part.Name = b.name
		part.Anchored = true
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
		part.Position = Vector3.new(o[1] + b.offset[1], o[2] + b.offset[2], o[3] + b.offset[3])
		part.Color = Color3.fromHex(COLORS[b.color] or COLORS.wall)
		part.Material = Enum.Material.SmoothPlastic
		if b.color == "mark" or b.color == "accent" then
			part.CanCollide = false
		end
		part.Parent = folder
	end
	folder.Parent = workspace
	print(`[TestCourse] movement test course built at {o[1]},{o[2]},{o[3]}`)
end

return TestCourseBuilder
