--!strict
-- Upkeep wiring (T-018b, D-074): equipped Kith drain Satiety (faster while the player is fighting) and recover
-- Strain on a 0.5 s tick; the `Feed` remote spends one species food from `data.items`. Rules live in the pure
-- `Shared.KithCare`; Abilities blocks Dormant/Exhausted casts and charges Strain. Publishes per slot
-- `Slot<i>Strain`, `Slot<i>Satiety` (0..1) and `Slot<i>State` for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local KithCare = require(ReplicatedStorage.Shared.KithCare)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)

local TICK = 0.5

local built = Registry.build(All.content(Config))
local lastFight: { [Player]: number } = {}

local UpkeepService = {}

-- Marks `player` as fighting now (called on every paid cast).
function UpkeepService.fought(player: Player)
	lastFight[player] = os.clock()
end

local function rankOf(speciesId: any): number
	local k = built.kith[speciesId]
	return if k and typeof(k.rank) == "number" then k.rank else 1
end

local function usableData(data: any): boolean
	return data ~= nil
		and type(data.kith) == "table"
		and type(data.loadout) == "table"
		and type(data.loadout.slots) == "table"
end

local function publish(player: Player, data: any, now: number)
	for i = 1, Config.Loadout.maxSlots do
		local uid = data.loadout.slots[i]
		local inst = if type(uid) == "string" and uid ~= "" then data.kith[uid] else nil
		if inst then
			local strain, satiety, state = KithCare.view(inst, Config, now)
			player:SetAttribute(`Slot{i}Strain`, math.floor(strain * 100 + 0.5) / 100)
			player:SetAttribute(`Slot{i}Satiety`, math.floor(satiety * 100 + 0.5) / 100)
			player:SetAttribute(`Slot{i}State`, state)
		else
			player:SetAttribute(`Slot{i}Strain`, nil)
			player:SetAttribute(`Slot{i}Satiety`, nil)
			player:SetAttribute(`Slot{i}State`, nil)
		end
	end
end

local function tick(dt: number)
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if usableData(data) then
			local fighting = os.clock() - (lastFight[player] or -math.huge) < Config.Upkeep.fightWindow
			for _, uid in data.loadout.slots do
				local inst = if type(uid) == "string" then data.kith[uid] else nil
				if inst then
					KithCare.ensure(inst, Config)
					KithCare.drain(inst, Config, rankOf(inst.speciesId), dt, fighting)
					KithCare.recover(inst, Config, dt, now)
				end
			end
			publish(player, data, now)
		end
	end
end

function UpkeepService.start()
	Net.Feed.On(function(player: Player, value)
		local data = DataService.get(player)
		if not usableData(data) or type(value.uid) ~= "string" then
			return
		end
		local inst = data.kith[value.uid]
		if not inst then
			return
		end
		local k = built.kith[inst.speciesId]
		if KithCare.feedFrom(data, inst, Config, if k then k.food else nil, value.rare == true) then
			publish(player, data, os.time())
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		lastFight[p] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= TICK then
			tick(acc)
			acc = 0
		end
	end)
end

return UpkeepService
