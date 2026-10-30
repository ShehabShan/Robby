--!strict
-- Beast telegraph visuals + sound (T-022c, D-136). Cosmetic only: the server alone decides beast hits.
-- `fx.beast.telegraph` draws a red ground warning (full ring for slams, front cone for lunges) that fills
-- over the wind-up, plus a short warning sound. Shapes and timing come from pure `Shared.TelegraphFx`.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local TelegraphFx = require(ReplicatedStorage.Shared.TelegraphFx)

local C = TelegraphFx.COLOR
local RED = Color3.fromRGB(C.r, C.g, C.b)
local WARN_SOUND = "rbxasset://sounds/electronicpingshort.wav" -- placeholder until the audio pass

local BeastFx = {}

local function disc(parent: Instance, cf: CFrame, radius: number, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, radius * 2, radius * 2)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Transparency = transparency
	p.Parent = parent
	return p
end

-- Front cone: a fan of thin wedge-like bars from the beast outwards.
local function cone(parent: Instance, cf: CFrame, params: TelegraphFx.Params)
	local steps = 7
	local half = math.rad(params.coneDeg / 2)
	for i = 0, steps - 1 do
		local a = -half + (2 * half) * (i / (steps - 1))
		local bar = Instance.new("Part")
		bar.Size = Vector3.new(0.4, 0.05, params.radius)
		bar.CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -params.radius / 2)
		bar.Anchored = true
		bar.CanCollide = false
		bar.CanQuery = false
		bar.CanTouch = false
		bar.CastShadow = false
		bar.Material = Enum.Material.Neon
		bar.Color = RED
		bar.Transparency = 0.45
		bar.Parent = parent
	end
end

local function warn(ctx: any)
	local model = ctx.model
	local body = if typeof(model) == "Instance" then model:FindFirstChild("Body") else nil
	if not body or not body:IsA("BasePart") then
		return
	end
	local kind: any = Config.Beasts.kinds[model:GetAttribute("BeastKind")]
	if model:GetAttribute("TelegraphRange") ~= nil then -- bosses send the current attack's shape (D-138)
		kind = {
			range = model:GetAttribute("TelegraphRange"),
			arcDot = model:GetAttribute("TelegraphArc"),
			telegraph = model:GetAttribute("TelegraphSeconds"),
			hp = model:GetAttribute("TelegraphWeight"),
		}
	end
	local params = TelegraphFx.params(kind)
	local here = body.Position - Vector3.new(0, body.Size.Y / 2 - 0.05, 0)
	local look = body.CFrame.LookVector
	local cf = CFrame.lookAt(here, here + Vector3.new(look.X, 0, look.Z))
	local isBoss = model:GetAttribute("TelegraphRange") ~= nil -- beasts already get BeastHud's ring (D-157)
	local folder = Instance.new("Folder")
	folder.Name = "TelegraphFx"
	if isBoss and params.allRound then
		disc(folder, cf, params.radius, 0.8) -- faint outer ring: the danger zone
		local fill = disc(folder, cf, 0.2, 0.4) -- inner disc grows to the edge as the wind-up ends
		TweenService:Create(fill, TweenInfo.new(params.seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.05, params.radius * 2, params.radius * 2),
		}):Play()
	elseif isBoss then -- beasts: sound only here
		cone(folder, cf, params)
	end
	folder.Parent = workspace
	Debris:AddItem(folder, params.seconds + 0.15)
	local s = Instance.new("Sound")
	s.SoundId = WARN_SOUND
	s.PlaybackSpeed = params.pitch
	s.Volume = 0.6
	s.RollOffMaxDistance = 80
	s.Parent = body
	s:Play()
	Debris:AddItem(s, 2)
end

function BeastFx.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, TelegraphFx.FX_ID, warn)
end

return BeastFx
