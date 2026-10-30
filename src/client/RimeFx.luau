--!strict
-- Rimeshard visuals (T-027e, D-197): pooled ice shards (≤12 per cast, `Shared.RimeFxPlan`), Rime Fall telegraph,
-- rain and frost disc, Chill crust, Shatter ring + camera shake. Code-built only, placeholder built-in sounds.
-- Cosmetic only: nothing here decides hits.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local RimeFxPlan = require(ReplicatedStorage.Shared.RimeFxPlan)
local HitFeel = require(script.Parent.HitFeel)

local R = Config.Abilities.Rimeshard
local ICE = Color3.fromRGB(168, 230, 255)
local RED = Color3.fromRGB(255, 70, 70)
local CAST_SOUND = "rbxasset://sounds/swordslash.wav" -- placeholder
local SHATTER_SOUND = "rbxasset://sounds/electronicpingshort.wav" -- placeholder
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local MAX_ACTIVE = 24 -- all casts together; each cast stays within RimeFxPlan.MAX_SHARDS

local RimeFx = {}

local pool: { BasePart } = {}
local active = 0

local function take(): BasePart?
	if active >= MAX_ACTIVE then
		return nil
	end
	active += 1
	local p: BasePart? = table.remove(pool)
	if p == nil then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Glass
		part.Color = ICE
		part.Transparency = 0.2
		part.Size = Vector3.new(0.3, 0.3, 1.8)
		p = part
	end
	return p
end

local function give(p: BasePart)
	active -= 1
	p.Parent = nil
	table.insert(pool, p)
end

local function rootOf(character: any): BasePart?
	local r = if typeof(character) == "Instance" then character:FindFirstChild("HumanoidRootPart") else nil
	return if r and r:IsA("BasePart") then r else nil
end

local function sound(id: string, parent: Instance?, volume: number)
	if not parent then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 2)
end

local function puff(pos: any, n: number)
	if typeof(pos) ~= "Vector3" then
		return
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(ICE)
	e.Rate = 0
	e.LightEmission = 0.6
	e.Lifetime = NumberRange.new(0.2, 0.45)
	e.Speed = NumberRange.new(3, 9)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Parent = a
	e:Emit(n)
	Debris:AddItem(a, 1)
end

