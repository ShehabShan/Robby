--!strict
-- T-051a play mode client (D-373): R key / gamepad X / touch button -> server Wind Step.
-- Sends only a direction hint; the server validates, rate-limits and owns the cooldown.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("WindStepPlay", 30) :: RemoteEvent?
local status = ReplicatedStorage:WaitForChild("WindStepPlayStatus", 30) :: RemoteEvent?
if not remote or not status then
	warn("WIND_STEP_PLAY_CLIENT: server not ready")
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "WindStepPlayHint"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 8)
label.Size = UDim2.fromOffset(260, 28)
label.BackgroundTransparency = 0.5
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Text = "Wind Step: press R"
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local readyAt = 0
local function hint()
	local left = readyAt - os.clock()
	label.Text = if left > 0 then string.format("Wind Step: %.1fs", left) else "Wind Step: press R"
end

local function onAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen then
		return Enum.ContextActionResult.Pass
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return Enum.ContextActionResult.Sink
	end
	local move = humanoid.MoveDirection
	local look = root.CFrame.LookVector
	remote:FireServer(move.X, move.Z, look.X, look.Z)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("WindStepPlay", onAction, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("WindStepPlay", "Dash")
ContextActionService:SetPosition("WindStepPlay", UDim2.new(1, -150, 1, -150))

status.OnClientEvent:Connect(function(kind: any, seconds: any)
	if type(seconds) ~= "number" or seconds ~= seconds then
		return
	end
	if kind == "dash" or kind == "cooldown" then
		readyAt = os.clock() + math.clamp(seconds, 0, 10)
	end
	hint()
end)

task.spawn(function()
	while gui.Parent do
		hint()
		task.wait(0.1)
	end
end)
