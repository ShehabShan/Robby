--!strict
-- Ability server authority (ARCHITECTURE v2 §3, SCHEMAS §5, T-002c3): one CastRequest path driven by Content data.
-- Registry (validated Content) → Moves (costs, cooldown per (caster, moveId)) → Deliveries/Projectile (travel, pierce)
-- → Effects (onHit) → DamageMath. Remotes are Blink-generated (Net.luau, T-011); CastFx/HitFx carry Content fx ids.
-- The server never trusts the client: aim is validated, Qi, cooldown and alive state are server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Qi = require(ReplicatedStorage.Shared.Qi)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Effects = require(ReplicatedStorage.Shared.Effects)
local Moves = require(ReplicatedStorage.Shared.Moves)
local CastTransaction = require(ReplicatedStorage.Shared.CastTransaction)
local CastAdmission = require(ReplicatedStorage.Shared.CastAdmission)
local CastCharacterIdentity = require(ReplicatedStorage.Shared.CastCharacterIdentity)
local CastLedger = require(ReplicatedStorage.Shared.CastLedger)
local CastReceipts = require(ReplicatedStorage.Shared.CastReceipts)
local CastSchedule = require(ReplicatedStorage.Shared.CastSchedule)
local CastGeometry = require(ReplicatedStorage.Shared.CastGeometry)
local CastLifetime = require(ReplicatedStorage.Shared.CastLifetime)
local CastContacts = require(ReplicatedStorage.Shared.CastContacts)
local Registry = require(ReplicatedStorage.Shared.Registry)
local DamageMath = require(ReplicatedStorage.Shared.DamageMath)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)
local Volley = require(ReplicatedStorage.Shared.Deliveries.Volley)
local Zone = require(ReplicatedStorage.Shared.Deliveries.Zone)
local Burst = require(ReplicatedStorage.Shared.Deliveries.Burst)
local Frost = require(ReplicatedStorage.Shared.Frost)
local Stance = require(ReplicatedStorage.Shared.Stance)
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
	lifetime: CastLifetime.Handle,
	resource: number,
	caster: Player,
	character: Model,
	origin: Vector3,
	dir: Vector3,
	move: any,
	state: Projectile.State,
	register: (targetId: string) -> boolean, -- Projectile or Volley hit rules (per-target cap), T-027d2
}
type ZoneCast = {
	caster: Player,
	character: Model,
	center: Vector3,
	move: any,
	state: Zone.State,
	lifetime: CastLifetime.Handle,
}

local Abilities = {}

local pools: { [Player]: Qi.Pool } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local shots: { Shot } = {}
local zones: { ZoneCast } = {}
local lifetimes = CastLifetime.new(Config.CastLifetime.capacity)
local stances: { [Player]: Stance.State } = {}
-- One Effects holder per hit model (Chill stacks live here, T-027d2, D-187); weak keys drop dead models.
local holders: { [Instance]: Effects.Holder } = setmetatable({}, { __mode = "k" }) :: any
local function holderFor(model: Instance): Effects.Holder
	local h = holders[model]
	if h == nil then
		h = Effects.newHolder()
		holders[model] = h
	end
	return h
end
local STAGGER_TAG = "State.Staggered" -- granted by Shatter on a Rimed target (D-188); readers: CombatService/BeastBrain (T-027d3)
local DEFAULT_HITBOX = Config.Abilities.Rimeshard.needle.hitboxSize -- Volley shards carry no hitbox of their own
local GROUND_PROBE = 50 -- studs above/below the aimed Zone point searched for ground

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

