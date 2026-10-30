--!strict
-- Beast labels (T-022c, D-135): a local BillboardGui over every `Beast`-tagged model with its name and Rank,
-- coloured by `Shared.RankBand` (viewer Rank vs beast Rank), plus a red "!" while the server sets `Telegraph`
-- (the wind-up, ≥ 0.4 s). Works with streaming: labels attach when a beast streams in.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RankBand = require(ReplicatedStorage.Shared.RankBand)

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

local function attach(inst: Instance)
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
	local function telegraph()
		alert.Visible = model:GetAttribute("Telegraph") == true
	end
	refresh()
	telegraph()
	local rankConn = me:GetAttributeChangedSignal("Rank"):Connect(refresh)
	model:GetAttributeChangedSignal("Telegraph"):Connect(telegraph)
	model.Destroying:Connect(function()
		rankConn:Disconnect()
	end)
	gui.Parent = part
end

function BeastHud.start()
	for _, m in CollectionService:GetTagged("Beast") do
		task.spawn(attach, m)
	end
	CollectionService:GetInstanceAddedSignal("Beast"):Connect(function(m: Instance)
		task.spawn(attach, m)
	end)
end

return BeastHud
