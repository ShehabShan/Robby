--!strict
-- Client movement (T-058b, D-429; was T-026b3a sprint): press LeftShift / gamepad L3 / touch button once to toggle run (T-060a, D-469).
-- Q / gamepad B slides while running (T-058e). LeftControl is shift lock, B (keyboard) is Crucible. Each frame runs the pure `Shared.Movement` step (momentum,
-- jog → sprint ramp, stamina, sharp-reversal brake) and writes the result to the local Humanoid.WalkSpeed.
-- Stamina is mirrored to the character attribute `Stamina` (0..staminaMax) for a later HUD bar.
-- Sprint FOV: tweens the camera FOV on sprint start/stop only, so CrescentFx FOV kicks still work.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Movement = require(ReplicatedStorage.Shared.Movement)
local Dash = require(ReplicatedStorage.Shared.Dash)

local tune: Movement.Tuning = Config.Movement
local dashTune: Dash.Tuning = Config.Dash
local dashState = Dash.new()
local dashDir = Vector3.zero
local cam = Config.MovementCamera
local SprintClient = {}
local held = false
local slidePressed = false -- Q / gamepad B (T-058e, D-431)
local state: Movement.State = Movement.new(tune)
local sprintingFov = false
local lastCharacter: Model? = nil
local wasAir, fallSpeed = false, 0

local function setFov(sprinting: boolean)
	if sprinting == sprintingFov then
		return
	end
	sprintingFov = sprinting
	local camera = workspace.CurrentCamera
	if camera then
		local goal = if sprinting then cam.fovSprint else cam.fovBase
		TweenService:Create(camera, TweenInfo.new(cam.fovTween), { FieldOfView = goal }):Play()
	end
end

-- Degrees between the wanted move direction and the current planar velocity (0 when either is ~zero).
local function turnAngle(move: Vector3, vel: Vector3): number
	local planar = Vector3.new(vel.X, 0, vel.Z)
	if move.Magnitude < 0.1 or planar.Magnitude < 1 then
		return 0
	end
	local d = math.clamp(move.Unit:Dot(planar.Unit), -1, 1)
	return math.deg(math.acos(d))
end

-- Air Q hook (T-059d2): MoveClient sets this; gets current stamina.
SprintClient.airQ = nil :: ((stamina: number) -> ())?

-- Spend stamina for a move another client module executed (air dash, T-059d2).
function SprintClient.spend(cost: number)
	state.stamina = math.max(0, state.stamina - cost)
	state.regenWait = tune.regenDelay
end

-- `onDash(dir)` tells the server about an accepted basic dash (T-058d2, D-437).
function SprintClient.start(onDash: ((dir: Vector3) -> ())?)
	ContextActionService:BindAction("Sprint", function(_, inputState: Enum.UserInputState, _)
		held = Movement.toggleRun(held, inputState == Enum.UserInputState.Begin) -- toggle, not hold (T-060a, D-469)
		local player = Players.LocalPlayer
		player:SetAttribute("RunToggled", held)
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Sprint", "Run") -- touch toggle button label (T-060a)
	ContextActionService:BindAction("Slide", function(_, inputState: Enum.UserInputState, _)
		if inputState == Enum.UserInputState.Begin then
			slidePressed = true
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	RunService.Heartbeat:Connect(function(dt: number)
		local character = Players.LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
			setFov(false)
			return
		end
		if character ~= lastCharacter then
			lastCharacter = character
			state = Movement.new(tune) -- respawn: full stamina, standing start
			wasAir, fallSpeed = false, 0
			dashState = Dash.new()
		end
		local move = hum.MoveDirection
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local landedFall: number? = nil -- landing recovery (T-058g, D-430)
		if not grounded then
			fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
		elseif wasAir then
			landedFall = fallSpeed
			fallSpeed = 0
		end
		wasAir = not grounded
		-- Q: slide when sprinting forward fast, otherwise a directional dash (T-058d2, D-437).
		local stunned = character:GetAttribute("Staggered") == true
		-- Q in the air is an air dash (T-059d2, D-473): handed to MoveClient, never a ground dash.
		if slidePressed and not grounded then
			slidePressed = false
			if SprintClient.airQ then
				SprintClient.airQ(state.stamina)
			end
		end
		if slidePressed then
			local look = root.CFrame.LookVector
			local kind: Dash.Kind = Dash.classify(dashTune, look.X, look.Z, move.X, move.Z)
			if Dash.qAction(dashTune, held, state.speed, kind) == "dash" then
				slidePressed = false
				local started, cost =
					Dash.start(dashTune, dashState, kind, { stamina = state.stamina, stunned = stunned })
				if cost > 0 then
					dashState = started
					state.stamina -= cost
					state.regenWait = tune.regenDelay
					local flatLook = Vector3.new(look.X, 0, look.Z)
					dashDir = if move.Magnitude > 0.1 then Vector3.new(move.X, 0, move.Z).Unit else -flatLook.Unit
					if onDash then
						onDash(dashDir)
					end
				end
			end
		end
		local input: Movement.Input = {
			sprint = held,
			walk = false,
			moving = move.Magnitude > 0.1,
			grounded = grounded,
			turnAngle = turnAngle(move, root.AssemblyLinearVelocity),
			landedFall = landedFall,
			slide = slidePressed,
		}
		local sprinting = Movement.canSprint(tune, state, input)
		state = Movement.step(tune, state, input, dt)
		slidePressed = false
		dashState = Dash.step(dashTune, dashState, dt, stunned)
		if dashState.kind then
			local v = Dash.speedAt(dashTune, dashState.kind, dashState.elapsed)
			root.AssemblyLinearVelocity = dashDir * v + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		character:SetAttribute("Dashing", dashState.kind) -- for T-058c dash animations
		character:SetAttribute("Sprinting", sprinting or nil) -- for MoveFxClient speed streaks (T-058i)
		character:SetAttribute("Sliding", (state.slide or 0) > 0 or nil) -- for T-058c slide animation
		local speed = state.speed
		local boostEnd = character:GetAttribute("SpeedBoostEnd")
		local boostMult = character:GetAttribute("SpeedBoostMult")
		if type(boostEnd) == "number" and type(boostMult) == "number" and workspace:GetServerTimeNow() < boostEnd then
			speed *= math.clamp(boostMult, 1, 2) -- Full Moon Ring shatter boost (T-057c2, D-416)
		end
		hum.WalkSpeed = speed
		character:SetAttribute("Stamina", math.floor(state.stamina + 0.5))
		setFov(sprinting)
	end)
end

return SprintClient
