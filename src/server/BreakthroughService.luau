--!strict
-- Breakthrough trial wiring (T-018f, D-080): Blink `Breakthrough{start}` starts the Rank trial when the Peak is
-- full and the player is at a rest spot. Damage the player deals during the trial (moves on dummies / wave enemies)
-- cracks the shell via `onDamage`. Rules live in the pure `Shared.Breakthrough`. Publishes `TrialWave`,
-- `TrialWaves`, `TrialCrack` (0..1 of the wave), `TrialLeft` (s) and `TrialResult`; Rank/Stage on finish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Breakthrough = require(ReplicatedStorage.Shared.Breakthrough)
local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RefineService = require(script.Parent.RefineService)

local PUBLISH_EVERY = 0.25

local trials: { [Player]: Breakthrough.Trial } = {}

local BreakthroughService = {}

local function publish(player: Player, t: Breakthrough.Trial?)
	if t then
		local v = Breakthrough.view(t, Config)
		player:SetAttribute("TrialWave", v.wave)
		player:SetAttribute("TrialWaves", v.waves)
		player:SetAttribute("TrialCrack", math.floor(v.crack * 100 + 0.5) / 100)
		player:SetAttribute("TrialLeft", v.timeLeft)
	else
		for _, name in { "TrialWave", "TrialWaves", "TrialCrack", "TrialLeft" } do
			player:SetAttribute(name, nil)
		end
	end
end

-- Called by Abilities / CombatService after the player deals damage.
function BreakthroughService.onDamage(player: Player, amount: number)
	local t = trials[player]
	if t then
		Breakthrough.hit(t, Config, Breakthrough.crackFor(Config, amount))
	end
end

local function finish(player: Player, t: Breakthrough.Trial)
	trials[player] = nil
	local data = DataService.get(player)
	if data then
		Breakthrough.finish(data, t, os.time())
		player:SetAttribute("Rank", data.rank or 1)
		player:SetAttribute("Stage", data.stage or 1)
		player:SetAttribute("StageReady", Stages.ready(data, Config))
	end
	player:SetAttribute("TrialResult", t.result)
	publish(player, nil)
end

function BreakthroughService.start()
	Net.Breakthrough.On(function(player: Player, value)
		if value.start ~= true or trials[player] then
			return
		end
		local data = DataService.get(player)
		if not data or not RefineService.atRest(player) then
			return
		end
		local t = Breakthrough.start(data, Config, os.time())
		if t then
			trials[player] = t
			player:SetAttribute("TrialResult", nil)
			publish(player, t)
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		trials[p] = nil
	end)
	local since = 0
	RunService.Heartbeat:Connect(function(dt: number)
		since += dt
		local due = since >= PUBLISH_EVERY
		if due then
			since = 0
		end
		for player, t in trials do
			Breakthrough.step(t, dt)
			if t.result ~= nil then
				finish(player, t)
			elseif due then
				publish(player, t)
			end
		end
	end)
end

return BreakthroughService
