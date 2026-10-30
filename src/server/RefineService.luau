--!strict
-- Stage / Refine wiring (T-018d, D-076): while the client holds Refine (Blink `Refine{holding}`) and the player
-- stands within `Config.Stages.restRadius` of a part tagged `RestSpot`, Shards turn into Stage progress at
-- `refinePerSecond`. Rules live in the pure `Shared.Stages`. Publishes `Rank`, `Stage`, `StageProgress` (0..1),
-- `StageReady`, `AtRest` and `Shards` for the Core Shell HUD.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Refining = require(ReplicatedStorage.Shared.Refining)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)

local TAG = "RestSpot"
local built = Registry.build(All.content(Config))
local PUBLISH_EVERY = 0.25

local holding: { [Player]: boolean } = {}
local acc: { [Player]: number } = {}

local RefineService = {}

local function ensureRestSpot()
	if #CollectionService:GetTagged(TAG) > 0 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "RestSpot" -- provisional until the Mistvale hub (T-021)
	p.Anchored = true
	p.Size = Vector3.new(6, 1, 6)
	p.Position = Vector3.new(-20, 0.5, 0)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(120, 200, 255)
	p.Parent = workspace
	CollectionService:AddTag(p, TAG)
end

local function atRest(player: Player): boolean
	local character = player.Character
	local root = (if character then character:FindFirstChild("HumanoidRootPart") else nil) :: BasePart?
	if not root then
		return false
	end
	for _, inst in CollectionService:GetTagged(TAG) do
		if inst:IsA("BasePart") and (inst.Position - root.Position).Magnitude <= Config.Stages.restRadius then
			return true
		end
	end
	return false
end

RefineService.atRest = atRest -- used by BreakthroughService (T-018f)

local function publish(player: Player, data: any)
	local v = Stages.view(data, Config)
	player:SetAttribute("Rank", data.rank or 1)
	player:SetAttribute("Stage", v.stage)
	player:SetAttribute("StageProgress", math.floor(v.progress * 100 + 0.5) / 100)
	player:SetAttribute("StageReady", v.ready)
	player:SetAttribute("AtRest", atRest(player))
	player:SetAttribute("Shards", if type(data.wallet) == "table" then data.wallet.shards or 0 else 0)
end

function RefineService.start()
	ensureRestSpot()
	Net.Refine.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "Refine") then
			return
		end
		if value.holding == true then
			holding[player] = true
		else
			holding[player] = nil
			acc[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		holding[p] = nil
		acc[p] = nil
	end)
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		for player in holding do
			local data = DataService.get(player)
			if data and atRest(player) then
				local a = (acc[player] or 0) + Config.Stages.refinePerSecond * dt
				local whole = math.floor(a)
				acc[player] = a - whole
				if whole >= 1 then
					Stages.refine(data, Config, whole, true, Refining.multiplier(data, Config, built))
				end
			end
		end
		since += dt
		if since >= PUBLISH_EVERY then
			since = 0
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					publish(player, data)
				end
			end
		end
	end)
end

return RefineService
