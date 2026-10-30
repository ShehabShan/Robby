--!strict
-- Crescent Cut server authority (.ai/SPIKE.md §3): remotes, Qi pools, validation,
-- server-side projectile simulation (blockcast per step) and damage. Never trusts the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrescentCut = require(ReplicatedStorage.Shared.Kith.CrescentCut)
local Qi = require(ReplicatedStorage.Shared.Qi)

local cfg = Config.Abilities.CrescentCut
local CHEST = Vector3.new(0, 0.5, 0)

type Shot = {
	caster: Player,
	character: Model,
	origin: Vector3,
	dir: Vector3,
	proj: CrescentCut.Projectile,
}

local Abilities = {}

local pools: { [Player]: Qi.Pool } = {}
local lastCast: { [Player]: number } = {}
local shots: { Shot } = {}

local function remote(folder: Folder, name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local function publishQi(player: Player, pool: Qi.Pool)
	local shown = math.floor(pool.current)
	if player:GetAttribute("Qi") ~= shown then
		player:SetAttribute("Qi", shown)
	end
end

local function aliveRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Sweeps the blade from `from` to `to` studs along its path; may hit several targets in one step.
local function sweep(shot: Shot, from: number, to: number, hitFx: RemoteEvent)
	if to <= from then
		return
	end
	local exclude: { Instance } = { shot.character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local size = Vector3.new(cfg.hitboxSize.x, cfg.hitboxSize.y, cfg.hitboxSize.z)
	local start = shot.origin + shot.dir * from
	for _ = 1, cfg.maxHits + 4 do
		if shot.proj.done and shot.proj.hitCount >= cfg.maxHits then
			return
		end
		params.FilterDescendantsInstances = exclude
		local result = workspace:Blockcast(CFrame.lookAt(start, start + shot.dir), size, shot.dir * (to - from), params)
		if not result then
			return
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		if model and humanoid and humanoid.Health > 0 then
			table.insert(exclude, model)
			if CrescentCut.registerHit(shot.proj, model:GetFullName() .. tostring(model:GetDebugId()), cfg) then
				local amount = CrescentCut.damageFor(1, cfg)
				humanoid:TakeDamage(amount)
				hitFx:FireAllClients(shot.caster, model, amount, result.Position)
			end
		else
			-- walls and scenery do not stop the blade in the spike; skip them
			table.insert(exclude, result.Instance)
		end
	end
end

function Abilities.start()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	local castRequest = remote(folder, "CastRequest")
	local castFx = remote(folder, "CastFx")
	local hitFx = remote(folder, "HitFx")
	folder.Parent = ReplicatedStorage

	local function join(player: Player)
		local pool = Qi.new(Config.Qi.max, Config.Qi.regen)
		pools[player] = pool
		player:SetAttribute("QiMax", pool.max)
		publishQi(player, pool)
	end
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		join(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		pools[player] = nil
		lastCast[player] = nil
	end)

	castRequest.OnServerEvent:Connect(function(player: Player, raw: unknown)
		local pool = pools[player]
		if not pool or typeof(raw) ~= "Vector3" then
			return
		end
		local v = raw :: Vector3
		if not CrescentCut.isValidDirection(v.X, v.Y, v.Z) then
			return
		end
		local x, z, okFlat = CrescentCut.flatten(v.X, v.Z)
		local character = player.Character
		local root = aliveRoot(character)
		local now = os.clock()
		local ok = CrescentCut.tryCast(now, lastCast[player], pool.current, root ~= nil, cfg)
		if not okFlat or not ok or not root or not character then
			return
		end
		Qi.spend(pool, cfg.cost)
		publishQi(player, pool)
		lastCast[player] = now
		local dir = Vector3.new(x, 0, z)
		local origin = root.Position + dir * cfg.spawnOffset + CHEST
		table.insert(shots, {
			caster = player,
			character = character,
			origin = origin,
			dir = dir,
			proj = CrescentCut.newProjectile(),
		})
		castFx:FireAllClients(player, origin, dir)
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for player, pool in pools do
			Qi.regen(pool, dt)
			publishQi(player, pool)
		end
		for i = #shots, 1, -1 do
			local shot = shots[i]
			local from, to = CrescentCut.stepProjectile(shot.proj, dt, cfg)
			sweep(shot, from, to, hitFx)
			if shot.proj.done then
				table.remove(shots, i)
			end
		end
	end)
end

return Abilities
