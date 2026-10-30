--!strict
-- Training ground (.ai/SPIKE.md §4): ground, a spawn, and a 200 HP training dummy built from parts in code.
-- The dummy respawns 5 s after it reaches 0 HP and shows its HP above its head.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Dummy = {}

local MAX_HP = 200
local RESPAWN = 5
local POSITION = Vector3.new(0, 3, -25)
local WOOD = Color3.fromRGB(196, 170, 120)

local function ensureGround()
	if not workspace:FindFirstChild("Baseplate") then
		local base = Instance.new("Part")
		base.Name = "Baseplate"
		base.Size = Vector3.new(512, 1, 512)
		base.Position = Vector3.new(0, -0.5, 0)
		base.Anchored = true
		base.Material = Enum.Material.Slate
		base.Color = Color3.fromRGB(70, 74, 82)
		base.Parent = workspace
	end
	if not workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Parent = workspace
	end
end

local function part(model: Model, name: string, size: Vector3, offset: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = WOOD
	p.Material = Enum.Material.Wood
	p.Anchored = true
	p.CFrame = CFrame.lookAt(POSITION + offset, POSITION + offset + Vector3.new(0, 0, 1))
	p.Parent = model
	return p
end

local function build(): (Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero)
	root.Transparency = 1
	root.CanCollide = false
	model.PrimaryPart = root
	part(model, "UpperTorso", Vector3.new(2, 2, 1), Vector3.zero)
	local head = part(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0))
	part(model, "LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0))
	part(model, "RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0))
	part(model, "LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0))
	part(model, "RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = MAX_HP
	humanoid.Health = MAX_HP
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 28)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	local function refresh()
		label.Text = string.format("%d / %d", math.max(0, math.ceil(humanoid.Health)), MAX_HP)
	end
	humanoid.HealthChanged:Connect(refresh)
	refresh()
	return model, humanoid
end

local function spawnDummy()
	local model, humanoid = build()
	model:SetAttribute("WildKith", Config.Binding.dummyKith) -- bindable when weakened (T-017b)
	model:SetAttribute("Will", Config.Binding.wildWill)
	model.Parent = workspace
	humanoid.Died:Connect(function()
		task.delay(RESPAWN, function()
			model:Destroy()
			spawnDummy()
		end)
	end)
end

function Dummy.start()
	ensureGround()
	spawnDummy()
end

return Dummy
