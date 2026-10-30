--!strict
-- Crescent Cut visuals and sounds (.ai/SPIKE.md §2). Code-built only, no uploaded assets.
-- Cosmetic only: nothing here decides hits.

local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local HitFeel = require(script.Parent.HitFeel)

local cfg = Config.Abilities.CrescentCut
local BLUE = Color3.fromRGB(150, 205, 255)
local SEGMENTS = 7
local RADIUS = 3
local ARC = math.rad(120)
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CAST_SOUND = "rbxasset://sounds/swordslash.wav" -- placeholder

local CrescentFx = {}

local originals: { [Motor6D]: CFrame } = {}

local function sound(id: string, parent: Instance, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

local function fxPart(size: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = BLUE
	p.Size = size
	return p
end

local function emitter(rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK_TEXTURE
	e.Color = ColorSequence.new(BLUE)
	e.LightEmission = 1
	e.Rate = rate
	e.Size = NumberSequence.new(0.5, 0)
	return e
end

-- Builds the crescent at the origin: tips trail behind (+Z), the bow faces forward (-Z).
local function buildCrescent(): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "CrescentCut"
	local pivot = fxPart(Vector3.new(0.2, 0.2, 0.2))
	pivot.Transparency = 1
	pivot.CFrame = CFrame.identity
	pivot.Parent = model
	model.PrimaryPart = pivot
	local parts: { BasePart } = {}
	for i = 1, SEGMENTS do
		local a = -ARC / 2 + ARC * (i - 1) / (SEGMENTS - 1)
		local seg = fxPart(Vector3.new(1.2, 0.2, 0.35))
		seg.CFrame = CFrame.new(math.sin(a) * RADIUS, 0, RADIUS * (1 - math.cos(a))) * CFrame.Angles(0, -a, 0)
		seg.Parent = model
		table.insert(parts, seg)
	end
	local tipA = Instance.new("Attachment")
	tipA.Parent = parts[1]
	local tipB = Instance.new("Attachment")
	tipB.Parent = parts[SEGMENTS]
	local trail = Instance.new("Trail")
	trail.Attachment0 = tipA
	trail.Attachment1 = tipB
	trail.Color = ColorSequence.new(BLUE)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.15
	trail.LightEmission = 1
	trail.Parent = pivot
	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Brightness = 2
	light.Range = 10
	light.Parent = pivot
	local sparkle = emitter(60)
	sparkle.Lifetime = NumberRange.new(0.2, 0.4)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.Parent = pivot
	return model, parts
end

local function fade(model: Model, parts: { BasePart })
	local info = TweenInfo.new(0.15)
	for _, p in parts do
		TweenService:Create(p, info, { Transparency = 1, Size = p.Size * Vector3.new(1.6, 1, 1) }):Play()
	end
	Debris:AddItem(model, 0.3)
end

-- Flies a crescent from origin along dir to the ability's range, then fades it.
function CrescentFx.crescent(origin: Vector3, dir: Vector3)
	local model, parts = buildCrescent()
	model:PivotTo(CFrame.lookAt(origin, origin + dir))
	model.Parent = workspace
	local traveled = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		traveled = math.min(cfg.range, traveled + cfg.speed * dt)
		local pos = origin + dir * traveled
		model:PivotTo(CFrame.lookAt(pos, pos + dir))
		if traveled >= cfg.range then
			if conn then
				conn:Disconnect()
			end
			fade(model, parts)
		end
	end)
end

-- Arm swipe (tweened shoulder joint, no animation asset), palm glow and cast sound.
function CrescentFx.swipe(character: Model)
	local arm = character:FindFirstChild("RightUpperArm")
	local shoulder = if arm then arm:FindFirstChild("RightShoulder") else nil
	if shoulder and shoulder:IsA("Motor6D") then
		local base = originals[shoulder] or shoulder.C0
		originals[shoulder] = base
		local out = TweenService:Create(
			shoulder,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = base * CFrame.Angles(0, math.rad(-70), math.rad(80)) }
		)
		out.Completed:Once(function()
			TweenService:Create(shoulder, TweenInfo.new(0.15), { C0 = base }):Play()
		end)
		out:Play()
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then
		local glow = Instance.new("PointLight")
		glow.Color = BLUE
		glow.Brightness = 3
		glow.Range = 6
		glow.Parent = hand
		Debris:AddItem(glow, 0.2)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		sound(CAST_SOUND, root, 0.6)
	end
end

function CrescentFx.hit(caster: Player, target: Model?, amount: number, position: Vector3)
	HitFeel.play(caster, target, amount, position)
end

-- Registers the Crescent handlers under the fx ids its Content names (T-002c4).
function CrescentFx.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, "fx.crescent.cast", function(ctx: any)
		if ctx.character then
			CrescentFx.swipe(ctx.character)
		end
	end)
	FxRegistry.register(reg, "fx.crescent.travel", function(ctx: any)
		CrescentFx.crescent(ctx.pos, ctx.dir)
	end)
	FxRegistry.register(reg, "fx.crescent.hit", function(ctx: any)
		CrescentFx.hit(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end)
end

return CrescentFx
