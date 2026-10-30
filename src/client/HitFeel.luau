--!strict
-- Shared client hit feel (T-014, ART §5 items 2 and 5): spark burst, SFX, white flash, damage number,
-- attacker hit-stop and camera shake. Used by every move's hit FX. Cosmetic only: nothing here decides hits.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Feel = require(ReplicatedStorage.Shared.HitFeel)

local tune: Feel.Tuning = Config.HitFeel
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local HIT_SOUND = "rbxasset://sounds/swordlunge.wav" -- placeholder

local HitFeel = {}

-- Generic hit id for moves without their own hit FX (CombatService melee chain).
HitFeel.GENERIC_ID = "fx.combat.hit"

local function burst(position: Vector3, amount: number)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Position = position
	anchor.Parent = workspace

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Rate = 0
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.2, 0.35)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = anchor
	sparks:Emit(tune.sparks)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = Feel.damageText(amount)
	label.Parent = gui
	local info = TweenInfo.new(tune.numberSeconds)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 2 + tune.numberRise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	local s = Instance.new("Sound")
	s.SoundId = HIT_SOUND
	s.Volume = 0.7
	s.Parent = anchor
	s:Play()
	Debris:AddItem(anchor, tune.numberSeconds + 0.4)
end

local function flash(target: Model)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.2
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = target
	Debris:AddItem(h, tune.flashSeconds)
end

-- Pause the attacker's playing animations for 2–4 frames.
local function hitStop(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local tracks = animator:GetPlayingAnimationTracks()
	for _, t in tracks do
		t:AdjustSpeed(0)
	end
	task.delay(Feel.hitStopSeconds(tune), function()
		for _, t in tracks do
			t:AdjustSpeed(1)
		end
	end)
end

-- Small camera shake that always returns to zero (no drift).
local function shake(humanoid: Humanoid)
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = Feel.shakeAmplitude(tune, os.clock() - start)
		if k <= 0 then
			humanoid.CameraOffset = Vector3.zero
			if conn then
				conn:Disconnect()
			end
			return
		end
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

-- Plays the full hit feel. Hit-stop and shake only for the local attacker.
function HitFeel.play(caster: Player?, target: Model?, amount: number, position: Vector3?)
	if position then
		burst(position, amount)
	end
	if target then
		flash(target)
	end
	local me = Players.LocalPlayer
	local character = me and me.Character
	if caster == me and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			hitStop(humanoid)
			shake(humanoid)
		end
	end
end

function HitFeel.register(reg: FxRegistry.Registry)
	FxRegistry.register(reg, HitFeel.GENERIC_ID, function(ctx: any)
		HitFeel.play(ctx.caster, ctx.target, ctx.amount or 0, ctx.pos)
	end)
end

return HitFeel
