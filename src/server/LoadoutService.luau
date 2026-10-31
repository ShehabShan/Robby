--!strict
-- Loadout server wiring (T-016b, D-064): validates Blink `Equip` requests against the profile and publishes
-- slot attributes for the HUD (`SlotCount`, `Slot<i>` species id, `Slot<i>Uid`, `LoadoutGaps`). Rules live in
-- the pure `Shared.Loadout`; the client is never trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local Loadout = require(ReplicatedStorage.Shared.Loadout)
local Refining = require(ReplicatedStorage.Shared.Refining)
local LoadoutScreen = require(ReplicatedStorage.Shared.LoadoutScreen)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)

local built = Registry.build(All.content(Config))

local LoadoutService = {}

local active: { [Player]: number } = {} -- selected core slot per player (T-036a, D-216); 1 until chosen

function LoadoutService.publish(player: Player, data: any)
	local n = Loadout.slotCount(Config, data.rank or 1)
	player:SetAttribute("SlotCount", n)
	for i = 1, Config.Loadout.maxSlots do
		local uid = data.loadout.slots[i]
		local inst = if i <= n and uid and uid ~= "" then data.kith[uid] else nil
		player:SetAttribute(`Slot{i}`, if inst then inst.speciesId else nil)
		player:SetAttribute(`Slot{i}Uid`, if inst then uid else nil)
	end
	player:SetAttribute("LoadoutGaps", table.concat(Loadout.gaps(data.loadout, data.kith, built, Config), ","))
	local slot = active[player] or 1
	player:SetAttribute("ActiveSlot", slot)
	player:SetAttribute("ActiveKith", Loadout.activeKith(data.loadout, data.kith, built, slot)) -- live Kith (D-216)
	player:SetAttribute("RefineYield", Refining.multiplier(data, Config, built)) -- loadout hint (T-025b2)
	player:SetAttribute("OwnedKith", LoadoutScreen.encodeOwned(data.kith)) -- loadout screen list (T-016d, D-069)
end

function LoadoutService.start()
	DataService.onLoaded(LoadoutService.publish)
	Net.Equip.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "Equip") then
			return
		end
		local data = DataService.get(player)
		if not data then
			return
		end
		local ok
		if value.uid == "" then
			ok = Loadout.unequip(data.loadout, value.slot)
		else
			ok = Loadout.equip(data.loadout, Config, data.rank or 1, data.kith, built, value.slot, value.uid, os.time())
		end
		if ok then
			LoadoutService.publish(player, data)
		end
	end)
	Net.SelectSlot.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "SelectSlot") then
			return
		end
		local data = DataService.get(player)
		local slot = if data then Loadout.selectSlot(Config, data.rank or 1, value.slot) else nil
		if data and slot then
			active[player] = slot
			LoadoutService.publish(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		active[player] = nil
	end)
end

return LoadoutService