-- Runs the move's onHit effects on the target's holder (Chill stacks persist per model); returns the damage dealt.
-- Ops: Dmg (flat), DmgPerStack (Shatter: Frost.consume reads and spends the Chill), Stagger (Rimed targets only).
local function applyOnHit(caster: Player, move: any, humanoid: Humanoid): number
	local total = 0
	local victimModel = humanoid.Parent
	local holder = if victimModel then holderFor(victimModel) else Effects.newHolder()
	local now = os.clock()
	local lastShatter: any = nil
	local function deal(base: number)
		local data = DataService.get(caster)
		local path = PathMarks.pathOf(move)
		local boost, friction = PathMarks.hitMods(Config, data and data.marks, path)
		local amount = DamageMath.compute({ base = base, rank = 1, boost = boost, friction = friction })
		if data then
			PathMarks.award(data, Config, path, 1) -- Path Marks by use (T-020b, D-089)
			caster:SetAttribute("Marks", PathMarks.encode(data.marks)) -- Loom panel (T-020f, D-122)
		end
		humanoid:TakeDamage(amount)
		if victimModel and not Players:GetPlayerFromCharacter(victimModel) then
			victimModel:SetAttribute("LastHitBy", caster.UserId) -- kill credit (BeastService, T-022b)
		end
		BreakthroughService.onDamage(caster, amount) -- trial cracks (T-018f)
		total += amount
	end
	local ctx: Effects.Ctx
	ctx = {
		now = now,
		tags = Tags,
		onOp = function(op: Effects.Op)
			local p: { [string]: any } = op.params or {}
			if op.kind == "Dmg" then
				deal(p.base or 0)
			elseif op.kind == "DmgPerStack" then
				local rime = Config.Abilities.Rimeshard
				lastShatter = Frost.consume(holder, lookupEffect, ctx, rime.chill, {
					base = p.base or 0,
					perStack = p.perStack or 0,
					staggerSeconds = rime.shatter.staggerSeconds,
				})
				if lastShatter.damage > 0 then
					deal(lastShatter.damage)
				end
			elseif op.kind == "Stagger" then
				local rimed = if lastShatter then lastShatter.stagger > 0 else false
				if p.requireTag == nil or rimed or Tags.hasAll(holder.tags, { p.requireTag }) then
					Status.grant(statuses, victimModel or humanoid, STAGGER_TAG, now + (p.seconds or 0))
				end
			end
		end,
	}
	for _, effectId in move.effects.onHit or {} do
		local effect = lookupEffect(effectId)
		if effect then
			Effects.apply(holder, effect, caster.Name, ctx)
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

-- Confirmed contacts are post-effect notifications, never damage admission or replay.
local contactLedgers: { [CastLifetime.Handle]: CastContacts.State } = {}
local function startContactLedger(handle: CastLifetime.Handle)
	contactLedgers[handle] = CastContacts.new(
		handle.acceptance.castId,
		handle.resources,
		handle.acceptance.acceptedAt,
		Config.CastContact.capacity
	)
end
local function confirmedContact(
	handle: CastLifetime.Handle,
	resource: number,
	tick: number,
	target: Instance?,
	pos: Vector3,
	dir: Vector3,
	amount: number
)
	local ledger = contactLedgers[handle]
	if not ledger or not target then
		return
	end
	local status, contact = CastContacts.record(ledger, {
		resource = resource,
		tick = tick,
		targetKey = hitKey(target),
		at = handle.acceptance.acceptedAt + os.clock() - handle.startedAt,
		position = { x = pos.X, y = pos.Y, z = pos.Z },
		direction = { x = dir.X, y = dir.Y, z = dir.Z },
		amount = amount,
	})
	if status == "stored" and contact then
		Net.CastContact.FireAll(table.freeze({
			castId = contact.castId,
			ordinal = contact.ordinal,
			resource = contact.resource,
			tick = contact.tick,
			targetKey = contact.targetKey,
			at = contact.at,
			amount = contact.amount,
			position = Vector3.new(contact.position.x, contact.position.y, contact.position.z),
			direction = Vector3.new(contact.direction.x, contact.direction.y, contact.direction.z),
		}))
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
	local hb = p.hitbox or DEFAULT_HITBOX
	local size = Vector3.new(hb.x, hb.y, hb.z)
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
			if shot.register(hitKey(model)) then
				local amount = applyOnHit(shot.caster, shot.move, humanoid)
				confirmedContact(shot.lifetime, shot.resource, 1, model, result.Position, shot.dir, amount)
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

local function fireCast(move: any, player: Player, pos: Vector3, dir: Vector3)
	for _, slot in { "cast", "travel" } do
		local fxId = move.fx[slot]
		if fxId then
			Net.CastFx.FireAll({ fxId = fxId, caster = player, pos = pos, dir = dir })
		end
	end
