--!strict
-- Disabled, separate test place only. Never includes game startup, persistence or remotes.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Evidence = require(script.Evidence)
if
	not RunService:IsStudio()
	or not RunService:IsServer()
	or not RunService:IsRunning()
	or script:GetAttribute("RunWindStep") ~= true
then
	warn("WIND_STEP_BLOCKED: requires isolated Studio Play, server, and RunWindStep=true")
	return
end
local untilPlayer = os.clock() + 30
repeat
	task.wait(0.1)
until #Players:GetPlayers() > 0 or os.clock() >= untilPlayer
local environment = {
	studio = RunService:IsStudio(),
	running = RunService:IsRunning(),
	server = RunService:IsServer(),
	optIn = script:GetAttribute("RunWindStep") == true,
	players = #Players:GetPlayers(),
	engine = RunService:GetRobloxVersion(),
	placeVersion = game.PlaceVersion,
	gravity = workspace.Gravity,
	sourceRevision = script:GetAttribute("SourceRevision") or "UNRECORDED",
	sourceHashes = script:GetAttribute("SourceHashes") or "UNRECORDED",
}
if
	not Evidence.guard(
		environment.studio,
		environment.running,
		environment.server,
		environment.optIn,
		environment.players
	)
then
	warn("WIND_STEP_BLOCKED: exactly one real Player required")
	return
end
if script:GetAttribute("HasRun") then
	warn("WIND_STEP_BLOCKED: stop Play and restart before another run")
	return
end
script:SetAttribute("HasRun", true)
local player = Players:GetPlayers()[1]
local Driver = require(script.WindStepDriver)
local Motion = require(game:GetService("ReplicatedStorage").Shared.WindStep)
local rows: { any }, connections: { RBXScriptConnection } = {}, {}
local lease: any = nil
local fixtures = Instance.new("Folder")
fixtures.Name = "WindStepFixtures"
fixtures.Parent = workspace
local character: any, root: any, humanoid: any, saved: any = nil, nil, nil, nil
local function part(name, size, position)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Anchored = name, size, position, true
	p.Parent = fixtures
	return p
end
local function disconnect()
	local failed = false
	for _, connection in connections do
		local disconnected = pcall(function()
			connection:Disconnect()
		end)
		if not disconnected or connection.Connected then
			failed = true
		end
	end
	table.clear(connections)
	assert(not failed, "observer disconnect failed")
end
local function cleanRoot()
	return root:FindFirstChild("WindStepVelocity") == nil and root:FindFirstChild("WindStepAttachment") == nil
end
local function sameOwner(auto, owner)
	return root:GetNetworkOwnershipAuto() == auto and (auto or root:GetNetworkOwner() == owner)
end
local function waitUntil(predicate, seconds)
	local deadline = os.clock() + seconds
	repeat
		task.wait()
		if predicate() then
			return
		end
	until os.clock() >= deadline
	error("bounded wait expired")
