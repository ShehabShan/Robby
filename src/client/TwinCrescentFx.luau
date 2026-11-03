--!strict
-- Twin Crescent "Scissor" FX (T-053b, D-397): a blue blade from the caster's left and a gold blade from the right
-- curve inward on the shared Scissor path (the same pure path the server sweeps), cross in a white X flash at
-- `crossAt`, then fly on and dissolve. The cast swipe and hit feel reuse Crescent Cut's (CrescentFx).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Scissor = require(ReplicatedStorage.Shared.Deliveries.Scissor)
local Ring = require(ReplicatedStorage.Shared.Deliveries.Ring)
local CrescentFx = require(script.Parent.CrescentFx)

local cfg = Config.Abilities.TwinCrescent
local look = Config.Fx.TwinCrescent
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local ARC = math.rad(120)
local WHITE = Color3.new(1, 1, 1)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local COLORS = { [-1] = rgb(look.blue), [0] = rgb(look.third.color), [1] = rgb(look.gold) } -- 0 = 3rd blade (T-056c)
local CORES = { [-1] = rgb(look.blueCore), [0] = rgb(look.third.core), [1] = rgb(look.goldCore) }

local TwinCrescentFx = {}

local live = 0

local function lowGraphics(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and type(level) == "number" and level > 0 and level <= 3
end

local function fxPart(size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	return p
end

local function soundAt(id: string?, pos: Vector3, volume: number, speed: number)
	if not id then
		return
	end
	local at = Instance.new("Attachment")
	at.WorldPosition = pos
	at.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.Parent = at
	s:Play()
	Debris:AddItem(at, 3)
end

type Blade = { model: Model, beams: { Beam }, cores: { BasePart }, light: PointLight, sparks: ParticleEmitter? }

-- One blade: textured Beam (Crescent art tinted to the blade colour) over a thin neon arc; trail and light in colour.
local function buildBlade(side: number): Blade
	local color, core = COLORS[side], CORES[side]
	local model = Instance.new("Model")
	model.Name = if side < 0 then "TwinCrescentBlue" elseif side == 0 then "TwinCrescentThird" else "TwinCrescentGold"
	local pivot = fxPart(Vector3.new(0.2, 0.2, 0.2), color)
	pivot.Transparency = 1
	pivot.Parent = model
	model.PrimaryPart = pivot
	local beams: { Beam } = {}
	-- Per-blade owner art (T-057a, D-412/D-413): blue left, gold right, third2 for the 3rd blade.
	local art = if side < 0 then "crescentBlueAdd" elseif side == 0 then "crescentThirdAdd" else "crescentGoldAdd"
	local texture = AssetIds.image(art) or AssetIds.image("crescentSlashAdd")
	if texture then
		local back = Instance.new("Attachment")
		back.CFrame = CFrame.new(0, 0, look.bladeDepth / 2) * CFrame.Angles(0, 0, math.rad(90))
		back.Parent = pivot
		local front = Instance.new("Attachment")
		front.CFrame = CFrame.new(0, 0, -look.bladeDepth / 2) * CFrame.Angles(0, 0, math.rad(90))
		front.Parent = pivot
		local beam = Instance.new("Beam")
		beam.Attachment0 = back
		beam.Attachment1 = front
		beam.Texture = texture
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.TextureSpeed = 0
		beam.FaceCamera = false
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(color)
		beam.Parent = pivot
		table.insert(beams, beam)
	end
	local cores: { BasePart } = {}
	local r = look.bladeWidth / 2
	local tips: { Attachment } = {}
	for i = 1, 5 do
		local a = -ARC / 2 + ARC * (i - 1) / 4
		local seg = fxPart(Vector3.new(look.bladeWidth * 0.22, 0.08, 0.14), core)
		seg.Name = "Core"
		seg.CFrame = CFrame.new(math.sin(a) * r, 0, r * (1 - math.cos(a)) * 0.6) * CFrame.Angles(0, -a, 0)
		seg.Parent = model
		table.insert(cores, seg)
		if i == 1 or i == 5 then
			local tip = Instance.new("Attachment")
			tip.Parent = seg
			table.insert(tips, tip)
		end
	end
	local trail = Instance.new("Trail")
	trail.Attachment0 = tips[1]
	trail.Attachment1 = tips[2]
	trail.Color = ColorSequence.new(color, WHITE)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = look.trailLife
	trail.LightEmission = 1
	trail.Parent = pivot
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = look.lightBrightness
	light.Range = 10
	light.Parent = pivot
	local sparks: ParticleEmitter? = nil
	if not lowGraphics() then
		local e = Instance.new("ParticleEmitter")
		e.Texture = AssetIds.image("crescentSlashAlpha") or SPARK_TEXTURE
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Rate = look.sparkRate
		e.Lifetime = NumberRange.new(0.2, 0.4)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Size = NumberSequence.new(0.3, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = pivot
		sparks = e
	end
	return { model = model, beams = beams, cores = cores, light = light, sparks = sparks }
end

local function setBlade(b: Blade, scale: number, vis: number)
	for _, beam in b.beams do
		beam.Width0 = look.bladeWidth * scale
		beam.Width1 = look.bladeWidth * scale
		beam.Transparency = NumberSequence.new(1 - vis)
	end
	for _, c in b.cores do
		c.Transparency = 1 - vis
	end
	b.light.Brightness = look.lightBrightness * vis
end

-- The X where the blades cross: two white neon bars at ±45° facing the caster, a white core flash, a light pop,
-- a camera-facing hit sprite and a spray of blue + gold sparks.
local function crossFlash(pos: Vector3, dir: Vector3)
	local f = look.flash
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2), WHITE)
	holder.Transparency = 1
	holder.CFrame = CFrame.lookAt(pos, pos - dir)
	holder.Parent = workspace
	local info = TweenInfo.new(f.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, deg in { 45, -45 } do
		local bar = fxPart(Vector3.new(0.5, f.size * 0.4, 0.1), WHITE)
		bar.CFrame = holder.CFrame * CFrame.Angles(0, 0, math.rad(deg))
		bar.Parent = holder
		TweenService:Create(bar, info, { Size = Vector3.new(0.12, f.size, 0.05), Transparency = 1 }):Play()
	end
	local core = fxPart(Vector3.new(1, 1, 1), WHITE)
	core.Shape = Enum.PartType.Ball
	core.CFrame = holder.CFrame
	core.Transparency = 0.1
	core.Parent = holder
	TweenService:Create(core, info, { Size = Vector3.one * f.size * 0.45, Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color = WHITE
	light.Brightness = f.light
	light.Range = 18
	light.Parent = holder
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	local hitArt = AssetIds.image("crescentHitAdd")
	if hitArt then
		local e = Instance.new("ParticleEmitter")
		e.Texture = hitArt
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = 0
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(f.time)
		e.Size = NumberSequence.new(f.size * 0.3, f.size)
		e.Transparency = NumberSequence.new(0, 1)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = holder
		e:Emit(1)
	end
	if not lowGraphics() then
		for _, color in { COLORS[-1], COLORS[1], WHITE } do
			local s = Instance.new("ParticleEmitter")
			s.Texture = SPARK_TEXTURE
			s.Color = ColorSequence.new(color)
			s.LightEmission = 1
			s.Rate = 0
			s.Lifetime = NumberRange.new(0.2, 0.45)
			s.Speed = NumberRange.new(10, 22)
			s.SpreadAngle = Vector2.new(180, 180)
			s.Drag = 6
			s.Size = NumberSequence.new(0.45, 0)
			s.Parent = holder
			s:Emit(math.floor(f.sparks / 3))
		end
	end
	soundAt(AssetIds.sound("crescentHit"), pos, look.sound.cross, look.sound.crossPitch)
	Debris:AddItem(holder, f.time + 0.6)
end

-- Flies both blades along the Scissor path from origin (flat dir) to the range, flashing the X where they cross.
function TwinCrescentFx.scissor(origin: Vector3, dir: Vector3, _character: Model?)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 or live >= look.maxLive then
		return
	end
	flat = flat.Unit
	live += 1
	local p = cfg :: any
	local params = { curve = "Scissor", width = p.width, crossAt = p.crossAt, range = p.range }
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local blades: { [number]: Blade } = {}
	for _, side in { -1, 1 } do
		local b = buildBlade(side)
		setBlade(b, look.growFrom, 1)
		b.model:PivotTo(CFrame.lookAt(origin + right * side * p.width, origin + right * side * p.width + flat))
		b.model.Parent = workspace
		blades[side] = b
	end
	local traveled, age = 0, 0
	local crossed = false
	local dissolving: number? = nil
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		age += dt
		if dissolving == nil then
			traveled = math.min(p.range, traveled + p.speed * dt)
			local grow = math.min(1, look.growFrom + (1 - look.growFrom) * age / look.growTime)
			for side, b in blades do
				local pos = origin + flat * traveled + right * Scissor.lateral(side, traveled, params)
				local tangent = (flat + right * Scissor.slope(side, traveled, params)).Unit
				-- roll each blade toward the aim line so the pair reads as scissor blades
				local roll = math.rad(look.rollDeg) * side
				b.model:PivotTo(CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, roll))
				setBlade(b, grow, 1)
			end
			if not crossed and traveled >= p.crossAt then
				crossed = true
				crossFlash(origin + flat * p.crossAt, flat)
			end
			if traveled >= p.range then
				dissolving = 0
				for _, b in blades do
					if b.sparks then
						b.sparks.Enabled = false
					end
				end
			end
		else
			dissolving += dt
			local k = math.clamp(1 - (dissolving :: number) / look.dissolveTime, 0, 1)
			for _, b in blades do
				setBlade(b, 1 + (1 - k) * 0.5, k)
			end
			if k <= 0 then
				if conn then
					conn:Disconnect()
				end
				for _, b in blades do
					b.model:Destroy()
				end
				live -= 1
			end
		end
	end)
end

-- 3rd blade (T-056c, D-406): the server sends `fx.twin.third` only when both blades reached the cross. A silver-white
-- blade, `third.sizeMult` × one blade's size, flies straight from the cross along the aim for range × rangeMult and
-- dissolves early on walls / solid parts (enemy hits end it on the server; the hit FX shows there).
function TwinCrescentFx.third(origin: Vector3, dir: Vector3, character: Model?)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 or live >= look.maxLive then
		return
	end
	flat = flat.Unit
	live += 1
	local t = (cfg :: any).third
	local scale = t.sizeMult
	local range = cfg.range * t.rangeMult
	local b = buildBlade(0)
	b.model:ScaleTo(scale)
	setBlade(b, look.growFrom * scale, 1)
	b.model:PivotTo(CFrame.lookAt(origin, origin + flat))
	b.model.Parent = workspace
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = if character then { character, b.model } else { b.model }
	local traveled, age = 0, 0
	local dissolving: number? = nil
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		age += dt
		if dissolving == nil then
			local step = math.min(range - traveled, cfg.speed * dt)
			local from = origin + flat * traveled
			local hit = workspace:Raycast(from, flat * step, ray)
			local wall = hit
				and (
					hit.Instance:IsA("Terrain")
					or (hit.Instance:IsA("BasePart") and hit.Instance.Anchored and hit.Instance.CanCollide)
				)
			traveled += step
			local grow = math.min(1, look.growFrom + (1 - look.growFrom) * age / look.growTime)
			local pos = if wall and hit then hit.Position else origin + flat * traveled
			b.model:PivotTo(CFrame.lookAt(pos, pos + flat))
			setBlade(b, grow * scale, 1)
			if wall or traveled >= range then
				dissolving = 0
				if b.sparks then
					b.sparks.Enabled = false
				end
			end
		else
			dissolving += dt
			local k = math.clamp(1 - (dissolving :: number) / look.dissolveTime, 0, 1)
			setBlade(b, (1 + (1 - k) * 0.5) * scale, k)
			if k <= 0 then
				if conn then
					conn:Disconnect()
				end
				b.model:Destroy()
				live -= 1
			end
		end
	end)
end

-- Full Moon Ring (T-053c2, D-408): blue and gold blades (alternating) form a ring round the caster, then fly
-- straight outward for `range`; each dissolves early on walls / solid parts. Visual only (hits are server-side).
function TwinCrescentFx.ring(origin: Vector3, dir: Vector3, character: Model?)
	if live >= look.maxLive then
		return
	end
	live += 1
	local p = Config.Abilities.FullMoonRing :: any
	local params = { curve = "Ring", count = p.count, radius = p.radius, range = p.range }
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = if character then { character } else {}
	type RingBlade = { b: Blade, out: Vector3, traveled: number, stopped: boolean }
	local blades: { RingBlade } = {}
	for i, d in Ring.directions(dir.X, dir.Z, params) do
		local b = buildBlade(if i % 2 == 1 then -1 else 1)
		local out = Vector3.new(d.x, 0, d.z)
		local pos = origin + out * p.radius
		setBlade(b, look.growFrom, 1)
		b.model:PivotTo(CFrame.lookAt(pos, pos + out))
		b.model.Parent = workspace
		table.insert(blades, { b = b, out = out, traveled = 0, stopped = false })
	end
	local age = 0
	local dissolving: number? = nil
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		age += dt
		if dissolving == nil then
			local grow = math.min(1, look.growFrom + (1 - look.growFrom) * age / look.growTime)
			local moving = false
			for _, r in blades do
				if not r.stopped then
					local from = origin + r.out * (p.radius + r.traveled)
					local step = math.min(p.range - r.traveled, p.speed * dt)
					local hit = workspace:Raycast(from, r.out * step, ray)
					local wall = hit
						and (
							hit.Instance:IsA("Terrain")
							or (hit.Instance:IsA("BasePart") and hit.Instance.Anchored and hit.Instance.CanCollide)
						)
					r.traveled += step
					local pos = if wall and hit then hit.Position else origin + r.out * (p.radius + r.traveled)
					r.b.model:PivotTo(CFrame.lookAt(pos, pos + r.out))
					if wall or r.traveled >= p.range then
						r.stopped = true
					else
						moving = true
					end
				end
				setBlade(r.b, grow, if r.stopped then 0.5 else 1)
			end
			if not moving then
				dissolving = 0
				for _, r in blades do
					if r.b.sparks then
						r.b.sparks.Enabled = false
					end
				end
			end
		else
			dissolving += dt
			local k = math.clamp(1 - (dissolving :: number) / look.dissolveTime, 0, 1)
			for _, r in blades do
				setBlade(r.b, 1 + (1 - k) * 0.5, k)
			end
			if k <= 0 then
				if conn then
					conn:Disconnect()
				end
				for _, r in blades do
					r.b.model:Destroy()
				end
				live -= 1
			end
		end
	end)