end

local function hitFx(move: any, caster: Player, pos: Vector3, dir: Vector3, target: Instance?, amount: number)
	local model: Model? = if target and target:IsA("Model") then target else nil
	Net.HitFx.FireAll({ fxId = move.fx.hit, caster = caster, pos = pos, dir = dir, target = model, amount = amount })
end

local function pushShot(
	player: Player,
	character: Model,
	move: any,
	origin: Vector3,
	dir: Vector3,
	lifetime: CastLifetime.Handle
)
	local state = Projectile.new()
	table.insert(shots, {
		lifetime = lifetime,
		resource = 1,
		caster = player,
		character = character,
		origin = origin,
		dir = dir,
		move = move,
		state = state,
		register = function(key: string): boolean
			return Projectile.registerHit(state, key, move.delivery.params)
		end,
	})
end

-- Volley (Shard Fan, Needle finisher): one Shot per shard, all sharing the volley's per-target cap (T-027d2).
local function volleyCast(
	player: Player,
	character: Model,
	move: any,
	origin: Vector3,
	dir: Vector3,
	lifetime: CastLifetime.Handle
)
	local p = move.delivery.params
	local vstate = Volley.new(p)
	for i, d in Volley.directions(dir.X, dir.Z, p) do
		table.insert(shots, {
			lifetime = lifetime,
			resource = i,
			caster = player,
			character = character,
			origin = origin,
			dir = Vector3.new(d.x, 0, d.z),
			move = move,
			state = vstate.shards[i],
			register = function(key: string): boolean
				return Volley.registerHit(vstate, i, key, p)
			end,
		})
	end
	fireCast(move, player, origin, dir)
end

