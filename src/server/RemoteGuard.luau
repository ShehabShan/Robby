--!strict
-- Remote rate guard (F-02, D-171). Blink already type- and bounds-checks every client→server payload;
-- this adds a per-player token bucket per event (`Config.RemoteRates`). Handlers call
-- `RemoteGuard.allow(player, "Event")` first and drop the call when it returns false. Range and
-- cooldown checks stay in each service.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local RemoteGuard = {}

local buckets: { [Player]: { [string]: RateLimit.Bucket } } = {}
local dropped: { [Player]: number } = {}

function RemoteGuard.allow(player: Player, event: string): boolean
	local cfg = Config.RemoteRates[event] or Config.RemoteRates.default
	local now = os.clock()
	local mine = buckets[player]
	if mine == nil then
		mine = {}
		buckets[player] = mine
	end
	local b = mine[event]
	if b == nil then
		b = RateLimit.new(cfg.burst, now)
		mine[event] = b
	end
	if RateLimit.allow(b, now, cfg.rate, cfg.burst) then
		return true
	end
	local n = (dropped[player] or 0) + 1
	dropped[player] = n
	if n == 1 or n % 100 == 0 then
		warn(`[RemoteGuard] {player.Name}: dropped {n} over-rate calls (last {event})`)
	end
	return false
end

Players.PlayerRemoving:Connect(function(player: Player)
	buckets[player] = nil
	dropped[player] = nil
end)

return RemoteGuard
