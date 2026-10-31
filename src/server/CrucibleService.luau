--!strict
-- Crucible wiring (T-019c, D-083): Blink `CrucibleStart{a, b}` at a rest spot opens a fusion of two owned Kith.
-- Known recipes fuse at once (safe). Experimental ones run the focus mini-game: the server picks the zones and owns
-- the clock (`workspace:GetServerTimeNow()`), the client only sends `CruciblePress`. The server rolls the result;
-- a fail Wounds one Kith and causes Recoil (Qi drained, regen halved). Rules live in `Shared.Crucible(Focus)`.
-- Publishes `CrucibleRound`, `CrucibleZone`, `CrucibleRoundStart`, `CrucibleOdds`, `CrucibleResult`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Crucible = require(ReplicatedStorage.Shared.Crucible)
local CrucibleFocus = require(ReplicatedStorage.Shared.CrucibleFocus)
local Abilities = require(script.Parent.Abilities)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RefineService = require(script.Parent.RefineService)

type Session = { a: string, b: string, recipeId: string, focus: CrucibleFocus.Focus }

local sessions: { [Player]: Session } = {}
local rng = Random.new()

local CrucibleService = {}

local function clock(): number
	return workspace:GetServerTimeNow()
end

local function publish(player: Player, s: Session?)
	local f = if s and not s.focus.done then s.focus else nil
	player:SetAttribute("CrucibleRound", if f then f.round else nil)
	player:SetAttribute("CrucibleZone", if f then f.zones[f.round] else nil)
	player:SetAttribute("CrucibleRoundStart", if f then f.roundStart else nil)
	local data = DataService.get(player)
	player:SetAttribute(
		"CrucibleOdds",
		if s and data then Crucible.odds(data, Config, s.recipeId, CrucibleFocus.result(s.focus, Config)) else nil
	)
end

local function finish(player: Player, s: Session)
	sessions[player] = nil
	local data = DataService.get(player)
	local res = if data
		then Crucible.fuse(data, Config, s.a, s.b, CrucibleFocus.result(s.focus, Config), rng:NextNumber(), os.time())
		else nil
	if data and res and not res.success then
		local pool = Abilities.pool(player)
		if pool then
			data.timers = data.timers or {}
			data.timers.recoilUntil = Crucible.applyRecoil(pool, Config, os.time())
		end
	end
	if res then
		DataService.saveNow(player) -- T-033: fusion result
	end
	player:SetAttribute("CrucibleResult", if res then (if res.success then "success" else "failed") else "refused")
	publish(player, nil)
end

function CrucibleService.start()
	Net.CrucibleStart.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "CrucibleStart") then
			return
		end
		if sessions[player] then
			return
		end
		local data = DataService.get(player)
		if not data or not RefineService.atRest(player) then
			return
		end
		local id = Crucible.recipe(data, Config, value.a, value.b, os.time())
		if not id then
			player:SetAttribute("CrucibleResult", "refused")
			return
		end
		local rolls = {}
		for i = 1, Config.Crucible.focus.rounds do
			rolls[i] = rng:NextNumber()
		end
		local s: Session =
			{ a = value.a, b = value.b, recipeId = id, focus = CrucibleFocus.new(Config, rolls, clock()) }
		sessions[player] = s
		player:SetAttribute("CrucibleResult", nil)
		if Crucible.odds(data, Config, id, 0) >= 1 then
			finish(player, s) -- known recipe: safe, no mini-game
		else
			publish(player, s)
		end
	end)
	Net.CruciblePress.On(function(player: Player, _)
		if not RemoteGuard.allow(player, "CruciblePress") then
			return
		end
		local s = sessions[player]
		if not s then
			return
		end
		CrucibleFocus.press(s.focus, Config, clock())
		if s.focus.done then
			finish(player, s)
		else
			publish(player, s)
		end
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		sessions[p] = nil
	end)
	RunService.Heartbeat:Connect(function()
		local now = clock()
		for player, s in sessions do
			local round = s.focus.round
			CrucibleFocus.step(s.focus, Config, now)
			if s.focus.done then
				finish(player, s)
			elseif s.focus.round ~= round then
				publish(player, s)
			end
		end
		local wall = os.time()
		for _, player in Players:GetPlayers() do -- Recoil: halved Qi regen while active
			local pool = Abilities.pool(player)
			local data = DataService.get(player)
			if pool and data then
				local recoil = if type(data.timers) == "table" then data.timers.recoilUntil else nil
				pool.regenRate = Crucible.regenRate(Config.Qi.regen, Config, recoil, wall)
			end
		end
	end)
end

return CrucibleService
