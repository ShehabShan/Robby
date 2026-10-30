--!strict
-- Client footsteps (T-026b2, D-162): plays a surface-matched step sound at the local character's feet,
-- timed by speed, using pure `Shared.Footsteps`. Mutes Roblox's default "Running" loop so steps don't double.
-- Cosmetic only. Other players keep the default running sound (local footsteps only, for now).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Footsteps = require(ReplicatedStorage.Shared.Footsteps)

local VOLUME = 0.45
local FootstepClient = {}

local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	local hum: Humanoid = humanoid
	local rootPart: BasePart = root
	task.delay(1, function()
		local running = rootPart:FindFirstChild("Running")
		if running and running:IsA("Sound") then
			running.Volume = 0
		end
	end)
	local sound = Instance.new("Sound")
	sound.Name = "RobbyFootstep"
	sound.RollOffMaxDistance = 40
	sound.Parent = rootPart
	local acc, last = 0, nil :: number?

	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if hum.Health <= 0 or character.Parent == nil then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local v = rootPart.AssemblyLinearVelocity
		local surface = Footsteps.surfaceFor(hum.FloorMaterial.Name)
		local step = Footsteps.interval(Vector3.new(v.X, 0, v.Z).Magnitude)
		if not surface or not step then
			acc = 0
			return
		end
		acc += dt
		if acc < step then
			return
		end
		acc = 0
		local id, i = Footsteps.pick(surface, last, math.random())
		last = i
		if id then
			sound.SoundId = id
			sound.Volume = VOLUME
			sound.PlaybackSpeed = 0.92 + math.random() * 0.16
			sound:Play()
		end
	end)
end

function FootstepClient.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(attach, character)
	end)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end

return FootstepClient