end
local function runCase(name: string, kind: string, mode: string)
	assert(#Players:GetPlayers() == 1 and player.Character == character and humanoid.Health > 0, "player changed")
	disconnect()
	root:SetNetworkOwner(nil)
	local start = Vector3.new(0, if kind == "fall" then 100 else 8, 0)
	character:PivotTo(CFrame.new(start))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	if kind ~= "fall" then
		local settled = 0
		waitUntil(function()
			if
				humanoid.FloorMaterial ~= Enum.Material.Air
				and math.abs(root.AssemblyLinearVelocity.Y) < 0.5
				and root.Position.Y < 6
			then
				settled += 1
			else
				settled = 0
			end
			return settled >= 3
		end, 3)
	end
	-- Align setup with a completed real physics step. No fabricated scheduler callbacks.
	RunService.PostSimulation:Wait()
	if mode == "auto" then
		root:SetNetworkOwnershipAuto()
	else
		root:SetNetworkOwner(if mode == "player" then player else nil)
	end
	local auto, owner = root:GetNetworkOwnershipAuto(), root:GetNetworkOwner()
	local origin = root.Position
	local wall = if kind == "wall" then part("Wall", Vector3.new(2, 20, 30), origin + Vector3.new(7, 0, 0)) else nil
	local row: any = {
		name = name,
		kind = kind,
		committed = false,
		clean = false,
		restored = false,
		phaseOK = true,
		distance = 0,
		maxX = 0,
		elapsed = 0,
		minDt = 0,
		maxDt = 0,
		pairs = 0,
		maxYError = 0,
		commandedDistance = 0,
		lastSpeed = 0,
		simulatedSeconds = 0,
		maxSide = 0,
		samples = {},
		cancelled = false,
		velocityKept = false,
	}
	table.insert(rows, row) -- preserve failing/partial cases on every error path
	local preY, forceApplied = 0, false
	local pendingDt: number? = nil
	local function observe(callback)
		return function(...)
			local success, err = pcall(callback, ...)
			if not success then
				row.phaseOK = false
				row.observerError = tostring(err)
				if lease then
					lease.stop()
				end
			end
		end
	end
	local began = os.clock()
	lease = Driver.prepare(player, Motion.PROPOSED, Vector3.xAxis)
	assert(lease, "prepare refused: " .. name .. "; state=" .. humanoid:GetState().Name)
	assert(not lease.active(), "reservation already active")
	row.committed = lease.commit(workspace:GetServerTimeNow())
	assert(row.committed, "commit refused: " .. name)
	table.insert(
		connections,
		RunService.PreSimulation:Connect(observe(function(dt: number)
			if not lease.active() then
				return
			end
			if pendingDt then
				row.phaseOK = false
			end
			pendingDt, preY = dt, root.AssemblyLinearVelocity.Y
			row.minDt, row.maxDt = if row.minDt == 0 then dt else math.min(row.minDt, dt), math.max(row.maxDt, dt)
			local force = root:FindFirstChild("WindStepVelocity")
			if force and force.Enabled then
				row.lastSpeed = force.PlaneVelocity.X
				row.commandedDistance += row.lastSpeed * dt
			end
			forceApplied = force ~= nil and force.Enabled
			if not forceApplied or root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil then
				row.phaseOK = false
			end
		end))
	)
	table.insert(
		connections,
		RunService.PostSimulation:Connect(observe(function()
			if not pendingDt then
				return
			end
			local dt = pendingDt
			pendingDt = nil
			row.pairs += 1
			row.simulatedSeconds += dt
			local offset = root.Position - origin
			row.distance, row.maxX, row.maxSide =
				offset.X, math.max(row.maxX, offset.X), math.max(row.maxSide, math.abs(offset.Z))
			row.elapsed = os.clock() - began
			if kind == "fall" then
				row.maxYError =
					math.max(row.maxYError, math.abs(root.AssemblyLinearVelocity.Y - preY + workspace.Gravity * dt))
			end
			local force = root:FindFirstChild("WindStepVelocity")
			if force and force.Enabled then
				row.phaseOK = false
			end
			if not string.match(name, "^lifetime") and #row.samples < 128 then
				table.insert(row.samples, {
					dt = dt,
					t = row.elapsed,
					x = offset.X,
					y = offset.Y,
					vy = root.AssemblyLinearVelocity.Y,
					applied = forceApplied,
					commandSpeed = row.lastSpeed,
				})
			end
			if kind == "cancel" and row.pairs == 3 then
				local velocity = root.AssemblyLinearVelocity
				lease.stop(true)
				row.cancelled, row.velocityKept = true, root.AssemblyLinearVelocity == velocity
			end
		end))
	)
	waitUntil(function()
		return not lease.active()
	end, 1)
	disconnect()
	lease.stop()
	lease = nil
	row.clean, row.restored = cleanRoot(), sameOwner(auto, owner)
	if wall then
		wall:Destroy()
	end
	print("WIND_STEP_CASE " .. HttpService:JSONEncode(row))
	assert(Evidence.accept(row), "case failed: " .. name)
end
local ok, failure = xpcall(function()
	part("Floor", Vector3.new(160, 2, 80), Vector3.new(0, -1, 0))
	waitUntil(function()
		return player.Character ~= nil and player.Character:FindFirstChild("HumanoidRootPart") ~= nil
	end, 15)
	character = player.Character
	root = character:FindFirstChild("HumanoidRootPart")
	humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(
		humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 and root.Size == Vector3.new(2, 2, 1),
		"requires default R15 root (2,2,1)"
	)
	assert(root:CanSetNetworkOwnership(), "root ownership unavailable")
	saved = {
		pivot = character:GetPivot(),
		velocity = root.AssemblyLinearVelocity,
		angular = root.AssemblyAngularVelocity,
		walk = humanoid.WalkSpeed,
		jump = humanoid.JumpPower,
		height = humanoid.JumpHeight,
		rotate = humanoid.AutoRotate,
		auto = root:GetNetworkOwnershipAuto(),
		owner = root:GetNetworkOwner(),
	}
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0, 0, 0, false
	for _, mode in { "auto", "player", "server" } do
		runCase("travel-" .. mode, "travel", mode)
	end
	runCase("wall", "wall", "server")
	runCase("fall", "fall", "server")
	runCase("cancel", "cancel", "server")
	for i = 1, 100 do
		runCase("lifetime-" .. i, "travel", if i % 2 == 0 then "auto" else "player")
	end
end, debug.traceback)
-- Independent releases; failure in one must not skip another.
local cleanup = true
local function release(fn)
	local success, err = pcall(fn)
	if not success then
		cleanup = false
		warn(tostring(err))
	end
end
release(function()
	if lease then
		lease.stop()
	end
end)
release(disconnect)
release(function()
	fixtures:Destroy()
end)
release(function()
	if saved and player.Character == character and root:IsDescendantOf(workspace) then
		root:SetNetworkOwner(nil)
		character:PivotTo(saved.pivot)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = saved.velocity, saved.angular
	end
end)
release(function()
	if saved then
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate =
			saved.walk, saved.jump, saved.height, saved.rotate
	end
end)
release(function()
	if saved and root:IsDescendantOf(workspace) then
		if saved.auto then
			root:SetNetworkOwnershipAuto()
		else
			root:SetNetworkOwner(saved.owner)
		end
		assert(sameOwner(saved.auto, saved.owner) and cleanRoot(), "root cleanup/ownership mismatch")
	end
	assert(fixtures.Parent == nil and #connections == 0, "fixture/listener leak")
end)
local report = Evidence.finish(environment, rows, cleanup)
report.matrixPassed = report.matrixPassed and ok
report.runCompleted = ok
report.error = if ok then nil else tostring(failure)
local result = Instance.new("StringValue")
result.Name = "WindStepEvidence"
result.Value = HttpService:JSONEncode(report)
result.Parent = game:GetService("ServerStorage")
print("WIND_STEP_SUMMARY " .. HttpService:JSONEncode({
	matrixPassed = report.matrixPassed,
	passed = report.passed,
	expected = report.expected,
	cleanup = report.cleanup,
	error = report.error,
	dynamicsAccepted = false,
}))
