--!strict
-- Weave Loom wiring (T-020c, D-090): Blink `WeaveSet{core, support}` at a rest spot sets the Weave on an equipped
-- core move (support "" clears it). Rules live in the pure `Shared.Loom`; Abilities casts the woven move.
-- Publishes `WeaveResult` ("ok" or the reason), `ResonanceHint` (weave id, first time only) and `Weaves` for the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local All = require(ReplicatedStorage.Shared.Content.All)
local Loadout = require(ReplicatedStorage.Shared.Loadout)
local Loom = require(ReplicatedStorage.Shared.Loom)
local PathMarks = require(ReplicatedStorage.Shared.PathMarks)
local Registry = require(ReplicatedStorage.Shared.Registry)
local DataService = require(script.Parent.DataService)
local RefineService = require(script.Parent.RefineService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)

local built = Registry.build(All.content(Config))

local LoomService = {}

-- "core=support+support,..." for the Loom UI (T-020d).
function LoomService.publish(player: Player, data: any)
	local parts = {}
	for _, w in (data.loadout and data.loadout.weaves) or {} do
		table.insert(parts, `{w.core}={table.concat(w.supports or {}, "+")}`)
	end
	player:SetAttribute("Weaves", table.concat(parts, ","))
	player:SetAttribute("Marks", PathMarks.encode(data.marks)) -- Path Marks for the Loom panel (T-020f)
end

function LoomService.start()
	DataService.onLoaded(LoomService.publish)
	Net.WeaveSet.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "WeaveSet") then
			return
		end
		local data = DataService.get(player)
		local core, support = value.core, value.support
		if not data or typeof(core) ~= "string" or typeof(support) ~= "string" then
			return
		end
		local ok: boolean, why: string?, first: boolean = false, nil, false
		if not RefineService.atRest(player) then
			why = "not at a rest spot"
		elseif support == "" then
			ok, why = Loom.clear(data, core), "no Weave to clear"
		else
			local allowed = Loadout.allowedMoves(data.loadout, data.kith, built)
			ok, why, first = Loom.set(data, Config, built, allowed, core, { support }, os.time())
		end
		player:SetAttribute("WeaveResult", if ok and support == "" then "cleared" elseif ok then "ok" else why)
		if first then
			player:SetAttribute("ResonanceHint", Loom.weaveIdFor(core)) -- first time this Weave is made (journal)
		end
		if ok then
			LoomService.publish(player, data)
		end
	end)
end

return LoomService
