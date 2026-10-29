--!strict
-- Server entry point: wires the pure RoundState machine to Roblox services and
-- replicates the round state to clients via ReplicatedStorage attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundState = require(ReplicatedStorage.Shared.RoundState)

local state = RoundState.new()
local finished: { [Player]: boolean } = {}

local function publish()
	ReplicatedStorage:SetAttribute("Phase", state.phase)
	ReplicatedStorage:SetAttribute("TimeLeft", math.ceil(state.timeLeft))
	ReplicatedStorage:SetAttribute("Round", state.round)
end

local function allFinished(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not finished[player] then
			return false
		end
	end
	return true
end

Players.PlayerRemoving:Connect(function(player: Player)
	finished[player] = nil
end)

publish()

RunService.Heartbeat:Connect(function(dt: number)
	local newState, entered = RoundState.step(state, dt, #Players:GetPlayers(), allFinished(), Config.Round)
	state = newState
	if entered == "Racing" then
		table.clear(finished)
	end
	publish()
end)
