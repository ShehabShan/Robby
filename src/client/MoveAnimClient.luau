--!strict
-- Movement animations (T-026c, D-210): points the default `Animate` script's idle/walk/run/jump at the
-- movement kit's animations and plays the kit's land track after a real fall. Local player only;
-- the Animator replicates tracks to other players. Combat, stagger and Binding use their own tracks/tweens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MoveAnims = require(ReplicatedStorage.Shared.MoveAnims)

local MoveAnimClient = {}

local function setIds(animate: Instance)
	for _, slot in MoveAnims.slots do
		local folder = animate:FindFirstChild(slot)
		local id = MoveAnims.ids[slot]
		if folder and id then
			for _, child in folder:GetChildren() do
				if child:IsA("Animation") then
					child.AnimationId = MoveAnims.assetUrl(id)
				end
			end
		end
	end
end

local function apply(character: Model)
	local animate = character:WaitForChild("Animate", 10)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if animate == nil or humanoid == nil or root == nil then
		return
	end
	setIds(animate)
	local hum: Humanoid = humanoid
	local rootPart: BasePart = root
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = MoveAnims.assetUrl(MoveAnims.ids.land)
	local land = animator:LoadAnimation(anim)
	local fall = 0
	local beat = RunService.Heartbeat:Connect(function()
		if hum:GetState() == Enum.HumanoidStateType.Freefall then
			fall = math.max(fall, -rootPart.AssemblyLinearVelocity.Y)
		end
	end)
	local changed = hum.StateChanged:Connect(function(_, state: Enum.HumanoidStateType)
		if state == Enum.HumanoidStateType.Landed then
			if MoveAnims.shouldLand(fall) then
				land:Play(0.05)
			end
			fall = 0
		end
	end)
	character.Destroying:Connect(function()
		beat:Disconnect()
		changed:Disconnect()
	end)
end

function MoveAnimClient.start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(apply, character)
	end)
	if player.Character then
		task.spawn(apply, player.Character)
	end
end

return MoveAnimClient