-- Zone (Rime Fall): the validated aim point snapped to the ground; ticks run from the heartbeat.
local function groundCentre(character: Model, point: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(point + Vector3.new(0, GROUND_PROBE, 0), Vector3.new(0, -2 * GROUND_PROBE, 0), params)
	return if hit then hit.Position else point
end

-- Geometry and monotonic start are captured once by authorization.
local function zoneCast(
	player: Player,
	character: Model,
	move: any,
	center: Vector3,
	dir: Vector3,
	startedAt: number,
	lifetime: CastLifetime.Handle
)
	table.insert(zones, {
		caster = player,
		character = character,
		center = center,
		move = move,
		state = Zone.new(startedAt),
		lifetime = lifetime,
	})
	fireCast(move, player, center, dir)
end

-- Live humanoids whose root stands inside the zone circle, once per model.
local function humanoidsInZone(z: ZoneCast, p: Zone.Params): { Humanoid }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { z.character }
	local seen: { [Instance]: boolean } = {}
	local out: { Humanoid } = {}
	for _, part in workspace:GetPartBoundsInRadius(z.center, p.radius + 5, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] then
			seen[model] = true
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				if Zone.contains(root.Position.X, root.Position.Z, z.center.X, z.center.Z, p) then
					table.insert(out, humanoid)
				end
			end
		end
	end
	return out
end

local function tickZone(z: ZoneCast, now: number)
	local p = z.move.delivery.params
	local due = Zone.step(z.state, now, p)
	for tick = z.state.fired - due + 1, z.state.fired do
		for _, humanoid in humanoidsInZone(z, p) do
			local model = humanoid.Parent
			local victim = if model then Players:GetPlayerFromCharacter(model) else nil
			if victim and Status.blocksHit(statuses, victim, now) then
				continue
			end
			local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
			local pos = if root and root:IsA("BasePart") then root.Position else z.center
			local amount = applyOnHit(z.caster, z.move, humanoid)
			confirmedContact(z.lifetime, 1, tick, model, pos, Vector3.yAxis, amount)
			hitFx(z.move, z.caster, pos, Vector3.yAxis, model, amount)
		end
	end
end

-- Burst (Shatter): after the clap wind-up, the Chilled models in radius, nearest first (Burst.select);
-- candidates come from the holders table, so only targets that still carry Chill are ever considered.
local function burstCast(player: Player, character: Model, move: any, dir: Vector3, lifetime: CastLifetime.Handle)
	local p = move.delivery.params
	local root = aliveRoot(character)
	if root then
		fireCast(move, player, root.Position, dir)
	end
	task.delay(move.telegraph or 0, function()
		if not CastLifetime.isActive(lifetimes, lifetime) then
			return
		end
		-- task.delay can resume before the heartbeat reaper after a scheduler stall.
		if os.clock() >= lifetime.deadline then
			CastLifetime.terminate(lifetimes, lifetime, "expired", os.clock())
			return
		end
		local castRoot = if player.Parent == Players and player.Character == character
			then aliveRoot(character)
			else nil
		if not castRoot then
			CastLifetime.terminate(lifetimes, lifetime, "caster_lost", os.clock())
			return -- never bind an accepted wind-up to a replacement character
		end
		local candidates: { Burst.Candidate } = {}
		local byId: { [string]: Humanoid } = {}
		for model, holder in holders do
			if model == character or model.Parent == nil then
				continue
			end
			local stacks = Frost.stacks(holder)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local mroot = model:FindFirstChild("HumanoidRootPart")
			if stacks > 0 and humanoid and humanoid.Health > 0 and mroot and mroot:IsA("BasePart") then
				local id = hitKey(model)
				byId[id] = humanoid
				table.insert(candidates, { id = id, x = mroot.Position.X, z = mroot.Position.Z, marks = stacks })
			end
		end
		local now = os.clock()
		for _, c in Burst.select(castRoot.Position.X, castRoot.Position.Z, candidates, p) do
			local humanoid = byId[c.id]
			local model = humanoid.Parent
			local victim = if model then Players:GetPlayerFromCharacter(model) else nil
			if victim and Status.blocksHit(statuses, victim, now) then
				continue
			end
			local pos = Vector3.new(c.x, castRoot.Position.Y, c.z)
			local amount = applyOnHit(player, move, humanoid)
			confirmedContact(lifetime, 1, 1, model, pos, dir, amount)
			hitFx(move, player, pos, dir, model, amount)
		end
		CastLifetime.finish(lifetimes, lifetime, 1, os.clock())
	end)
end

-- The Kith's Kit and stance timing (chain move + `_finisher`), or nil for Kith without a left-click chain.
local function kitFor(move: any): (Stance.Kit?, Stance.Cfg?)
	local kith = if move.kith then built.kith[move.kith] else nil
	local kit = if kith then Stance.kit(kith, built.moves) else nil
	if not kit then
		return nil, nil
	end
	local chain = built.moves[kit.chain]
	local fin = built.moves[kit.finisher]
	return kit, { chain = chain.chain, finisherRecovery = if fin then fin.cooldown else chain.chain.recovery }
end

local function stanceFor(player: Player): Stance.State
	local st = stances[player]
	if st == nil then
		st = Stance.new()
		stances[player] = st
	end
	return st
end

-- Kith stance toggle (T-027d2, Action kind "Stance", D-186): the server mirrors the client's left-click swap.
function Abilities.toggleStance(player: Player): boolean
	local on = Stance.toggle(stanceFor(player))
	player:SetAttribute("Stance", on)
	return on
end

-- The server Qi pool for `player` (BindingService spends from it, T-017b).
function Abilities.pool(player: Player): Qi.Pool?
	return pools[player]
end

-- T-043c0b3b2a: explicit synchronous authorization seam for replay admission.
-- Captures one delivery and paired clocks; the caller stores an immutable receipt.
type AcceptedCast = {
	player: Player,
	character: Model,
	root: BasePart,
	move: any,
	pool: Qi.Pool,
	dir: Vector3,
	point: Vector3?,
	origin: Vector3,
	monotonicAt: number,
	acceptedAt: number,
	schedule: CastSchedule.Offsets,
	geometry: CastGeometry.Snapshot,
}
local function authorizeCast(player: Player, value: any): (AcceptedCast?, string?)
	local rawMoveId, raw, rawSeq = value.moveId, value.aim, value.seq
	local pool = pools[player]
	local cds = cooldowns[player]
	local move = CastRequest.decode(rawMoveId, rawSeq, built.moves)
	if not pool or not cds then
		return nil, "not_ready"
	end
	if not move or typeof(raw) ~= "Vector3" then
		return nil, "invalid_request"
	end
	local data = DataService.get(player)
	local slot = tonumber(player:GetAttribute("ActiveSlot")) or 1
	if not data or not Loadout.canCastLive(data.loadout, data.kith, built, Config, slot, move.id) then
		return nil, "loadout" -- only the selected slot's Kith (+ fixed moves) may cast (T-036a, D-216)
	end
	move = Loom.wovenFor(Config, built, data.loadout.weaves, move.id) or move -- saved Weave (T-020c, D-090)
	local _, kithInst = KithCare.casterOf(data, move)
	local now = os.time()
	if kithInst then
		KithCare.ensure(kithInst, Config)
		if not KithCare.usable(kithInst, Config, now) then
			return nil, "unusable" -- Dormant or Exhausted Kith cannot cast (T-018b, D-074)
		end
	end
	local v = raw :: Vector3
	if not Projectile.isValidDirection(v.X, v.Y, v.Z) then
		return nil, "aim"
	end
	local x, z, okFlat = Projectile.flatten(v.X, v.Z)
	local character = player.Character
	local root = aliveRoot(character)
	if not okFlat then
		return nil, "aim"
	end
	if not root or not character then
		return nil, "character"
	end
	local point: Vector3? = nil
	if move.delivery.kind == "Zone" then
		local rawPoint = value.point
		if typeof(rawPoint) ~= "Vector3" then
			return nil, "point"
		end
		local rp = root.Position
		if not Zone.isValidPoint(rp.X, rp.Z, rawPoint.X, rawPoint.Z, move.delivery.params) then
			return nil, "point" -- out of range or not finite (T-027b)
		end
		point = groundCentre(character, rawPoint) -- legacy fallback; hardening belongs to T-043c3
	end
	local schedule = CastSchedule.offsets(move, built.effects, Config.CastReceipt.maxLifetimeSeconds)
	if not schedule then
		return nil, "schedule"
	end
	local geometry = CastGeometry.capture(move, DEFAULT_HITBOX)
	if not geometry then
		return nil, "geometry"
	end
	local kit, stanceCfg = kitFor(move)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local caster: Moves.Caster = {
		qi = pool.current,
		strain = 0,
		strainMax = math.huge, -- per-Kith Strain is charged below via KithCare (T-018b, D-074)
		hp = if humanoid then humanoid.Health else 0,
		cooldowns = cds,
	}
	-- Capture engine-facing values before committing payment. No effects, scheduling,
	-- attribute publication or remote sends occur inside authorization.
	local dir = Vector3.new(x, 0, z)
	local accepted: AcceptedCast = {
		player = player,
		character = character,
		root = root,
		move = move,
		pool = pool,
		dir = dir,
		point = point,
		origin = if move.delivery.kind == "Self" or move.delivery.kind == "Burst"
			then root.Position
			else root.Position + dir * (move.delivery.params.spawnOffset or 0) + CHEST,
		monotonicAt = 0,
		acceptedAt = 0,
		schedule = schedule,
		geometry = geometry,
	}
	if not CastLifetime.hasRoom(lifetimes) then
		return nil, "delivery_capacity"
	end
	local strain = if kithInst then KithCare.moveStrain(Config, move) else 0
	local paid, reason =
		CastTransaction.pay(if kit then stanceFor(player) else nil, stanceCfg, kit, caster, move, os.clock())
	if not paid then
		return nil, reason or "payment"
	end
	pool.current = caster.qi
	if kithInst then
		KithCare.addStrain(kithInst, Config, strain, now)
	end
	-- No yield separates successful payment, these two clock reads and receipt capture.
	accepted.monotonicAt = os.clock()
	accepted.acceptedAt = workspace:GetServerTimeNow()
	return accepted, nil
end

-- Invoke only once for a fresh acceptance, OUTSIDE the admission transaction.
local function deliverCast(accepted: AcceptedCast, lifetime: CastLifetime.Handle)
	local player, character, root, move = accepted.player, accepted.character, accepted.root, accepted.move
	local dir = accepted.dir
	UpkeepService.fought(player)
	publishQi(player, accepted.pool)
	local kind = move.delivery.kind
	if kind == "Self" then
		selfCast(player, move, root, dir)
		task.delay(accepted.schedule.finish, function()
			CastLifetime.finish(lifetimes, lifetime, 1, os.clock())
		end)
	elseif kind == "Burst" then
		burstCast(player, character, move, dir, lifetime)
	elseif kind == "Zone" then
		zoneCast(player, character, move, accepted.point :: Vector3, dir, accepted.monotonicAt, lifetime)
	elseif kind == "Volley" then
		volleyCast(player, character, move, accepted.origin, dir, lifetime)
	else
		pushShot(player, character, move, accepted.origin, dir, lifetime)
		fireCast(move, player, accepted.origin, dir)
	end
end

type CastSession = {
	admission: CastAdmission.State,
	receipts: CastReceipts.State,
	character: Model?,
	characterKey: string,
	slotRevision: number,
	connections: { RBXScriptConnection },
}
local castSessions: { [Player]: CastSession } = {}
-- Completed world records survive player departure; eviction never grants admission.
local terminalReceipts = CastReceipts.new(Config.CastTerminal)
local function publishCastIdentity(player: Player, session: CastSession)
	local character = session.character
	if character then
		character:SetAttribute(
			CastCharacterIdentity.attribute,
			if not session.admission.closed and character == player.Character
				then CastCharacterIdentity.encode({
					generation = session.admission.ledger.generation,
					characterKey = session.characterKey,
					slotRevision = session.slotRevision,
					casterUserId = player.UserId,
				})
				else nil
		)
	end
end
local function syncCast(player: Player, session: CastSession)
	publishCastIdentity(player, session)
	Net.CastGeneration.Fire(player, {
		generation = session.admission.ledger.generation,
		epoch = session.admission.epoch,
		character = if session.admission.closed then nil else session.character,
	})
end
-- Epoch exhaustion must fail closed; never reuse a character generation.
local function rotateCast(session: CastSession)
	if not CastAdmission.rotate(session.admission) then
		CastAdmission.destroy(session.admission)
	end
end
local function castVector(v: Vector3): CastAdmission.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

-- One immutable acceptance representation for fresh broadcasts and duplicate replies.
local function sendAcceptance(player: Player, a: CastReceipts.Acceptance, broadcast: boolean)
	local value = {
		castId = a.castId,
		generation = a.generation,
		seq = a.seq,
		moveId = a.moveId,
		casterUserId = a.casterUserId,
		characterKey = a.characterKey,
		slotRevision = a.slotRevision,
		acceptedAt = a.acceptedAt,
		releaseAt = a.releaseAt,
		endsAt = a.endsAt,
		geometry = a.geometry,
		aim = Vector3.new(a.aim.x, a.aim.y, a.aim.z),
		origin = Vector3.new(a.origin.x, a.origin.y, a.origin.z),
		centre = if a.centre then Vector3.new(a.centre.x, a.centre.y, a.centre.z) else nil,
	}
	if broadcast then
		Net.CastAccepted.FireAll(value)
	else
		Net.CastAccepted.Fire(player, value)
	end
end
local function sendTerminal(player: Player?, key: string, terminal: CastReceipts.Terminal)
	local value = { castId = key, reason = terminal.reason, at = terminal.at }
	if player then
		Net.CastTerminal.Fire(player, value)
	else
		Net.CastTerminal.FireAll(value)
	end
end
local function recordTerminal(handle: CastLifetime.Handle, now: number)
	local a, terminal = handle.acceptance, handle.terminal
	if not terminal then
		return
	end
	local ledger = contactLedgers[handle]
	if ledger then
		CastContacts.close(ledger)
		contactLedgers[handle] = nil
	end
	CastReceipts.put(terminalReceipts, a, now)
	CastReceipts.terminate(terminalReceipts, a.castId, terminal.reason, terminal.at, now)
	-- Keep owner replay terminal even if the bounded world cache churns.
	for player, session in castSessions do
		if player.UserId == a.casterUserId then
			CastReceipts.put(session.receipts, a, now)
			CastReceipts.terminate(session.receipts, a.castId, terminal.reason, terminal.at, now)
			break
		end
	end
	sendTerminal(nil, a.castId, terminal)
end
local function sendDisposition(player: Player, value: any, status: string, reason: string)
	Net.CastDisposition.Fire(player, {
		generation = value.generation,
		seq = value.seq,
		moveId = value.moveId,
		status = status,
		reason = reason,
	})
end

function Abilities.start()
	lifetimes.onTerminal = recordTerminal
	local function join(player: Player)
		local session: CastSession = {
			admission = CastAdmission.new(HttpService:GenerateGUID(false), Config.CastProtocol),
			receipts = CastReceipts.new(Config.CastReceipt),
			character = nil,
			characterKey = "",
			slotRevision = 0,
			connections = {},
		}
		castSessions[player] = session
		local pool = Qi.new(Config.Qi.max, Config.Qi.regen)
		pools[player] = pool
		cooldowns[player] = {}
		player:SetAttribute("QiMax", pool.max)
		publishQi(player, pool)
		-- Stance follows the selected slot (T-036a, D-216): on while the live Kith has a chain; mirrors KithInput.
		local function followSlot()
			local id = player:GetAttribute("ActiveKith")
			local kith = if typeof(id) == "string" then built.kith[id] else nil
			local on = Stance.set(stanceFor(player), kith ~= nil and Stance.kit(kith, built.moves) ~= nil)
			player:SetAttribute("Stance", on)
		end
		table.insert(session.connections, player:GetAttributeChangedSignal("ActiveKith"):Connect(followSlot))
		table.insert(
			session.connections,
			player:GetAttributeChangedSignal("ActiveSlot"):Connect(function()
				-- Every change, even away-and-back, invalidates a future pending-slot token.
				if session.slotRevision >= 4294967295 then
					CastAdmission.destroy(session.admission)
				else
					session.slotRevision += 1
				end
				publishCastIdentity(player, session)
			end)
		)
		local function characterAdded(character: Model)
			if session.character == character then
				return
			end
			if session.character then
				session.character:SetAttribute(CastCharacterIdentity.attribute, nil)
			end
			session.character = character
			session.characterKey = HttpService:GenerateGUID(false)
			rotateCast(session)
			stances[player] = Stance.new()
			followSlot()
			syncCast(player, session)
		end
		table.insert(session.connections, player.CharacterAdded:Connect(characterAdded))
		table.insert(
			session.connections,
			player.CharacterRemoving:Connect(function(character: Model)
				if session.character ~= character then
					return
				end
				character:SetAttribute(CastCharacterIdentity.attribute, nil)
				session.character = nil
				rotateCast(session)
				stances[player] = Stance.new()
				syncCast(player, session)
			end)
		)
		followSlot()
		if player.Character then
			characterAdded(player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, p in Players:GetPlayers() do
		join(p)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local session = castSessions[player]
		if session then
			CastAdmission.destroy(session.admission)
			publishCastIdentity(player, session)
			CastReceipts.destroy(session.receipts)
			for _, connection in session.connections do
				connection:Disconnect()
			end
			castSessions[player] = nil
		end
		pools[player] = nil
		cooldowns[player] = nil
		stances[player] = nil
		Status.clear(statuses, player)
	end)

	Net.CastSync.On(function(player: Player)
		local session = castSessions[player]
		if session and RemoteGuard.allow(player, "CastSync") then
			syncCast(player, session)
		end
	end)
	Net.CastRequest.On(function(player: Player, value)
		if not RemoteGuard.allow(player, "CastRequest") then
			return
		end
		local session = castSessions[player]
		if not session then
			return
		end
		if session.character == nil or session.character ~= player.Character then
			sendDisposition(player, value, "rejected", "character")
			syncCast(player, session)
			return
		end
		local accepted: AcceptedCast? = nil
		local lifetime: CastLifetime.Handle? = nil
		local result = CastAdmission.dispatch(
			session.admission,
			{
				generation = value.generation,
				seq = value.seq,
				moveId = value.moveId,
				aim = castVector(value.aim),
				point = if value.point then castVector(value.point) else nil,
			},
			os.clock(),
			function(request, castId)
				local context, reason = authorizeCast(player, {
					moveId = request.moveId,
					seq = request.seq,
					aim = Vector3.new(request.aim.x, request.aim.y, request.aim.z),
					point = if request.point
						then Vector3.new(request.point.x, request.point.y, request.point.z)
						else nil,
				})
				if context then
					local a = context
					local receipt: CastReceipts.Acceptance = {
						castId = castId,
						generation = request.generation,
						seq = request.seq,
						moveId = a.move.id,
						casterUserId = player.UserId,
						characterKey = session.characterKey,
						slotRevision = session.slotRevision,
						acceptedAt = a.acceptedAt,
						releaseAt = a.acceptedAt + a.schedule.release,
						endsAt = a.acceptedAt + a.schedule.finish,
						geometry = a.geometry,
						aim = castVector(a.dir),
						origin = castVector(a.origin),
						centre = if a.point then castVector(a.point) else nil,
					}
					local stored = CastReceipts.put(session.receipts, receipt, a.monotonicAt)
					local handle = CastLifetime.start(
						lifetimes,
						receipt,
						a.monotonicAt,
						if a.move.delivery.kind == "Volley" then a.move.delivery.params.count else 1,
						Config.CastLifetime.graceSeconds
					)
					lifetime = handle
					startContactLedger(handle)
					if stored ~= "stored" then
						warn("Paid cast receipt unavailable: " .. stored) -- never suppress paid delivery or re-pay
					end
				end
				accepted = context
				return context ~= nil, reason
			end
		)
		if result.receipt and result.receipt.reason == "internal_error" then
			warn("Cast authorization internal_error")
		end
		if result.receipt and result.receipt.status == "accepted" then
			local key = result.receipt.castId :: string
			local entry = CastReceipts.get(terminalReceipts, key, os.clock())
				or CastReceipts.get(session.receipts, key, os.clock())
			if entry and entry.acceptance then
				sendAcceptance(player, entry.acceptance, result.kind == "completed")
				if entry.terminal then
					sendTerminal(player, key, entry.terminal)
				end
			else
				sendDisposition(player, value, "expired", "receipt_expired")
			end
		elseif result.reason ~= "malformed" then
			local reason = if result.receipt then result.receipt.reason else result.reason
			sendDisposition(player, value, "rejected", reason or result.kind)
		end
		-- Duplicate dispositions never populate accepted; no payment or delivery replay.
		if
			result.kind == "completed"
			and result.receipt
			and result.receipt.status == "accepted"
			and accepted
			and lifetime
		then
			deliverCast(accepted, lifetime)
		end
		if result.renew then
			rotateCast(session)
		end
		if result.renew or result.reason == "generation" then
			syncCast(player, session)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		for player, pool in pools do
			Qi.regen(pool, dt)
			publishQi(player, pool)
		end
		local now = os.clock()
		for _, session in castSessions do
			CastLedger.prune(session.admission.ledger, now)
			CastReceipts.prune(session.receipts, now)
		end
		for i = #zones, 1, -1 do
			local z = zones[i]
			if CastLifetime.isActive(lifetimes, z.lifetime) then
				tickZone(z, now)
			else
				z.state.done = true
			end
			if z.state.done then
				CastLifetime.finish(lifetimes, z.lifetime, 1, now)
				table.remove(zones, i)
			end
		end
		for _, holder in holders do
			if #holder.active > 0 then
				Effects.tick(holder, lookupEffect, { now = now, tags = Tags }) -- Chill expiry (T-027a)
			end
		end
		for i = #shots, 1, -1 do
			local shot = shots[i]
			if CastLifetime.isActive(lifetimes, shot.lifetime) then
				local from, to = Projectile.step(shot.state, dt, shot.move.delivery.params)
				sweep(shot, from, to)
			else
				shot.state.done = true
			end
			if shot.state.done then
				CastLifetime.finish(lifetimes, shot.lifetime, shot.resource, now)
				table.remove(shots, i)
			end
		end
		CastLifetime.expire(lifetimes, now)
		CastReceipts.prune(terminalReceipts, now)
	end)
end

return Abilities
