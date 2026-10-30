--!strict
-- Server sprint speed guard (T-026b3b, D-166): samples each character's root position at 4 Hz and runs
-- the pure `Shared.SpeedGuard`. An accepted Wind Step opens a burst window (`burst`). Repeated
-- violations move the character back to its last good position (height kept) and log a warning.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SpeedGuard = require(ReplicatedStorage.Shared.SpeedGuard)

local SAMPLE_DT = 0.25
local WIND_STEP_BURST = 0.25 -- mirrors BURST_SECONDS in client AbilityInput
local G = Config.SpeedGuard
local CFG: SpeedGuard.Cfg = {
	sprint = Config.Movement.sprint,
	burstSpeed = Config.Abilities.WindStep.distance / WIND_STEP_BURST,
	burstSeconds = G.burstSeconds,
	tolerance = G.tolerance,
	slack = G.slack,
	strikes = G.strikes,
}

local states: { [Player]: SpeedGuard.State } = {}

local SpeedGuardService = {}

local function stateFor(player: Player): SpeedGuard.State
	local s = states[player]
	if not s then
		s = SpeedGuard.new()
		states[player] = s
	end
	return s
end

-- Call when the server accepts a burst move (Wind Step) for `player`.
function SpeedGuardService.burst(player: Player)
	SpeedGuard.burst(CFG, stateFor(player), os.clock())
end

-- Call after the server itself moves a character (teleport); respawns reset automatically.
function SpeedGuardService.reset(player: Player)
	SpeedGuard.reset(stateFor(player))
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function()
		SpeedGuardService.reset(player)
	end)
end

function SpeedGuardService.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < SAMPLE_DT then
			return
		end
		acc = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if character and root and root:IsA("BasePart") then
				local pos = root.Position
				local verdict, gx, gz = SpeedGuard.check(CFG, stateFor(player), pos.X, pos.Z, now)
				if verdict == "correct" and gx and gz then
					character:PivotTo(CFrame.new(gx, pos.Y, gz) * root.CFrame.Rotation)
					warn(`SpeedGuard: corrected {player.Name} (too fast)`)
				end
			end
		end
	end)
end

return SpeedGuardService
