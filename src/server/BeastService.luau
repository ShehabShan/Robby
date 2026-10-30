--!strict
-- Wild beasts (T-022b, D-125): thin server wiring for the pure `Shared.BeastBrain`. Spawns the
-- `Config.Beasts.spawns` pack around Workspace.MistvaleAnchors.zone1 (falls back near the origin), ticks
-- every brain at 10 Hz with server-owned physics, shows the wind-up (body turns red + `Telegraph` attribute;
-- facing locks when the wind-up starts so a dodge works), resolves strikes through `CombatService.incoming`
-- (i-frames, parry → beast stagger, guard), pays `shards` to the last player who hit it, and respawns.
-- Beasts are tagged `Beast` (CombatService targets them) and carry `WildKith`/`Will` (bindable, T-017).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BeastBrain = require(ReplicatedStorage.Shared.BeastBrain)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)

local B = Config.Beasts
local TICK = 0.1
local TELEGRAPH_COLOR = Color3.fromRGB(255, 80, 60)

local LOOKS: { [string]: { size: Vector3, color: Color3, material: Enum.Material } } = {
	["beast.mistfang"] = {
		size = Vector3.new(2.5, 2.5, 5),
		color = Color3.fromRGB(150, 160, 175),
		material = Enum.Material.SmoothPlastic,
	},
	["beast.stonehide"] = {
		size = Vector3.new(4, 3.5, 6),
		color = Color3.fromRGB(120, 105, 90),
		material = Enum.Material.Slate,
	},
}

type Beast = {
	model: Model,
	root: BasePart,
	body: BasePart,
	humanoid: Humanoid,
	kindId: string,
	kind: any,
	brain: BeastBrain.Brain,
	home: Vector3,
	color: Color3,
	faced: boolean,
	gone: boolean,
}

local beasts: { Beast } = {}

local BeastService = {}

local function zoneCentre(): Vector3
	local anchors = workspace:FindFirstChild("MistvaleAnchors")
	local zone = anchors and anchors:FindFirstChild("zone1")
	if zone and zone:IsA("BasePart") then
		return zone.Position
	end
	return Vector3.new(0, 1, -70)
end

local spawnBeast: (kindId: string, home: Vector3) -> ()

local function drop(b: Beast)
	if b.gone then
		return
	end
	b.gone = true
	local i = table.find(beasts, b)
	if i then
		table.remove(beasts, i)
	end
	task.delay(B.respawn, function()
		spawnBeast(b.kindId, b.home)
	end)
end

local function payKill(b: Beast)
	local userId = b.model:GetAttribute("LastHitBy")
	local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local data = if player then DataService.get(player) else nil
	if data and type(data.wallet) == "table" then
		data.wallet.shards = (data.wallet.shards or 0) + b.kind.shards
	end
end

spawnBeast = function(kindId: string, home: Vector3)
	local k = B.kinds[kindId]
	local look = LOOKS[kindId]
	local model = Instance.new("Model")
	model.Name = k.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(home + Vector3.new(0, look.size.Y / 2 + 2, 0))
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = look.size
	body.Color = look.color
	body.Material = look.material
	body.CanCollide = false
	body.Massless = true
	body.CFrame = root.CFrame
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, body
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = look.size.Y / 2 - 1
	humanoid.MaxHealth = k.hp
	humanoid.Health = k.hp
	humanoid.WalkSpeed = k.speed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("BeastKind", kindId)
	model:SetAttribute("Rank", k.rank)
	model:SetAttribute("Will", Config.Binding.wildWill)
	if k.wildKith then
		model:SetAttribute("WildKith", k.wildKith)
	end
	CollectionService:AddTag(model, "Beast")
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- server-owned AI
	end)
	local b: Beast = {
		model = model,
		root = root,
		body = body,
		humanoid = humanoid,
		kindId = kindId,
		kind = k,
		brain = BeastBrain.new(kindId, os.clock()),
		home = home,
		color = look.color,
		faced = false,
		gone = false,
	}
	table.insert(beasts, b)
	humanoid.Died:Connect(function()
		payKill(b)
		drop(b)
		task.delay(2, function()
			model:Destroy()
		end)
	end)
end

local function nearest(pos: Vector3): (BasePart?, number?)
	local best, bestDist = nil, nil
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local d = (r.Position - pos).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = r, d
			end
		end
	end
	return best, bestDist
end

local function strike(b: Beast, now: number)
	local look = b.root.CFrame.LookVector
	local fwd = Vector3.new(look.X, 0, look.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else Vector3.zAxis
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local offset = r.Position - b.root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dot = if flat.Magnitude > 0.5 then flat.Unit:Dot(fwd) else 1
			if BeastBrain.hits(b.kind, offset.Magnitude, dot) then
				local result = CombatService.incoming(p, b.kind.damage, now)
				if result == "hit" then
					h:TakeDamage(b.kind.damage)
				elseif result == "parried" then
					BeastBrain.stagger(b.brain, now, Config.Combat.parry.stagger)
				end
			end
		end
	end
end

local function tick(b: Beast, now: number)
	if b.model.Parent == nil then
		drop(b) -- bound or removed
		return
	end
	if b.humanoid.Health <= 0 then
		return
	end
	local target, dist = nearest(b.root.Position)
	local here = b.root.Position
	local homeDist = Vector3.new(here.X - b.home.X, 0, here.Z - b.home.Z).Magnitude
	local out = BeastBrain.step(b.brain, b.kind, { now = now, targetDist = dist, homeDist = homeDist })
	if out.move == "target" and target then
		b.humanoid:MoveTo(target.Position)
	elseif out.move == "home" then
		b.humanoid:MoveTo(b.home)
	else
		b.humanoid:MoveTo(here)
	end
	if out.telegraph and not b.faced and target then
		b.faced = true
		local t = target.Position
		b.root.CFrame = CFrame.lookAt(here, Vector3.new(t.X, here.Y, t.Z))
	elseif not out.telegraph and not out.strike then
		b.faced = false
	end
	b.body.Color = if out.telegraph and not out.strike then TELEGRAPH_COLOR else b.color
	b.model:SetAttribute("Telegraph", out.telegraph and not out.strike)
	if out.strike then
		strike(b, now)
	end
	if out.heal then
		b.humanoid.Health = b.humanoid.MaxHealth
		b.model:SetAttribute("LastHitBy", nil)
	end
end

function BeastService.start()
	local centre = zoneCentre()
	local n = 0
	for _, s in B.spawns do
		for _ = 1, s.count do
			n += 1
			local a = n * 2.4
			spawnBeast(s.kind, centre + Vector3.new(math.cos(a), 0, math.sin(a)) * B.spread)
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local now = os.clock()
		for _, b in table.clone(beasts) do
			tick(b, now)
		end
	end)
end

return BeastService