end

function TwinCrescentFx.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, "fx.twin.cast", function(ctx: any)
		if ctx.character then
			CrescentFx.swipe(ctx.character, ctx.dir, ctx.caster ~= nil and ctx.caster == Players.LocalPlayer)
		end
	end)
	FxRegistry.register(reg, "fx.twin.travel", function(ctx: any)
		local character = ctx.character or (if ctx.caster then ctx.caster.Character else nil)
		TwinCrescentFx.scissor(ctx.pos, ctx.dir, character)
	end)
	FxRegistry.register(reg, "fx.twin.third", function(ctx: any)
		local character = ctx.character or (if ctx.caster then ctx.caster.Character else nil)
		TwinCrescentFx.third(ctx.pos, ctx.dir, character)
	end)
	FxRegistry.register(reg, "fx.fullmoon.travel", function(ctx: any)
		local character = ctx.character or (if ctx.caster then ctx.caster.Character else nil)
		TwinCrescentFx.ring(ctx.pos, ctx.dir, character)
	end)
	FxRegistry.register(reg, "fx.fullmoon.hit", function(ctx: any)
		CrescentFx.hit(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end)
	FxRegistry.register(reg, "fx.twin.hit", function(ctx: any)
		CrescentFx.hit(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end)
end

return TwinCrescentFx