local function shake(strength: number, seconds: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		if t >= seconds then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local k = strength * (1 - t / seconds)
		cam.CFrame *= CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

local function yaw(dir: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(dir)
end

-- Flies one pooled shard from origin along dir to `range`, then returns it to the pool.
local function fly(origin: any, dir: any, speed: number, range: number)
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then
		return
	end
	local shard = take()
	if not shard then
		return
	end
	shard.CFrame = CFrame.lookAt(origin, origin + dir)
	shard.Parent = workspace
	local traveled = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		traveled = math.min(range, traveled + speed * dt)
		local pos = origin + dir * traveled
		shard.CFrame = CFrame.lookAt(pos, pos + dir)
		if traveled >= range then
			if conn then
				conn:Disconnect()
			end
			give(shard)
		end
	end)
end

local function fanOut(ctx: any, count: number, spreadDeg: number, speed: number, range: number)
	if typeof(ctx.dir) ~= "Vector3" then
		return
	end
	for _, a in RimeFxPlan.extras(count, spreadDeg) do
		fly(ctx.pos, yaw(ctx.dir, a), speed, range)
	end
end

-- Flat ground disc (Cylinder lies on its side) that fades out.
local function disc(pos: Vector3, radius: number, color: Color3, material: Enum.Material, seconds: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = material
	p.Color = color
	p.Transparency = 0.55
	p.Size = Vector3.new(0.15, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	Debris:AddItem(p, seconds + 0.1)
end

local function crust(model: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local old = model:FindFirstChild("RimeCrust")
	if old then
		old:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "RimeCrust"
	h.FillColor = ICE
	h.OutlineColor = ICE
	h.FillTransparency = 0.6
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	Debris:AddItem(h, R.chill.seconds)
end

local function rain(ctx: any)
	local centre = ctx.point or ctx.pos
	if typeof(centre) ~= "Vector3" then
		return
	end
	local f = R.rimeFall
	local points = RimeFxPlan.rain(8, f.radius)
	local function drop(i: number, x: number, z: number)
		task.delay(f.duration * (i - 1) / #points, function()
			local shard = take()
			if not shard then
				return
			end
			local ground = centre + Vector3.new(x, 0, z)
			shard.CFrame = CFrame.lookAt(ground + Vector3.new(0, 18, 0), ground)
			shard.Parent = workspace
			local tw = TweenService:Create(shard, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.9, 0), ground),
			})
			tw.Completed:Once(function()
				puff(ground, 6)
				give(shard)
			end)
			tw:Play()
		end)
	end
	local function start()
		for i, p in points do
			drop(i, p.x, p.z)
		end
		disc(centre, f.radius, ICE, Enum.Material.Ice, f.duration + 1.5) -- frost decal left on the ground
	end
	if ctx.caster == Players.LocalPlayer then
		task.delay(f.delay, start) -- the caster plays cast + travel at once; rain waits out the telegraph
	else
		start()
	end
end

local function hit(ctx: any, n: number)
	puff(ctx.pos, n)
	crust(ctx.target)
	if ctx.caster then
		HitFeel.play(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end
end

function RimeFx.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, "fx.rime.needle.cast", function(ctx: any)
		sound(CAST_SOUND, rootOf(ctx.character), 0.35)
	end)
	FxRegistry.register(reg, "fx.rime.needle.travel", function(ctx: any)
		fly(ctx.pos, ctx.dir, R.needle.speed, R.needle.range)
	end)
	FxRegistry.register(reg, "fx.rime.needle.finisher", function(ctx: any)
		sound(CAST_SOUND, rootOf(ctx.character), 0.5)
		local n = R.needle
		fanOut(ctx, n.finisher.shards, n.finisher.spreadDeg, n.speed, n.range)
	end)
	FxRegistry.register(reg, "fx.rime.fan.cast", function(ctx: any)
		sound(CAST_SOUND, rootOf(ctx.character), 0.5)
		local s = R.shardFan
		fanOut(ctx, s.count, s.spreadDeg, s.speed, s.range)
	end)
	FxRegistry.register(reg, "fx.rime.hit", function(ctx: any)
		hit(ctx, 10)
	end)
	FxRegistry.register(reg, "fx.rime.fall.tick", function(ctx: any)
		hit(ctx, 5)
	end)
	FxRegistry.register(reg, "fx.rime.chill", function(ctx: any)
		crust(ctx.target or ctx.character)
	end)
	FxRegistry.register(reg, "fx.rime.fall.telegraph", function(ctx: any)
		local centre = ctx.point or ctx.pos
		if typeof(centre) == "Vector3" then
			disc(centre, R.rimeFall.radius, RED, Enum.Material.Neon, R.rimeFall.delay)
		end
	end)
	FxRegistry.register(reg, "fx.rime.fall.rain", rain)
	FxRegistry.register(reg, "fx.rime.shatter.cast", function(ctx: any)
		local root = rootOf(ctx.character)
		sound(SHATTER_SOUND, root, 0.6)
		if root then
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Ball
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.Material = Enum.Material.Neon
			ring.Color = ICE
			ring.Transparency = 0.5
			ring.Size = Vector3.new(2, 2, 2)
			ring.CFrame = root.CFrame
			ring.Parent = workspace
			local d = R.shatter.radius * 2
			TweenService:Create(ring, TweenInfo.new(0.3), { Size = Vector3.new(d, d, d), Transparency = 1 }):Play()
			Debris:AddItem(ring, 0.4)
		end
		if ctx.caster == Players.LocalPlayer then
			shake(0.6, 0.25)
		end
	end)
	FxRegistry.register(reg, "fx.rime.shatter", function(ctx: any)
		hit(ctx, 24)
	end)
end

return RimeFx
