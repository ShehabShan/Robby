--!strict
-- Client entry point: minimal round HUD driven by ReplicatedStorage attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RoundHud"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.Name = "Status"
label.Size = UDim2.fromOffset(280, 44)
label.Position = UDim2.new(0.5, -140, 0, 12)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

gui.Parent = player:WaitForChild("PlayerGui")

local function render()
	local phase = tostring(ReplicatedStorage:GetAttribute("Phase") or "Waiting")
	local timeLeft = tostring(ReplicatedStorage:GetAttribute("TimeLeft") or 0)
	local round = tostring(ReplicatedStorage:GetAttribute("Round") or 0)
	if phase == "Waiting" then
		label.Text = "Waiting for players..."
	elseif phase == "Racing" then
		label.Text = `Round {round} · {timeLeft}s`
	else
		label.Text = `{phase} · {timeLeft}s`
	end
end

ReplicatedStorage.AttributeChanged:Connect(render)
render()
