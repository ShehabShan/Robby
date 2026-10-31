--!strict
-- Boss server (T-023b, D-138): spawns each `Config.Bosses` boss at Workspace.MistvaleAnchors.arena (falls back
-- to a spot inside zone 1 until T-021c places an arena), ticks pure `Shared.BossBrain` at 10 Hz with
-- server-owned physics, and resolves strikes through `CombatService.incoming` (parry staggers the boss).
-- The boss is tagged `Beast` (CombatService targets it, BeastHud labels it, BeastFx draws its telegraph) and
-- `Boss`. It has no `WildKith`, so it cannot be bound. Per-attack telegraph shape goes in attributes
-- `TelegraphRange` / `TelegraphArc` / `TelegraphSeconds` before `Telegraph` turns on; `Phase` = 1 or 2.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BossBrain = require(ReplicatedStorage.Shared.BossBrain)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Status = require(ReplicatedStorage.Shared.Status)
local statuses = require(script.Parent.StatusStore)
local STAGGER_TAG = "State.Staggered" -- Shatter on a Rimed boss (D-188); read each tick (T-031, D-196)
local RankTest = require(ReplicatedStorage.Shared.RankTest)

local C = Config.Bosses
local TICK = 0.1
local TELEGRAPH_COLOR = Color3.fromRGB(255, 80, 60)
local ARENA_FALLBACK = Vector3.new(0, 0, -90) -- offset from zone 1 centre until an arena anchor exists

local LOOKS: { [string]: { size: Vector3, color: Color3, material: Enum.Material } } = {
	["boss.mistmaw"] = {
		size = Vector3.new(6, 5, 11),
		color = Color3.fromRGB(120, 130, 150),
		material = Enum.Material.Slate,
	},
}

type Boss = {
	model: Model,
	root: BasePart,
	body: BasePart,
	humanoid: Humanoid,
	kindId: string,
	kind: any,
	brain: BossBrain.Brain,
	home: Vector3,
	color: Color3,
	faced: boolean,
	gone: boolean,
}

local bosses: { Boss } = {}

local BossService = {}

local function arenaCentre(): Vector3
	local anchors = workspace:FindFirstChild("MistvaleAnchors")
	local arena = anchors and anchors:FindFirstChild("arena")
	if arena and arena:IsA("BasePart") then
		return arena.Position
	end
	local zone = anchors and anchors:FindFirstChild("zone1")
	if zone and zone:IsA("BasePart") then
		return zone.Position + ARENA_FALLBACK
	end
	return Vector3.new(0, 1, -160)
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

local function payKill(b: Boss)
	local userId = b.model:GetAttribute("LastHitBy")
	local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local data = if player then DataService.get(player) else nil
	if data and type(data.wallet) == "table" then
		data.wallet.shards = (data.wallet.shards or 0) + b.kind.shards
	end
	if player and data and RankTest.credit(data, b.kind, os.time()) then
		player:SetAttribute("RankTestPassed", b.kind.rankTest)
		print(`[Boss] {player.Name} passed the {b.kind.rankTest} Rank test`)
	end
end

local function strike(b: Boss, attackId: string, now: number)
	local a = b.kind.attacks[attackId]
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
			if BossBrain.hits(a, offset.Magnitude, dot) then
				local result = CombatService.incoming(p, a.damage, now)
				if result == "hit" then
					h:TakeDamage(a.damage)
				elseif result == "parried" then
					BossBrain.stagger(b.brain, now, Config.Combat.parry.stagger)
				end
			end
		end
	end
end

local spawnBoss: (kindId: string, home: Vector3) -> ()

spawnBoss = function(kindId: string, home: Vector3)
	local k = C.kinds[kindId]
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
	model:SetAttribute("BossKind", kindId)
	model:SetAttribute("Rank", k.rank)
	model:SetAttribute("Phase", 1)
	model:SetAttribute("TelegraphWeight", k.hp)
	CollectionService:AddTag(model, "Beast")
	CollectionService:AddTag(model, "Boss")
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- server-owned AI
	end)
	local b: Boss = {
		model = model,
		root = root,
		body = body,
		humanoid = humanoid,
		kindId = kindId,
		kind = k,
		brain = BossBrain.new(kindId, os.clock()),
		home = home,
		color = look.color,
		faced = false,
		gone = false,
	}
	table.insert(bosses, b)
	humanoid.Died:Connect(function()
		payKill(b)
		b.gone = true
		local i = table.find(bosses, b)
		if i then
			table.remove(bosses, i)
		end
		task.delay(Config.Beasts.corpseSeconds, function()
			model:Destroy()
		end)
		task.delay(k.respawn or 90, function()
			spawnBoss(kindId, home)
		end)
	end)
end

local function tick(b: Boss, now: number)
	if b.gone or b.model.Parent == nil or b.humanoid.Health <= 0 then
		return
	end
	local target, dist = nearest(b.root.Position)
	local here = b.root.Position
	local homeDist = Vector3.new(here.X - b.home.X, 0, here.Z - b.home.Z).Magnitude
	local hpFrac = b.humanoid.Health / b.humanoid.MaxHealth
	local staggerEnd = Status.expiry(statuses, b.model, STAGGER_TAG)
	if staggerEnd > now and b.brain.staggerUntil < staggerEnd then
		BossBrain.stagger(b.brain, now, staggerEnd - now)
	end
	local out = BossBrain.step(b.brain, b.kind, { now = now, targetDist = dist, homeDist = homeDist, hpFrac = hpFrac })
	if out.move == "target" and target then
		b.humanoid:MoveTo(target.Position)
	elseif out.move == "home" then
		b.humanoid:MoveTo(b.home)
	else
		b.humanoid:MoveTo(here)
	end
	if out.phaseChanged then
		b.model:SetAttribute("Phase", b.brain.phase)
	end
	if out.attack then
		local a = b.kind.attacks[out.attack]
		b.model:SetAttribute("TelegraphRange", a.range)
		b.model:SetAttribute("TelegraphArc", a.arcDot)
		b.model:SetAttribute("TelegraphSeconds", a.telegraph)
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
	if out.strike and out.attack then
		strike(b, out.attack, now)
	end
	if out.heal then
		b.humanoid.Health = b.humanoid.MaxHealth
		b.model:SetAttribute("LastHitBy", nil)
		b.model:SetAttribute("Phase", 1)
	end
end

function BossService.start()
	local centre = arenaCentre()
	for kindId in C.kinds do
		spawnBoss(kindId :: string, centre)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local now = os.clock()
		for _, b in table.clone(bosses) do
			tick(b, now)
		end
	end)
end

return BossService
