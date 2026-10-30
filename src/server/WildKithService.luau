--!strict
-- Spawns the wild Kith from Shared.WildSpawns (T-025b1, D-158): a small anchored Model per spot with a Humanoid
-- and the `WildKith` attribute, so BindingService can bind it once weakened. Respawns after `respawn` seconds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MistvaleHub = require(ReplicatedStorage.Shared.MistvaleHub)
local MistvaleLayout = require(ReplicatedStorage.Shared.MistvaleLayout)
local WildSpawns = require(ReplicatedStorage.Shared.WildSpawns)

local WildKithService = {}

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: string, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(MistvaleHub.PALETTE[color])
	p.Material = if color == "glow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function spawnAt(s: WildSpawns.Spawn, folder: Folder)
	local model = Instance.new("Model")
	model.Name = "WildKith"
	local base = CFrame.new(s.x, s.y, s.z)
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 2), base * CFrame.new(0, 1.5, 0), "moss")
	root.Transparency = 1
	model.PrimaryPart = root
	part(model, "Pad", Vector3.new(3.4, 0.3, 3.4), base * CFrame.new(0, 0.15, 0), "pine")
	for i = 0, 4 do
		local a = i * 2 * math.pi / 5
		part(
			model,
			"Petal",
			Vector3.new(0.9, 0.9, 0.9),
			base * CFrame.new(0.8 * math.cos(a), 0.8, 0.8 * math.sin(a)),
			"plaster",
			Enum.PartType.Ball
		)
	end
	part(model, "Head", Vector3.new(0.8, 0.8, 0.8), base * CFrame.new(0, 1.2, 0), "glow", Enum.PartType.Ball)
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth, humanoid.Health = s.hp, s.hp
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model:SetAttribute("WildKith", s.kith)
	model.Parent = folder
	CollectionService:AddTag(model, "WildKith") -- melee targets (CombatService)
	humanoid.Died:Connect(function()
		task.delay(s.respawn, function()
			model:Destroy()
			spawnAt(s, folder)
		end)
	end)
end

function WildKithService.start()
	local folder = Instance.new("Folder")
	folder.Name = "WildKith"
	folder.Parent = workspace
	for _, s in WildSpawns.spots(MistvaleLayout.DEFAULT) do
		spawnAt(s, folder)
	end
end

return WildKithService
