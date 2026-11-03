--!strict
-- Client movement (T-058b, D-429; was T-026b3a sprint): hold LeftShift / gamepad L3 to sprint (D-164).
-- LeftControl is shift lock, B is Crucible. Each frame runs the pure `Shared.Movement` step (momentum,
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

local tune: Movement.Tuning = Config.Movement
local cam = Config.MovementCamera
local SprintClient = {}
local held = false
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

function SprintClient.start()
	ContextActionService:BindAction("Sprint", function(_, inputState: Enum.UserInputState, _)
		held = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

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
		local input: Movement.Input = {
			sprint = held,
			walk = false,
			moving = move.Magnitude > 0.1,
			grounded = grounded,
			turnAngle = turnAngle(move, root.AssemblyLinearVelocity),
			landedFall = landedFall,
		}
		local sprinting = Movement.canSprint(tune, state, input)
		state = Movement.step(tune, state, input, dt)
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
