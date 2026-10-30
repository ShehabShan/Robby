--!strict
-- Ability server authority (ARCHITECTURE v2 §3, SCHEMAS §5, T-002c3): one CastRequest path driven by Content data.
-- Registry (validated Content) → Moves (costs, cooldown per (caster, moveId)) → Deliveries/Projectile (travel, pierce)
-- → Effects (onHit) → DamageMath. Remotes are Blink-generated (Net.luau, T-011); CastFx/HitFx carry Content fx ids.
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
local All = require(ReplicatedStorage.Shared.Content.All)
local Status = require(ReplicatedStorage.Shared.Status)
local BreakthroughService = require(script.Parent.BreakthroughService)
local statuses = require(script.Parent.StatusStore)
local SpeedGuardService = require(script.Parent.SpeedGuardService)
local Loadout = require(ReplicatedStorage.Shared.Loadout)
local DataService = require(script.Parent.DataService)
local PathMarks = require(ReplicatedStorage.Shared.PathMarks)
local Loom = require(ReplicatedStorage.Shared.Loom)
local KithCare = require(ReplicatedStorage.Shared.KithCare)
local UpkeepService = require(script.Parent.UpkeepService)

local CHEST = Vector3.new(0, 0.5, 0)

-- Stable per-model hit key for pierce tracking. `GetDebugId` needs Plugin capability and errors in live
-- servers (S12 owner playtest), so keys come from a weak table instead.
local hitKeys: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local nextHitKey = 0
local function hitKey(model: Instance): string
	local key = hitKeys[model]
	if key == nil then
		nextHitKey += 1
		key = `m{nextHitKey}`
		hitKeys[model] = key
	end
	return key
end
local CastRequest = require(ReplicatedStorage.Shared.CastRequest)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)
local RemoteGuard = require(script.Parent.RemoteGuard)

local built, errors = Registry.build(All.content(Config))
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
				local data = DataService.get(shot.caster)
				local path = PathMarks.pathOf(shot.move)
				local boost, friction = PathMarks.hitMods(Config, data and data.marks, path)
				local amount = DamageMath.compute({ base = base or 0, rank = 1, boost = boost, friction = friction })
				if data then
					PathMarks.award(data, Config, path, 1) -- Path Marks by use (T-020b, D-089)
					shot.caster:SetAttribute("Marks", PathMarks.encode(data.marks)) -- Loom panel (T-020f, D-122)
				end
				humanoid:TakeDamage(amount)
				local victimModel = humanoid.Parent
				if victimModel and not game:GetService("Players"):GetPlayerFromCharacter(victimModel) then
					victimModel:SetAttribute("LastHitBy", shot.caster.UserId) -- kill credit (BeastService, T-022b)
				end
				BreakthroughService.onDamage(shot.caster, amount) -- trial cracks (T-018f)
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

-- Self delivery (T-015b): grant the onSelf effects' tags for their duration, then show the cast FX.
local function selfCast(player: Player, move: any, root: BasePart, dir: Vector3)
	local now = os.clock()
	if move.delivery.params and move.delivery.params.distance then
		SpeedGuardService.burst(player) -- Wind Step burst (D-166)
	end
	for _, effectId in move.effects.onSelf or {} do
		local effect: any = lookupEffect(effectId)
		if effect then
			for _, tag in effect.grantTags or {} do
				Status.grant(statuses, player, tag, now + (effect.seconds or 0))
			end
		end
	end
	if move.fx.cast then
		Net.CastFx.FireAll({ fxId = move.fx.cast, caster = player, pos = root.Position, dir = dir })
	end
end

-- Sweeps the projectile from `from` to `to` studs along its path; may hit several targets in one step.
local function sweep(shot: Shot, from: number, to: number)
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
			local victim = Players:GetPlayerFromCharacter(model)
			if victim and Status.blocksHit(statuses, victim, os.clock()) then
				continue -- warded or in i-frames
			end
			if Projectile.registerHit(shot.state, hitKey(model), p) then
				local amount = applyOnHit(shot, humanoid)
				Net.HitFx.FireAll({
					fxId = shot.move.fx.hit,
					caster = shot.caster,
					pos = result.Position,
					dir = shot.dir,
					target = model,
					amount = amount,
				})
			end
		else
			-- walls and scenery do not stop the projectile in the spike; skip them
			table.insert(exclude, result.Instance)
		end
	end
end

-- The server Qi pool for `player` (BindingService spends from it, T-017b).
function Abilities.pool(player: Player): Qi.Pool?
	return pools[player]
end

function Abilities.start()
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
		Status.clear(statuses, player)
	end)

	Net.CastRequest.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "CastRequest") then
			return
		end
		local rawMoveId, raw, rawSeq = value.moveId, value.aim, value.seq
		local pool = pools[player]
		local cds = cooldowns[player]
		local move = CastRequest.decode(rawMoveId, rawSeq, built.moves)
		if not pool or not cds or not move or typeof(raw) ~= "Vector3" then
			return
		end
		local data = DataService.get(player)
		if not data or not Loadout.canCast(data.loadout, data.kith, built, move.id) then
			return -- only moves of equipped Kith (T-016b, D-064)
		end
		move = Loom.wovenFor(Config, built, data.loadout.weaves, move.id) or move -- saved Weave (T-020c, D-090)
		local _, kithInst = KithCare.casterOf(data, move)
		local now = os.time()
		if kithInst then
			KithCare.ensure(kithInst, Config)
			if not KithCare.usable(kithInst, Config, now) then
				return -- Dormant or Exhausted Kith cannot cast (T-018b, D-074)
			end
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
			strainMax = math.huge, -- per-Kith Strain is charged below via KithCare (T-018b, D-074)
			hp = if humanoid then humanoid.Health else 0,
			cooldowns = cds,
		}
		if not Moves.pay(caster, move, os.clock()) then
			return
		end
		pool.current = caster.qi
		if kithInst then
			KithCare.addStrain(kithInst, Config, KithCare.moveStrain(Config, move), now)
		end
		UpkeepService.fought(player)
		publishQi(player, pool)
		local dir = Vector3.new(x, 0, z)
		if move.delivery.kind == "Self" then
			selfCast(player, move, root, dir)
			return
		end
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
				Net.CastFx.FireAll({ fxId = fxId, caster = player, pos = origin, dir = dir })
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
			sweep(shot, from, to)
			if shot.state.done then
				table.remove(shots, i)
			end
		end
	end)
end

return Abilities
