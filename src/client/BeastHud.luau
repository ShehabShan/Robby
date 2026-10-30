--!strict
-- Beast labels (T-022c, D-135): a local BillboardGui over every `Beast`-tagged model with its name and Rank,
-- coloured by `Shared.RankBand` (viewer Rank vs beast Rank), plus a red "!" while the server sets `Telegraph`
-- (the wind-up, ≥ 0.4 s). Works with streaming: labels attach when a beast streams in.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local RankBand = require(ReplicatedStorage.Shared.RankBand)
local TelegraphFx = require(ReplicatedStorage.Shared.TelegraphFx)

local BeastHud = {}

local function label(parent: Instance, y: number, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, size)
	t.Position = UDim2.fromScale(0, y)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextStrokeTransparency = 0.3
	t.Parent = parent
	return t
end

local function attach(inst: Instance, fx: FxRegistry.Registry?)
	if not inst:IsA("Model") or inst:FindFirstChild("BeastHud", true) then
		return
	end
	local model = inst :: Model
	local body = model:WaitForChild("Body", 5)
	if not body or not body:IsA("BasePart") then
		return
	end
	local part = body :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "BeastHud"
	gui.Size = UDim2.fromOffset(150, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Adornee = part
	local alert = label(gui, 0, 0.5)
	alert.Text = "!"
	alert.TextColor3 = Color3.fromRGB(255, 60, 40)
	alert.Visible = false
	local name = label(gui, 0.5, 0.5)
	local me = Players.LocalPlayer
	local function refresh()
		local band = RankBand.of(me:GetAttribute("Rank"), model:GetAttribute("Rank"))
		name.Text = `{model.Name} · R{tostring(model:GetAttribute("Rank") or 1)}`
		name.TextColor3 = Color3.fromRGB(band.r, band.g, band.b)
	end
	-- Wind-up ground ring (D-157): a red disc of the strike reach under the beast while `Telegraph` is on.
	local kind: any = Config.Beasts.kinds[model:GetAttribute("BeastKind") :: any]
	local ring: Part? = nil
	local function clearRing()
		if ring then
			ring:Destroy()
			ring = nil
		end
	end
	local was: unknown = false
	local function telegraph()
		local on = model:GetAttribute("Telegraph") == true
		alert.Visible = on
		clearRing()
		if on and kind then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model }
			local hit = workspace:Raycast(part.Position, Vector3.new(0, -30, 0), params)
			local ground = if hit then hit.Position else part.Position - Vector3.new(0, part.Size.Y / 2, 0)
			local d = (kind.range + 1) * 2
			local r = Instance.new("Part")
			r.Name = "TelegraphRing"
			r.Shape = Enum.PartType.Cylinder
			r.Size = Vector3.new(0.2, d, d)
			r.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			r.Anchored = true
			r.CanCollide = false
			r.CanQuery = false
			r.CanTouch = false
			r.CastShadow = false
			r.Material = Enum.Material.Neon
			r.Color = Color3.fromRGB(255, 60, 40)
			r.Transparency = 0.65
			r.Parent = workspace
			ring = r
		end
		if fx and TelegraphFx.edge(was, on) == "start" then
			FxRegistry.play(fx, TelegraphFx.FX_ID, { model = model }) -- warning sound; boss ring/cone (D-136)
		end
		was = on
	end
	refresh()
	telegraph()
	local rankConn = me:GetAttributeChangedSignal("Rank"):Connect(refresh)
	model:GetAttributeChangedSignal("Telegraph"):Connect(telegraph)
	model.Destroying:Connect(function()
		rankConn:Disconnect()
		clearRing()
	end)
	gui.Parent = part
end

function BeastHud.start(fx: FxRegistry.Registry?)
	for _, m in CollectionService:GetTagged("Beast") do
		task.spawn(attach, m, fx)
	end
	CollectionService:GetInstanceAddedSignal("Beast"):Connect(function(m: Instance)
		task.spawn(attach, m, fx)
	end)
end

return BeastHud
