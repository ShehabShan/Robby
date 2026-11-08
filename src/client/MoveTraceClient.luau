--!strict
-- MoveTraceClient (T-059b, D-466): debug movement recorder. `Config.TestCourse.traceKey` (F8) starts/stops a
-- trace; on stop it prints a summary and the CSV (`Shared.MoveTrace`) to the output and keeps the last CSV in
-- `MoveTraceClient.last` for cloud tests. Reads only state other scripts publish (attributes, velocity, FOV).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MoveTrace = require(Shared:WaitForChild("MoveTrace"))

local NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Space] = "jump",
	[Enum.KeyCode.ButtonA] = "jump",
	[Enum.KeyCode.Q] = "q",
	[Enum.KeyCode.ButtonB] = "q",
	[Enum.KeyCode.V] = "slam",
	[Enum.KeyCode.ButtonX] = "slam",
}

local MoveTraceClient = {}
MoveTraceClient.last = "" :: string

local trace: MoveTrace.Trace? = nil
local started = 0
local pending: { string } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearance(root: BasePart, character: Model): number
	rayParams.FilterDescendantsInstances = { character }
	local maxDown = 50
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -maxDown, 0), rayParams)
	local hip = root.Size.Y / 2 + 2 -- approx. root centre to feet for R15/robot rigs
	return if hit then math.max(0, (root.Position.Y - hit.Position.Y) - hip) else maxDown
end

local function sample()
	local tr = trace
	local character = Players.LocalPlayer.Character
	if not tr or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local v = root.AssemblyLinearVelocity
	local camera = workspace.CurrentCamera
	MoveTrace.record(tr, {
		t = os.clock() - started,
		input = if #pending > 0 then table.concat(pending, "|") else nil,
		consumed = character:GetAttribute("MoveConsumed") :: string?,
		mode = (character:GetAttribute("MoveMode") :: string?) or humanoid:GetState().Name,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		clearance = clearance(root, character),
		vx = v.X,
		vy = v.Y,
		vz = v.Z,
		stamina = (character:GetAttribute("Stamina") :: number?) or 0,
		charges = (character:GetAttribute("AirDashCharges") :: number?) or -1,
		fov = if camera then camera.FieldOfView else 0,
	})
	table.clear(pending)
	character:SetAttribute("MoveConsumed", nil)
end

local function toggle()
	if trace then
		local tr = trace :: MoveTrace.Trace
		trace = nil
		MoveTraceClient.last = MoveTrace.dump(tr)
		print(MoveTrace.summaryLine(tr))
		print(MoveTraceClient.last)
	else
		trace = MoveTrace.new(Config.TestCourse.traceRows)
		started = os.clock()
		table.clear(pending)
		print("[MoveTrace] recording… press again to stop")
	end
end

function MoveTraceClient.start()
	local cfg = Config.TestCourse
	if not (cfg.always or RunService:IsStudio()) then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode.Name == cfg.traceKey and not processed then
			toggle()
			return
		end
		local name = NAMES[input.KeyCode]
		if trace and name then
			table.insert(pending, name .. "+")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local name = NAMES[input.KeyCode]
		if trace and name then
			table.insert(pending, name .. "-")
		end
	end)
	RunService.Heartbeat:Connect(sample)
end

return MoveTraceClient
