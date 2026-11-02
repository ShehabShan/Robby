--!strict
-- Crescent Cut visuals and sounds (.ai/SPIKE.md §2). Art blade (T-053a3, D-385): uploaded slash texture on an
-- additive Beam, falling back to the code-built "Classic" blade when the setting or the texture id is missing.
-- Cosmetic only: nothing here decides hits.

local Debris = game:GetService("Debris")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)
local Config = require(ReplicatedStorage.Shared.Config)
local CrescentLook = require(ReplicatedStorage.Shared.CrescentLook)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local HitFeel = require(script.Parent.HitFeel)

local cfg = Config.Abilities.CrescentCut
local look = Config.Fx.CrescentCut
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

-- Art blade (T-053a3): textured additive Beam across the blade, thinner neon core arc, tip trail, light, moon dust.
local pool = CrescentLook.newPool(look.maxLive)
local freeBlades: { Model } = {}

local function lowGraphics(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and type(level) == "number" and level > 0 and level <= 3
end

local function buildArt(texture: string): Model
	local model = Instance.new("Model")
	model.Name = "CrescentCutArt"
	local pivot = fxPart(Vector3.new(0.2, 0.2, 0.2))
	pivot.Transparency = 1
	pivot.Parent = model
	model.PrimaryPart = pivot
	-- Beam runs tail (+Z) to front (-Z) in the blade plane; width spans tip to tip (X). Follows pitch with the pivot.
	local back = Instance.new("Attachment")
	back.Name = "Back"
	back.CFrame = CFrame.new(0, 0, look.bladeDepth / 2) * CFrame.Angles(0, 0, math.rad(90)) -- X axis up: beam lies flat in the blade plane
	back.Parent = pivot
	local front = Instance.new("Attachment")
	front.Name = "Front"
	front.CFrame = CFrame.new(0, 0, -look.bladeDepth / 2) * CFrame.Angles(0, 0, math.rad(90)) -- X axis up: beam lies flat in the blade plane
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
	beam.Width0 = look.bladeWidth
	beam.Width1 = look.bladeWidth
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	beam.Parent = pivot
	for i = 1, 5 do
		local a = -ARC / 2 + ARC * (i - 1) / 4
		local r = RADIUS * look.coreScale
		local seg = fxPart(Vector3.new(1.1 * look.coreScale, 0.08, 0.15))
		seg.Name = "Core"
		seg.CFrame = CFrame.new(math.sin(a) * r, 0, r * (1 - math.cos(a))) * CFrame.Angles(0, -a, 0)
		seg.Parent = model
		if i == 1 or i == 5 then
			local tip = Instance.new("Attachment")
			tip.Name = if i == 1 then "TipA" else "TipB"
			tip.Parent = seg
		end
	end
	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(BLUE)
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = look.trailLife
	trail.LightEmission = 1
	trail.Parent = pivot
	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Brightness = look.lightBrightness
	light.Range = 10
	light.Parent = pivot
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = AssetIds.image("crescentSlashAlpha") or SPARK_TEXTURE
	dust.Color = ColorSequence.new(BLUE)
	dust.LightEmission = 1
	dust.Rate = look.dustRate
	dust.Lifetime = NumberRange.new(0.25, 0.45)
	dust.Speed = NumberRange.new(0.5, 1.5)
	dust.Size = NumberSequence.new(0.35, 0)
	dust.Rotation = NumberRange.new(0, 360)
	dust.Parent = pivot
	local tips: { Attachment } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and (d.Name == "TipA" or d.Name == "TipB") then
			table.insert(tips, d)
		end
	end
	trail.Attachment0 = tips[1]
	trail.Attachment1 = tips[2]
	return model
end

local function setArt(model: Model, scale: number, vis: number, widen: number)
	for _, d in model:GetDescendants() do
		if d:IsA("Beam") then
			d.Width0 = look.bladeWidth * scale * widen
			d.Width1 = look.bladeWidth * scale * widen
			d.Transparency = NumberSequence.new(1 - vis)
		elseif d:IsA("BasePart") and d.Name == "Core" then
			d.Transparency = 1 - vis
		elseif d:IsA("PointLight") then
			d.Brightness = look.lightBrightness * vis
		end
	end
end

local function worldStop(from: Vector3, to: Vector3, character: Model?): (number?, Vector3?)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = if character then { character } else {}
	rp.RespectCanCollide = true
	local hit = workspace:Raycast(from, to - from, rp)
	if not hit then
		return nil
	end
	local inst = hit.Instance
	if
		inst:IsA("Terrain") or (inst:IsA("BasePart") and inst.Anchored and not inst:FindFirstAncestorOfClass("Model"))
	then
		return hit.Distance
	end
	local m = inst:FindFirstAncestorOfClass("Model")
	if inst:IsA("BasePart") and inst.Anchored and m and not m:FindFirstChildOfClass("Humanoid") then
		return hit.Distance, hit.Normal
	end
	return nil
end

-- Hit and impact sprites (T-053a5, D-386): one additive particle from the uploaded hit art, grown over its life.
local function sprite(pos: Vector3, normal: Vector3?, burst: { from: number, to: number, time: number }, dust: number?)
	local texture = AssetIds.image("crescentHitAdd")
	if not texture then
		return -- no art: HitFeel alone (Classic look)
	end
	local holder = fxPart(Vector3.new(0.2, 0.2, 0.2))
	holder.Transparency = 1
	holder.CFrame = if normal
		then CFrame.lookAt(pos, pos + normal) * CFrame.Angles(math.rad(-90), 0, 0)
		else CFrame.new(pos)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Speed = NumberRange.new(if normal then 0.01 else 0)
	e.Lifetime = NumberRange.new(burst.time)
	e.Size = NumberSequence.new(burst.from, burst.to)
	e.Transparency = NumberSequence.new(0, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	if normal then
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular -- flat on the surface
	end
	e.Parent = holder
	e:Emit(1)
	if normal and dust and dust > 0 and not lowGraphics() then
		local d = emitter(0)
		d.Lifetime = NumberRange.new(0.2, 0.5)
		d.Speed = NumberRange.new(4, 9)
		d.SpreadAngle = Vector2.new(70, 70)
		d.Acceleration = Vector3.new(0, -workspace.Gravity * 0.15, 0)
		d.EmissionDirection = Enum.NormalId.Top
		d.Parent = holder
		d:Emit(dust)
	end
	Debris:AddItem(holder, burst.time + 0.6)
end

local hitsOn: { [Model]: number } = {} -- live art blade → targets hit (pierce dim)
local bladeOf: { [Model]: Model } = {} -- caster character → its newest live art blade

local function artCrescent(texture: string, origin: Vector3, dir: Vector3, character: Model?): boolean
	local took = CrescentLook.acquire(pool)
	if took == "full" then
		return false
	end
	local model = if took == "reuse" then table.remove(freeBlades) :: Model else buildArt(texture)
	local dust = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Dust")
	if dust and dust:IsA("ParticleEmitter") then
		dust.Enabled = not lowGraphics()
	end
	setArt(model, look.growFrom, 1, 1)
	hitsOn[model] = 0
	if character then
		bladeOf[character] = model
	end
	local impactNormal: Vector3? = nil
	model:PivotTo(CFrame.lookAt(origin, origin + dir))
	model.Parent = workspace
	local traveled, age = 0, 0
	local range = cfg.range
	local dissolving: number? = nil
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		age += dt
		if dissolving == nil then
			local nextT = math.min(range, traveled + cfg.speed * dt)
			range = CrescentLook.stopDistance(
				range,
				(function()
					local d, n = worldStop(origin + dir * traveled, origin + dir * nextT, character)
					if d then
						impactNormal = n
					end
					return if d then traveled + d else nil
				end)()
			)
			traveled = math.min(nextT, range)
			local pos = origin + dir * traveled
			local roll = CrescentLook.rollAt(look, traveled, cfg.range)
			model:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, roll))
			local vis = CrescentLook.pierceVis(hitsOn[model] or 0, look.pierceDim)
			setArt(model, CrescentLook.scaleAt(look, age), vis, 1)
			if traveled >= range then
				dissolving = 0
				if impactNormal and range < cfg.range then
					sprite(pos, impactNormal, look.impactBurst, look.impactBurst.dust) -- world impact
				end
				if dust and dust:IsA("ParticleEmitter") then
					dust.Enabled = false
				end
			end
		else
			dissolving += dt
			local vis, widen, done = CrescentLook.dissolveAt(look, dissolving :: number)
			setArt(model, 1, vis * CrescentLook.pierceVis(hitsOn[model] or 0, look.pierceDim), widen)
			if done then
				if conn then
					conn:Disconnect()
				end
				model.Parent = nil
				hitsOn[model] = nil
				if character and bladeOf[character] == model then
					bladeOf[character] = nil
				end
				table.insert(freeBlades, model)
				CrescentLook.release(pool)
			end
		end
	end)
	return true
