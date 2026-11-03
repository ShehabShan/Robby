--!strict
-- Admin panel wiring (T-054b, D-400). Blink `AdminRequest` from the client; the server re-checks the allowlist
-- (`Config.Admin.userIds`) and re-validates every request with `Shared.AdminRules`. Non-admins are refused and
-- logged. Profile actions are applied by AdminRules (grants marked test-only); refill and spawnBeast act on the
-- live world here. Sets the `IsAdmin` player attribute (the client panel opens only when it is true) and
-- `AdminResult` ("ok: ..." / "refused: ...") after every request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(ReplicatedStorage.Shared.Registry)
local All = require(ReplicatedStorage.Shared.Content.All)
local AdminRules = require(ReplicatedStorage.Shared.AdminRules)
local Abilities = require(script.Parent.Abilities)
local BeastService = require(script.Parent.BeastService)
local DataService = require(script.Parent.DataService)
local LoadoutService = require(script.Parent.LoadoutService)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)

local built = Registry.build(All.content(Config))

local AdminService = {}

-- Owned Kith for the admin panel's remove list ("uid|speciesId,..."), admins only.
local function publishKith(player: Player, data: any)
	if not AdminRules.isAdmin(Config, player.UserId) or type(data.kith) ~= "table" then
		return
	end
	local parts = {}
	for uid, k in data.kith do
		table.insert(parts, `{uid}|{if type(k) == "table" then k.speciesId else "?"}`)
	end
	table.sort(parts)
	player:SetAttribute("AdminKith", table.concat(parts, ","))
end

local function report(player: Player, data: any, req: any, ok: boolean, detail: string)
	if data then
		AdminRules.log(Config, data, player.UserId, req, ok, detail, os.time())
	end
	local action = if type(req) == "table" and type(req.action) == "string" then req.action else "?"
	print(`[Admin] {player.Name} ({player.UserId}) {action}: {if ok then "ok" else "refused"} {detail}`)
	player:SetAttribute("AdminResult", `{if ok then "ok" else "refused"}: {detail}`)
end

local function live(player: Player, req: any): (boolean, string)
	if req.action == "refill" then
		local pool = Abilities.pool(player)
		if pool then
			pool.current = pool.max
		end
		Abilities.resetCooldowns(player)
		return pool ~= nil, if pool then "Qi full, cooldowns reset" else "no Qi pool"
	end
	-- spawnBeast: in front of the character, at the clamped distance; test beasts never respawn
	local char = player.Character
	local root = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false, "no character"
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dir = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	BeastService.spawnTest(req.kind, root.Position + dir * req.distance)
	return true, `{req.kind} at {math.floor(req.distance)} studs`
end

function AdminService.start()
	Players.PlayerAdded:Connect(function(player: Player)
		player:SetAttribute("IsAdmin", AdminRules.isAdmin(Config, player.UserId))
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("IsAdmin", AdminRules.isAdmin(Config, player.UserId))
	end
	DataService.onLoaded(publishKith)
	Net.AdminRequest.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "AdminRequest") then
			return
		end
		local data = DataService.get(player)
		if not AdminRules.isAdmin(Config, player.UserId) then
			report(player, nil, value, false, "not an admin")
			return
		end
		if not data then
			report(player, nil, value, false, "profile not loaded")
			return
		end
		local req, why = AdminRules.validate(Config, built, value)
		if not req then
			report(player, data, value, false, why or "invalid")
			return
		end
		local ok, detail
		if req.action == "refill" or req.action == "spawnBeast" then
			ok, detail = live(player, req)
		else
			ok, detail = AdminRules.apply(data, req)
			if ok then
				LoadoutService.publish(player, data)
				publishKith(player, data)
				DataService.saveNow(player)
			end
		end
		report(player, data, req, ok, detail)
	end)
end

return AdminService
