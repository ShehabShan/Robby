--!strict
-- Boss HP bar (T-023c, D-139): top-of-screen bar for the nearest `Boss`-tagged model within range.
-- Shows name, HP and an "Enraged" cue in phase 2 (server `Phase` attribute). View logic in `Shared.BossBar`.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossBar = require(ReplicatedStorage.Shared.BossBar)

local RED = Color3.fromRGB(200, 40, 30)
local ENRAGED = Color3.fromRGB(255, 120, 30)

local BossHud = {}

local function text(parent: Instance, pos: UDim2, size: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Parent = parent
	return t
end

function BossHud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossHud"
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 14)
	frame.Size = UDim2.new(0.5, 0, 0, 44)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(520, 44)
	constraint.Parent = frame
	local name = text(frame, UDim2.fromScale(0, 0), UDim2.new(0.7, 0, 0, 20))
	name.TextXAlignment = Enum.TextXAlignment.Left
	local cue = text(frame, UDim2.fromScale(0.7, 0), UDim2.new(0.3, 0, 0, 20))
	cue.TextXAlignment = Enum.TextXAlignment.Right
	cue.TextColor3 = ENRAGED
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 16)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = back
	local hp = text(back, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local c = Players.LocalPlayer.Character
		local me = c and c:FindFirstChild("HumanoidRootPart")
		local models: { Model } = {}
		local dists: { number } = {}
		if me and me:IsA("BasePart") then
			for _, m in CollectionService:GetTagged("Boss") do
				local h = m:FindFirstChildOfClass("Humanoid")
				local body = m:FindFirstChild("Body")
				if m:IsA("Model") and h and h.Health > 0 and body and body:IsA("BasePart") then
					table.insert(models, m)
					table.insert(dists, (body.Position - me.Position).Magnitude)
				end
			end
		end
		local i = BossBar.pick(dists)
		if not i then
			frame.Visible = false
			return
		end
		local m = models[i]
		local h = m:FindFirstChildOfClass("Humanoid") :: Humanoid
		local v = BossBar.view(h.Health, h.MaxHealth, m:GetAttribute("Phase"))
		name.Text = m.Name
		cue.Text = v.phaseText
		hp.Text = v.text
		fill.Size = UDim2.fromScale(v.frac, 1)
		fill.BackgroundColor3 = if v.enraged then ENRAGED else RED
		frame.Visible = true
	end)
end

return BossHud