end

-- Flies a crescent from origin along dir to the ability's range (or a wall in Art look), then fades it.
function CrescentFx.crescent(origin: Vector3, dir: Vector3, character: Model?)
	local texture = AssetIds.image("crescentSlashAdd")
	if CrescentLook.choose(look, texture) == "Art" then
		artCrescent(texture :: string, origin, dir, character)
		return
	end
	CrescentFx.classic(origin, dir)
end

-- The code-built blade (look = "Classic", or no uploaded texture).
function CrescentFx.classic(origin: Vector3, dir: Vector3)
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
-- Caster only (T-053a4, D-387): snap to the aim yaw (unless shift-locked) and a tiny FOV kick.
local function casterFeel(character: Model, dir: Vector3?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if dir and root and root:IsA("BasePart") and Players.LocalPlayer:GetAttribute("ShiftLock") ~= true then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 1e-3 then
			local from = root.CFrame
			local to = CFrame.lookAt(from.Position, from.Position + flat.Unit)
			local t = 0
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function(dt: number)
				t = math.min(look.turnTime, t + dt)
				local a = if look.turnTime > 0 then t / look.turnTime else 1
				local now = root.CFrame
				root.CFrame = CFrame.new(now.Position) * (from.Rotation:Lerp(to.Rotation, a))
				if a >= 1 and conn then
					conn:Disconnect()
				end
			end)
		end
	end
	local camera = workspace.CurrentCamera
	if camera and look.fovKick ~= 0 and Players.LocalPlayer:GetAttribute("FovKick") ~= false then
		local base = camera.FieldOfView
		local half = look.fovKickTime / 2
		local kick = TweenService:Create(camera, TweenInfo.new(half), { FieldOfView = base + look.fovKick })
		kick.Completed:Once(function()
			TweenService:Create(camera, TweenInfo.new(half), { FieldOfView = base }):Play()
		end)
		kick:Play()
	end
