--!strict
-- Client movement feel (T-026b1, D-161): body lean into movement, camera bob while walking and a
-- small camera dip on hard landings. Applies the pure `Shared.MoveFeel` numbers each frame.
-- Cosmetic only: lean edits the local LowerTorso.Root C0, bob/dip use Humanoid.CameraOffset.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Feel = require(ReplicatedStorage.Shared.MoveFeel)

local P = Feel.DEFAULTS
local MoveFeelClient = {}

local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local lower = character:WaitForChild("LowerTorso", 10)
	if not humanoid or not root or not lower then
		return
	end
	local joint = lower:WaitForChild("Root", 5) :: Motor6D?
	if not joint then
		return
	end
	local hum: Humanoid = humanoid
	local rootPart: BasePart = root
	local motor: Motor6D = joint
	local baseC0 = motor.C0
	local pitch, roll, phase, dip, fallSpeed = 0, 0, 0, 0, 0
	local wasAir = false

	-- Bound just before the camera update; HitFeel's shake (RenderStepped) overrides CameraOffset while it runs.
	local bindName = "RobbyMoveFeel"
	RunService:UnbindFromRenderStep(bindName)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value - 1, function(dt: number)
		if hum.Health <= 0 or character.Parent == nil then
			RunService:UnbindFromRenderStep(bindName)
			return
		end
		local v = rootPart.AssemblyLinearVelocity
		local planar = Vector3.new(v.X, 0, v.Z)
		local speed = planar.Magnitude
		local inAir = hum.FloorMaterial == Enum.Material.Air

		local localV = rootPart.CFrame:VectorToObjectSpace(planar)
		local tp, tr = Feel.leanTarget(localV.X, localV.Z)
		if inAir then
			tp, tr = 0, 0
		end
		pitch = Feel.approach(pitch, tp, P.leanRate, dt)
		roll = Feel.approach(roll, tr, P.leanRate, dt)
		motor.C0 = baseC0 * CFrame.Angles(pitch, 0, roll)

		if inAir then
			fallSpeed = math.max(fallSpeed, -v.Y)
		elseif wasAir then
			dip = math.max(dip, Feel.landDip(fallSpeed))
			fallSpeed = 0
		end
		wasAir = inAir
		dip = Feel.approach(dip, 0, P.dipRecover, dt)

		local bx, by = 0, 0
		if not inAir then
			phase = Feel.bobPhase(phase, speed, dt)
			bx, by = Feel.bob(phase, speed)
		end
		hum.CameraOffset = Vector3.new(bx, by - dip, 0)
	end)
end

function MoveFeelClient.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(attach, character)
	end)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end

return MoveFeelClient
