--!strict
-- Player data (T-012, D-047): ProfileStore session per player; ProfileSchema.load (migrate → reconcile →
-- validate, Retired ids resolved) runs in place on profile.Data before anything reads it.
-- A save the schema refuses (newer version, bad version) is left untouched and the player is kicked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Retired = require(ReplicatedStorage.Shared.Retired)
local ProfileStore: any = require(ServerScriptService.ServerPackages.ProfileStore) :: any

local STORE_NAME = "PlayerData"

local DataService = {}

local profiles: { [Player]: any } = {}

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
	profile:AddUserId(player.UserId)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
	else
		profile:EndSession()
	end
end

-- The loaded profile data for `player`, or nil while loading / after leaving.
function DataService.get(player: Player): any
	local profile = profiles[player]
	return if profile then profile.Data else nil
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
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
