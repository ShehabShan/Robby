--!strict
-- Wind Step visuals (T-015b; ART palette: Wind jade #7FE0B8).
-- Code-built only, no uploaded assets. Cosmetic only: nothing here decides hits.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)

local WIND = Color3.fromRGB(127, 224, 184)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local KithFx = {}

-- Jade gust puff at the stepping character.
local function gust(character: Model?)
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(WIND)
	e.Rate = 0
	e.LightEmission = 0.5
	e.Lifetime = NumberRange.new(0.2, 0.4)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Parent = root
	e:Emit(16)
	Debris:AddItem(e, 1)
end

function KithFx.register(reg: FxRegistry.Registry)
	for _, id in { "fx.wind.cast", "fx.wind.step" } do
		FxRegistry.register(reg, id, function(ctx: any)
			gust(ctx.character)
		end)
	end
end

return KithFx
