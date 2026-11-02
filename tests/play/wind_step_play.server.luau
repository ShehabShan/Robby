--!strict
-- T-051a play mode (D-373): owner presses R / touch button to Wind Step by hand.
-- TEST place only: refuses to run unless the bound test universe/place match (or Studio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Motion = require(ReplicatedStorage.Shared.WindStep)
local Play = require(ReplicatedStorage.Shared.WindStepPlay)
local Driver = require(script.WindStepDriver)

local universeId = script:GetAttribute("TestUniverseId")
local placeId = script:GetAttribute("TestPlaceId")
local studio = RunService:IsStudio()
if
	not studio
	and (type(universeId) ~= "number" or universeId <= 0 or game.GameId ~= universeId or game.PlaceId ~= placeId)
then
	warn("WIND_STEP_PLAY_BLOCKED: TEST place only")
	return
end

local remote = Instance.new("RemoteEvent")
remote.Name = "WindStepPlay"
local status = Instance.new("RemoteEvent")
status.Name = "WindStepPlayStatus"
local gate = Play.new(script:GetAttribute("Cooldown"))
local active: { [Player]: Driver.Lease } = {}

remote.OnServerEvent:Connect(function(player: Player, mx: any, mz: any, fx: any, fz: any)
	local now = os.clock()
	local ok, dx, dz, reason = Play.request(gate, player.UserId, now, mx, mz, fx, fz)
	if not ok then
		if reason == "cooldown" then
			status:FireClient(player, "cooldown", Play.remaining(gate, player.UserId, now))
		end
		return
	end
	local previous = active[player]
	if previous and previous.active() then
		Play.refund(gate, player.UserId)
		return
	end
	local lease = Driver.prepare(player, Motion.PROPOSED, Vector3.new(dx, 0, dz))
	if not lease or not lease.commit(workspace:GetServerTimeNow()) then
		if lease then
			lease.stop()
		end
		Play.refund(gate, player.UserId)
		status:FireClient(player, "refused", 0)
		return
	end
	active[player] = lease
	status:FireClient(player, "dash", gate.cooldown)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local lease = active[player]
	active[player] = nil
	if lease then
		lease.stop()
	end
	Play.forget(gate, player.UserId)
end)

status.Parent = ReplicatedStorage
remote.Parent = ReplicatedStorage
print("WIND_STEP_PLAY_READY cooldown=" .. gate.cooldown)
