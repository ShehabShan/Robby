--!strict
-- Combat service (T-013b, D-050): thin server wiring for the pure `Combat` + `Rewind` modules.
-- Owns per-player chain/dash/parry/guard state, records every target's position at 20 Hz for 1 s and
-- checks melee hits at now − min(ping, 250 ms). Every hit passes sanity checks (alive, i-frames,
-- range + 4 studs, facing arc, line of sight); the Action remote is rate limited by a token bucket.
-- F: press → Parry (opens the parry window and raises the guard); release → Guard (lowers it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Rewind = require(ReplicatedStorage.Shared.Rewind)
local DamageMath = require(ReplicatedStorage.Shared.DamageMath)
local Net = require(script.Parent.Net) -- Blink-generated (net/remotes.blink)

local C = Config.Combat
local RECORD_DT = 1 / 20
local BUFFER_SECONDS = 1
local RANGE_SLACK = 4
local HIT_FX = "fx.crescent.hit" -- shared hit FX until HitFeel (T-014)

type State = {
	chain: Combat.Chain,
	dash: Combat.Dash,
	parry: Combat.Parry,
	guard: Combat.Guard,
	tokens: number,
	tokenAt: number,
	staggerUntil: number,
}

local states: { [Player]: State } = {}
local buffers: { [Model]: Rewind.Buffer } = {}

local CombatService = {}

local function stateFor(player: Player): State
	local s = states[player]
	if not s then
		s = {
			chain = Combat.newChain(),
			dash = Combat.newDash(),
			parry = Combat.newParry(),
			guard = Combat.newGuard(C.guard),
			tokens = C.rate.burst,
			tokenAt = os.clock(),
			staggerUntil = -math.huge,
		}
		states[player] = s
	end
	return s
end

-- Token bucket: `burst` actions at once, refilled at `perSecond`.
local function take(s: State, now: number): boolean
	s.tokens = math.min(C.rate.burst, s.tokens + (now - s.tokenAt) * C.rate.perSecond)
	s.tokenAt = now
	if s.tokens < 1 then
		return false
	end
	s.tokens -= 1
	return true
end

local function lerp(a: Vector3, b: Vector3, alpha: number): Vector3
	return a:Lerp(b, alpha)
end

local function aliveRoot(model: Model?): BasePart?
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function targets(): { Model }
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			table.insert(list, c)
		end
	end
	local dummy = workspace:FindFirstChild("TrainingDummy")
	if dummy and dummy:IsA("Model") then
		table.insert(list, dummy)
	end
	return list
end

local function stagger(s: State, now: number, seconds: number)
	s.staggerUntil = math.max(s.staggerUntil, now + seconds)
end

-- A finite, flattened, unit aim; falls back to where the character faces.
local function flatDir(raw: any, root: BasePart): Vector3
	if typeof(raw) == "Vector3" and raw.X == raw.X and raw.Z == raw.Z then
		local flat = Vector3.new(raw.X, 0, raw.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function attack(player: Player, s: State, rawDir: any, now: number)
	if now < s.staggerUntil then
		return
	end
	local character = player.Character
	local root = aliveRoot(character)
	if not root or not character then
		return
	end
	local step = Combat.press(s.chain, now, C.chain)
	if not step then
		return
	end
	local dir = flatDir(rawDir, root)
	local at = Rewind.checkTime(now, player:GetNetworkPing())
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	for _, model in targets() do
		local targetRoot = aliveRoot(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if model == character or not targetRoot or not humanoid then
			continue
		end
		local buf = buffers[model]
		local pos: Vector3 = (if buf then Rewind.at(buf, at, lerp) else nil) or targetRoot.Position
		local offset = pos - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if offset.Magnitude > C.chain.range + RANGE_SLACK then
			continue
		end
		if flat.Magnitude > 0.5 and flat.Unit:Dot(dir) < C.chain.arcDot then
			continue
		end
		local ray = workspace:Raycast(root.Position, offset, params)
		if ray and not ray.Instance:IsDescendantOf(model) then
			continue
		end
		local amount = DamageMath.compute({ base = C.chain.damage, rank = 1 })
		local victim = Players:GetPlayerFromCharacter(model)
		local vs = if victim then states[victim] else nil
		if vs then
			if Combat.invulnerable(vs.dash, now) then
				continue
			end
			if Combat.parries(vs.parry, now) then
				stagger(s, now, C.parry.stagger)
				continue
			end
			local outcome = Combat.hitGuard(vs.guard, amount, step == C.chain.steps)
			if outcome == "blocked" then
				continue
			elseif outcome == "broken" then
				stagger(vs, now, C.guard.breakStagger)
			end
		end
		humanoid:TakeDamage(amount)
		Net.HitFx.FireAll({ fxId = HIT_FX, caster = player, pos = pos, dir = dir, target = model, amount = amount })
	end
end

function CombatService.start()
	Net.Action.On(function(player: Player, value)
		local now = os.clock()
		local s = stateFor(player)
		if not take(s, now) then
			return
		end
		local kind = value.kind
		if kind == "Attack" then
			attack(player, s, value.dir, now)
		elseif kind == "Dash" then
			if now >= s.staggerUntil then
				Combat.dash(s.dash, now, C.dash)
			end
		elseif kind == "Parry" then
			Combat.parry(s.parry, now, C.parry)
			Combat.setGuard(s.guard, true)
		elseif kind == "Guard" then
			Combat.setGuard(s.guard, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		for _, s in states do
			if not s.guard.up then
				Combat.regenGuard(s.guard, dt, C.guard.regenPerSecond, C.guard)
			end
		end
		acc += dt
		if acc < RECORD_DT then
			return
		end
		acc = 0
		local now = os.clock()
		for model in buffers do
			if model.Parent == nil then
				buffers[model] = nil
			end
		end
		for _, model in targets() do
			local root = aliveRoot(model)
			if root then
				local buf = buffers[model] or Rewind.new(BUFFER_SECONDS)
				buffers[model] = buf
				Rewind.record(buf, now, root.Position)
			end
		end
	end)
end

return CombatService
