--!strict
-- Loadout server wiring (T-016b, D-064): validates Blink `Equip` requests against the profile and publishes
-- slot attributes for the HUD (`SlotCount`, `Slot<i>` species id, `Slot<i>Uid`, `LoadoutGaps`). Rules live in
-- the pure `Shared.Loadout`; the client is never trusted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local Loadout = require(ReplicatedStorage.Shared.Loadout)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)

local built = Registry.build(All.content(Config))

local LoadoutService = {}

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
end

function LoadoutService.start()
	DataService.onLoaded(LoadoutService.publish)
	Net.Equip.On(function(player: Player, value)
		local data = DataService.get(player)
		if not data then
			return
		end
		local ok
		if value.uid == "" then
			ok = Loadout.unequip(data.loadout, value.slot)
		else
			ok = Loadout.equip(data.loadout, Config, data.rank or 1, data.kith, built, value.slot, value.uid)
		end
		if ok then
			LoadoutService.publish(player, data)
		end
	end)
end

return LoadoutService