end

-- 3-phase arm swing (T-053a4): anticipation pull-back, release, follow-through. Tweened Motor6D, no upload.
function CrescentFx.swipe(character: Model, dir: Vector3?, isCaster: boolean?)
	if isCaster then
		casterFeel(character, dir)
	end
	local arm = character:FindFirstChild("RightUpperArm")
	local shoulder = if arm then arm:FindFirstChild("RightShoulder") else nil
	if shoulder and shoulder:IsA("Motor6D") then
		local base = originals[shoulder] or shoulder.C0
		originals[shoulder] = base
		local pull = TweenService:Create(
			shoulder,
			TweenInfo.new(look.swing.pull, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = base * CFrame.Angles(0, math.rad(30), math.rad(-25)) }
		)
		local release = TweenService:Create(
			shoulder,
			TweenInfo.new(look.swing.release, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = base * CFrame.Angles(0, math.rad(-70), math.rad(80)) }
		)
		local follow = TweenService:Create(
			shoulder,
			TweenInfo.new(look.swing.follow, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ C0 = base }
		)
		pull.Completed:Once(function()
			release:Play()
		end)
		release.Completed:Once(function()
			follow:Play()
		end)
		pull:Play()
	end
	local hand = character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		task.delay(look.swing.pull, function()
			sprite(hand.Position, nil, look.handFlash, nil) -- small hand flash at release
		end)
	end
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
	if position then
		sprite(position, nil, look.hitBurst, nil) -- hit sprite burst on top of HitFeel (T-053a5)
	end
	local blade = if caster and caster.Character then bladeOf[caster.Character] else nil
	if blade and hitsOn[blade] then
		hitsOn[blade] += 1 -- dims the blade: a pierce reads as a pierce
	end
end

-- Registers the Crescent handlers under the fx ids its Content names (T-002c4).
function CrescentFx.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, "fx.crescent.cast", function(ctx: any)
		if ctx.character then
			CrescentFx.swipe(ctx.character, ctx.dir, ctx.caster ~= nil and ctx.caster == Players.LocalPlayer)
		end
	end)
	FxRegistry.register(reg, "fx.crescent.travel", function(ctx: any)
		local character = ctx.character or (if ctx.caster then ctx.caster.Character else nil)
		CrescentFx.crescent(ctx.pos, ctx.dir, character)
	end)
	FxRegistry.register(reg, "fx.crescent.hit", function(ctx: any)
		CrescentFx.hit(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end)
end

return CrescentFx
