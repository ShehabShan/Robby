--!strict
-- Movement VFX (T-058i, D-440): footstep dust, sprint speed streaks, dash dust ring / wind arcs / smoke puff.
-- Reference: owner movement video (research/notes/R-031-movement-video.md). Local character only.
-- Code-built, no uploaded assets. Cosmetic only: nothing here changes movement or hits.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Footsteps = require(ReplicatedStorage.Shared.Footsteps)
local MoveFxPlan = require(ReplicatedStorage.Shared.MoveFxPlan)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)

local T: MoveFxPlan.Tuning = Config.MoveFx
local MR: MoveRules.Tuning = Config.MoveRules
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local DUST = Color3.fromRGB(205, 198, 186)
local WHITE = Color3.fromRGB(255, 255, 255)

local MoveFxClient = {}

local function puff(at: Vector3, count: number, size: number, speed: number, life: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(DUST)
	e.Rate = 0
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(80, 80)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new(size, size * 2)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, life + 0.5)
end

-- Flat ring that grows and fades (dash start dust ring).
local function ring(at: Vector3, radius: number, life: number)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.SmoothPlastic
	p.Color = DUST
	p.Transparency = 0.4
	p.Size = Vector3.new(0.1, 1, 1)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, life + 0.1)
end

-- White crescent wind arcs around the body (side dodge), built from short-lived trails.
local function arcs(root: BasePart)
	for i = 1, 2 do
		local holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.Parent = Workspace
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.15, 0)
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.15, 0)
		a1.Parent = holder
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(WHITE)
		trail.LightEmission = 0.6
		trail.Lifetime = 0.18
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.FaceCamera = true
		trail.Parent = holder
		local start = os.clock()
		local tilt = if i == 1 then 0.35 else -0.35
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - start) / 0.25
			if k >= 1 or root.Parent == nil then
				if conn then
					conn:Disconnect()
				end
				holder:Destroy()
				return
			end
			local ang = (i - 1) * math.pi + k * math.pi * 1.6
			holder.CFrame = root.CFrame
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(math.cos(ang) * 2.6, (k - 0.5) * 1.5, math.sin(ang) * 2.6)
		end)
	end
end

-- Thin white streak passing the camera (sprint speed line).
local function streak(root: BasePart)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local side = if math.random() < 0.5 then -1 else 1
	local origin = root.Position
		+ cam.CFrame.RightVector * side * (3 + math.random() * 3)
		+ Vector3.new(0, 1 + math.random() * 3, 0)
	local back = -Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = WHITE
	p.Transparency = 0.5
	p.Size = Vector3.new(0.06, 0.06, 6)
	p.CFrame = CFrame.lookAt(origin, origin + back)
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
		CFrame = p.CFrame * CFrame.new(0, 0, -10),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.35)
end

local function feet(root: BasePart, hum: Humanoid): Vector3
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hum.HipHeight - 0.2, 0)
end

-- Vertical streak around the body while falling in a slam (T-059e, plan §5).
local function slamStreak(root: BasePart)
	local angle = math.random() * math.pi * 2
	local r = 1.6 + math.random() * 1.4
	local origin = root.Position + Vector3.new(math.cos(angle) * r, -1, math.sin(angle) * r)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = if math.random() < 0.7 then WHITE else Color3.fromRGB(28, 28, 32)
	p.Transparency = 0.35
	p.Size = Vector3.new(0.06, 4.5, 0.06)
	p.CFrame = CFrame.new(origin)
	p.Parent = Workspace
	TweenService:Create(p, TweenInfo.new(0.14, Enum.EasingStyle.Linear), {
		CFrame = p.CFrame * CFrame.new(0, 5, 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.2)
end

-- Short, low-amplitude camera shake on slam ground contact only (T-059e, plan §3/§5).
local function slamShake(humanoid: Humanoid)
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = MoveRules.slamShakeAmplitude(MR, os.clock() - start)
		if k <= 0 then
			humanoid.CameraOffset = Vector3.zero
			if conn then
				conn:Disconnect()
			end
			return
		end
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

local lastAir = false
local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	local hum: Humanoid = humanoid
	local rootPart: BasePart = root
	local stepAcc, streakAcc, slamAcc = 0, 0, 0
	local nextStreak = MoveFxPlan.streakDelay(T, math.random())
	local lastDash: string? = nil
	local lastSlamContact = (character:GetAttribute("SlamContact") :: number?) or 0

	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if hum.Health <= 0 or character.Parent == nil then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local v = rootPart.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local floor = hum.FloorMaterial.Name

		-- Footstep dust, same cadence as the step sounds (Shared.Footsteps).
		local step = Footsteps.interval(speed)
		if step and MoveFxPlan.dustOnStep(T, speed, floor) then
			stepAcc += dt
			if stepAcc >= step then
				stepAcc = 0
				puff(feet(rootPart, hum) - v.Unit * 0.8, 4, 0.6, 2, 0.3)
			end
		else
			stepAcc = 0
		end

		-- Rare speed streaks while sprinting.
		if MoveFxPlan.streaksOn(T, speed, character:GetAttribute("Sprinting") == true) then
			streakAcc += dt
			if streakAcc >= nextStreak then
				streakAcc = 0
				nextStreak = MoveFxPlan.streakDelay(T, math.random())
				streak(rootPart)
			end
		else
			streakAcc = 0
		end

		-- Dash: dust ring + (side) wind arcs at start, smoke puff at the end.
		local dashing = character:GetAttribute("Dashing")
		local now: string? = if typeof(dashing) == "string" then dashing else nil
		for _, ev in MoveFxPlan.dashEvents(lastDash, now) do
			if ev == "start" then
				ring(feet(rootPart, hum), 4, 0.3)
				puff(feet(rootPart, hum), 10, 1, 5, 0.4)
			elseif ev == "arcs" then
				arcs(rootPart)
			elseif ev == "finish" then
				puff(feet(rootPart, hum), 8, 1.2, 3, 0.5)
			end
		end
		lastDash = now
		-- Air dash (T-059d2): streak pair + small burst at the start.
		local airDashing = character:GetAttribute("AirDashing") == true
		if airDashing and not lastAir then
			streak(rootPart)
			streak(rootPart)
			puff(rootPart.Position, 8, 0.9, 6, 0.3)
		end
		lastAir = airDashing
		-- Slam (T-059e): downward streaks while falling; ring + dust + camera shake on ground contact only.
		if character:GetAttribute("SlamFalling") == true then
			slamAcc += dt
			if slamAcc >= 0.04 then
				slamAcc = 0
				slamStreak(rootPart)
			end
		else
			slamAcc = 0
		end
		local slamContact = (character:GetAttribute("SlamContact") :: number?) or 0
		if slamContact ~= lastSlamContact then
			lastSlamContact = slamContact
			local at = feet(rootPart, hum)
			ring(at, 6, 0.32)
			puff(at, 12, 1.1, 6, 0.45)
			slamShake(hum)
		end
	end)
end

function MoveFxClient.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(attach, character)
	end)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end

return MoveFxClient
