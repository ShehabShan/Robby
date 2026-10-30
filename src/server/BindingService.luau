--!strict
-- Binding server wiring (T-017b, D-071): the tug-of-war runs on the server. The client only sends
-- `BindStart` (target) and `BindInput` (channel held, Shard pressed); the server owns the duel, Qi, Shards
-- and the reward. Rules live in the pure `Shared.Binding` / `Shared.BindingRules`.
-- Publishes player attributes for the UI (T-017c): `BindState` ("" | "running" | "bound" | "fled"),
-- `BindProgress` (0..1), `Shards`, and `HeartKith` (uid). A wild Kith is a Model with `WildKith`/`Will` attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local Binding = require(ReplicatedStorage.Shared.Binding)
local BindingRules = require(ReplicatedStorage.Shared.BindingRules)
local Abilities = require(script.Parent.Abilities)
local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)

local built = Registry.build(All.content(Config))

type Active = { duel: Binding.Duel, target: Model, speciesId: string, channel: boolean }

local active: { [Player]: Active } = {}

local BindingService = {}

local function publish(player: Player, state: string, progress: number)
	player:SetAttribute("BindState", state)
	player:SetAttribute("BindProgress", math.floor(progress * 100 + 0.5) / 100)
end

local function publishWallet(player: Player, data: any)
	player:SetAttribute("Shards", data.wallet.shards or 0)
	player:SetAttribute("HeartKith", data.heartKith)
end

local function release(a: Active)
	if a.target.Parent then
		a.target:SetAttribute("BindingBy", nil)
	end
end

local function cancel(player: Player)
	local a = active[player]
	if a then
		active[player] = nil
		release(a)
		publish(player, "", 0)
	end
end

local function finish(player: Player, a: Active, result: string)
	active[player] = nil
	release(a)
	publish(player, result, a.duel.progress)
	local humanoid = a.target:FindFirstChildOfClass("Humanoid")
	if result == "bound" then
		local data = DataService.get(player)
		if data then
			BindingRules.grant(data, a.speciesId)
			LoadoutService.publish(player, data)
			publishWallet(player, data)
		end
		if humanoid then
			humanoid.Health = 0 -- the wild Kith is taken; its spawner respawns it
		end
	elseif humanoid then
		humanoid.Health = humanoid.MaxHealth -- it fled and recovered
	end
end

local function onStart(player: Player, target: Model)
	if active[player] or target:GetAttribute("BindingBy") ~= nil then
		return
	end
	local data = DataService.get(player)
	local pool = Abilities.pool(player)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local character = player.Character
	local root = (if character then character:FindFirstChild("HumanoidRootPart") else nil) :: BasePart?
	local targetRoot = target.PrimaryPart
	if not (data and pool and humanoid and root and targetRoot) then
		return
	end
	local distance = (root.Position - targetRoot.Position).Magnitude
	local speciesId = target:GetAttribute("WildKith")
	if not BindingRules.canStart(Config, built, speciesId, humanoid.Health, humanoid.MaxHealth, distance) then
		return
	end
	local will = target:GetAttribute("Will")
	local duel = BindingRules.start(
		Config,
		data,
		if typeof(will) == "number" then will else Config.Binding.wildWill,
		pool.current
	)
	target:SetAttribute("BindingBy", player.UserId)
	active[player] = { duel = duel, target = target, speciesId = speciesId :: string, channel = false }
	publishWallet(player, data)
	publish(player, "running", duel.progress)
end

local function onInput(player: Player, channel: boolean, shard: boolean)
	local a = active[player]
	if not a then
		return
	end
	a.channel = channel
	if shard then
		local data = DataService.get(player)
		local pool = Abilities.pool(player)
		if data and pool then
			a.duel.qi = pool.current
			if BindingRules.useShard(a.duel, Config, data, pool.max) then
				pool.current = a.duel.qi
				publishWallet(player, data)
			end
		end
	end
end

local function step(dt: number)
	for player, a in active do
		local pool = Abilities.pool(player)
		local humanoid = a.target:FindFirstChildOfClass("Humanoid")
		if not pool or not a.target.Parent or not humanoid or humanoid.Health <= 0 then
			cancel(player)
		else
			a.duel.qi = pool.current
			Binding.step(a.duel, Config, dt, a.channel)
			pool.current = a.duel.qi
			if a.duel.result then
				finish(player, a, a.duel.result)
			else
				publish(player, "running", a.duel.progress)
			end
		end
	end
end

function BindingService.start()
	DataService.onLoaded(publishWallet)
	Net.BindStart.On(function(player: Player, value)
		onStart(player, value.target)
	end)
	Net.BindInput.On(function(player: Player, value)
		onInput(player, value.channel, value.shard)
	end)
	Players.PlayerRemoving:Connect(cancel)
	RunService.Heartbeat:Connect(step)
end

return BindingService
