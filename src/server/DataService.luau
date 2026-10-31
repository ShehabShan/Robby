--!strict
-- Player data (T-012, D-047): ProfileStore session per player; ProfileSchema.load (migrate → reconcile →
-- validate, Retired ids resolved) runs in place on profile.Data before anything reads it.
-- A save the schema refuses (newer version, bad version) is left untouched and the player is kicked.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local Loadout = require(ReplicatedStorage.Shared.Loadout)

local built = Registry.build(All.content(Config))
local loadedListeners: { (Player, any) -> () } = {}
local Retired = require(ReplicatedStorage.Shared.Retired)
local ProfileStore: any = require(ServerScriptService.ServerPackages.ProfileStore) :: any

local STORE_NAME = ProfileSchema.storeName(RunService:IsStudio()) -- T-033
local SAVE_GAP = 30 -- seconds between early saves; autosave (5 min) and session end cover the rest

local DataService = {}

local profiles: { [Player]: any } = {}
local lastSave: { [Player]: number } = {}
local pendingSave: { [Player]: boolean } = {}

local function resolve(id: string): (string?, boolean)
	return Retired.resolve(id)
end

local function load(store: any, player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end
	local data, issues = ProfileSchema.load(profile.Data, resolve)
	if data == nil then
		profile:EndSession()
		player:Kick("Your save needs a newer server. Please rejoin.")
		warn(`DataService: refused save for {player.UserId}: {table.concat(issues, "; ")}`)
		return
	end
	for _, issue in issues do
		warn(`DataService: {player.UserId}: {issue}`)
	end
	for _, issue in Loadout.prepare(data, Config, built) do -- starter Kith + sanitized loadout (T-016b)
		warn(`DataService: {player.UserId}: loadout {issue}`)
	end
	profile:AddUserId(player.UserId)
	profile.OnSave:Connect(function() -- T-033: never let one bad value fail the write
		for _, issue in ProfileSchema.sanitize(profile.Data) do
			warn(`DataService: {player.UserId}: save fix {issue}`)
		end
	end)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
		for _, fn in loadedListeners do
			task.spawn(fn, player, profile.Data)
		end
	else
		profile:EndSession()
	end
end

-- Calls `fn(player, data)` after each profile finishes loading (T-016b: LoadoutService publishes slots).
function DataService.onLoaded(fn: (Player, any) -> ())
	table.insert(loadedListeners, fn)
end

-- The loaded profile data for `player`, or nil while loading / after leaving.
function DataService.get(player: Player): any
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Saves soon after a meaningful change (rank up, fusion, purchase), at most once per SAVE_GAP;
-- a change inside the gap is saved when the gap ends (T-033).
function DataService.saveNow(player: Player)
	local profile = profiles[player]
	if profile == nil or pendingSave[player] then
		return
	end
	local wait = SAVE_GAP - (os.clock() - (lastSave[player] or -math.huge))
	if wait <= 0 then
		lastSave[player] = os.clock()
		profile:Save()
		return
	end
	pendingSave[player] = true
	task.delay(wait, function()
		pendingSave[player] = nil
		if profiles[player] == profile and profile:IsActive() then
			lastSave[player] = os.clock()
			profile:Save()
		end
	end)
end

function DataService.start()
	local store = ProfileStore.New(STORE_NAME, ProfileSchema.template())
	local function added(player: Player)
		task.spawn(load, store, player)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		lastSave[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
