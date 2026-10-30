--!strict
-- Ability server authority (ARCHITECTURE v2 §3, SCHEMAS §5, T-002c3): one CastRequest path driven by Content data.
-- Registry (validated Content) → Moves (costs, cooldown per (caster, moveId)) → Deliveries/Projectile (travel, pierce)
-- → Effects (onHit) → DamageMath. Remotes keep the spike's shape so the client and FX stay unchanged.
-- The server never trusts the client: aim is validated, Qi, cooldown and alive state are server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Qi = require(ReplicatedStorage.Shared.Qi)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Effects = require(ReplicatedStorage.Shared.Effects)
local Moves = require(ReplicatedStorage.Shared.Moves)
local Registry = require(ReplicatedStorage.Shared.Registry)
local DamageMath = require(ReplicatedStorage.Shared.DamageMath)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)
local Crescent = require(ReplicatedStorage.Shared.Content.Crescent)

local CHEST = Vector3.new(0, 0.5, 0)
local CastRequest = require(ReplicatedStorage.Shared.CastRequest)

local built, errors = Registry.build(Crescent.content(Config))
if #errors > 0 then
	warn("Content errors: " .. table.concat(errors, "; "))
end

type Shot = {
	caster: Player,
	character: Model,
	origin: Vector3,
	dir: Vector3,
	move: any,
	state: Projectile.State,
}

local Abilities = {}

local pools: { [Player]: Qi.Pool } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local shots: { Shot } = {}

local function lookupEffect(id: string): Effects.Effect?
	return built.effects[id]
end

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

-- Runs the move's onHit effects on the target; returns the total damage dealt.
local function applyOnHit(shot: Shot, humanoid: Humanoid): number
	local total = 0
	local ctx: Effects.Ctx = {
		now = os.clock(),
		tags = Tags,
		onOp = function(op: Effects.Op)
			if op.kind == "Dmg" then
				local base = if op.params then op.params.base else 0
				local amount = DamageMath.compute({ base = base or 0, rank = 1 })
				humanoid:TakeDamage(amount)
				total += amount
			end
		end,
	}
	local holder = Effects.newHolder() -- spike targets carry no tags yet (T-002d adds entity state)
	for _, effectId in shot.move.effects.onHit or {} do
		local effect = lookupEffect(effectId)
		if effect then
			Effects.apply(holder, effect, shot.caster.Name, ctx)
		end
	end
	return total
end

-- Sweeps the projectile from `from` to `to` studs along its path; may hit several targets in one step.
local function sweep(shot: Shot, from: number, to: number, hitFx: RemoteEvent)
	if to <= from then
		return
	end
	local p = shot.move.delivery.params
	local exclude: { Instance } = { shot.character }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local size = Vector3.new(p.hitbox.x, p.hitbox.y, p.hitbox.z)
	local start = shot.origin + shot.dir * from
	for _ = 1, p.maxHits + 4 do
		if shot.state.done and shot.state.hitCount >= p.maxHits then
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
			if Projectile.registerHit(shot.state, model:GetFullName() .. tostring(model:GetDebugId()), p) then
				local amount = applyOnHit(shot, humanoid)
				hitFx:FireAllClients(shot.move.fx.hit, shot.caster, result.Position, shot.dir, model, amount)
			end
		else
			-- walls and scenery do not stop the projectile in the spike; skip them
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
		cooldowns[player] = {}
		player:SetAttribute("QiMax", pool.max)
		publishQi(player, pool)
	end
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		join(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		pools[player] = nil
		cooldowns[player] = nil
	end)

	castRequest.OnServerEvent:Connect(function(player: Player, rawMoveId: unknown, raw: unknown, rawSeq: unknown)
		local pool = pools[player]
		local cds = cooldowns[player]
		local move = CastRequest.decode(rawMoveId, rawSeq, built.moves)
		if not pool or not cds or not move or typeof(raw) ~= "Vector3" then
			return
		end
		local v = raw :: Vector3
		if not Projectile.isValidDirection(v.X, v.Y, v.Z) then
			return
		end
		local x, z, okFlat = Projectile.flatten(v.X, v.Z)
		local character = player.Character
		local root = aliveRoot(character)
		if not okFlat or not root or not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local caster: Moves.Caster = {
			qi = pool.current,
			strain = 0,
			strainMax = math.huge, -- Strain arrives with Upkeep (later task)
			hp = if humanoid then humanoid.Health else 0,
			cooldowns = cds,
		}
		if not Moves.pay(caster, move, os.clock()) then
			return
		end
		pool.current = caster.qi
		publishQi(player, pool)
		local dir = Vector3.new(x, 0, z)
		local origin = root.Position + dir * move.delivery.params.spawnOffset + CHEST
		table.insert(shots, {
			caster = player,
			character = character,
			origin = origin,
			dir = dir,
			move = move,
			state = Projectile.new(),
		})
		for _, slot in { "cast", "travel" } do
			local fxId = move.fx[slot]
			if fxId then
				castFx:FireAllClients(fxId, player, origin, dir)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for player, pool in pools do
			Qi.regen(pool, dt)
			publishQi(player, pool)
		end
		for i = #shots, 1, -1 do
			local shot = shots[i]
			local from, to = Projectile.step(shot.state, dt, shot.move.delivery.params)
			sweep(shot, from, to, hitFx)
			if shot.state.done then
				table.remove(shots, i)
			end
		end
	end)
end

return Abilities
