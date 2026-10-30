--!strict
-- Core Shell HUD wiring (T-018d, D-076): draws Shared.ShellUi. Reads `Rank`, `Stage`, `StageProgress`,
-- `StageReady`, `AtRest`, `Shards` (RefineService). Hold H / D-pad Down / the Refine button at a rest spot to
-- refine; the server checks the rest spot and spends the Shards.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local ShellUi = require(ReplicatedStorage.Shared.ShellUi)

local ShellHud = {}

local function platform(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	elseif UserInputService.GamepadEnabled then
		return "gamepad"
	end
	return "pc"
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function ShellHud.start(net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoreShell"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	local pool: { [string]: GuiObject } = {}
	local holding = false

	local function set(on: boolean)
		if on ~= holding then
			holding = on
			net.Refine.Fire({ holding = on })
		end
	end
	-- With a full Peak the button starts the breakthrough trial instead of refining (T-018f).
	local function press(on: boolean)
		if on and player:GetAttribute("StageReady") == true and player:GetAttribute("TrialWave") == nil then
			net.Breakthrough.Fire({ start = true })
			return
		end
		set(on)
	end

	local function num(name: string, default: number): number
		local v = player:GetAttribute(name)
		return if typeof(v) == "number" then v else default
	end

	local function state(): ShellUi.State
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local rest = player:GetAttribute("AtRest") == true
		if not rest then
			set(false)
		end
		return {
			width = math.floor(size.X),
			height = math.floor(size.Y),
			platform = platform(),
			rank = num("Rank", 1),
			stage = num("Stage", 1),
			progress = num("StageProgress", 0),
			ready = player:GetAttribute("StageReady") == true,
			atRest = rest,
			shards = num("Shards", 0),
			trial = if typeof(player:GetAttribute("TrialWave")) == "number"
				then {
					wave = num("TrialWave", 1),
					waves = num("TrialWaves", 3),
					crack = num("TrialCrack", 0),
					timeLeft = num("TrialLeft", 0),
				}
				else nil,
		}
	end

	local function create(e: HudLayout.Element): GuiObject
		local obj: GuiObject
		if e.kind == "button" then
			local b = Instance.new("TextButton")
			b.AutoButtonColor = true
			b.Font = Enum.Font.GothamBold
			b.TextColor3 = Color3.new(1, 1, 1)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = b
			b.InputBegan:Connect(function(input: InputObject)
				local t = input.UserInputType
				if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
					press(true)
				end
			end)
			b.InputEnded:Connect(function(input: InputObject)
				local t = input.UserInputType
				if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
					set(false)
				end
			end)
			obj = b
		elseif e.kind == "text" then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextStrokeTransparency = 0.4
			obj = t
		else
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = if e.kind == "dot" then UDim.new(0.5, 0) else UDim.new(0, 3)
			corner.Parent = f
			obj = f
		end
		obj.Name = e.id
		obj.Parent = gui
		return obj
	end

	local function draw()
		local used: { [string]: boolean } = {}
		for i, e in ShellUi.build(state()) do
			local obj = pool[e.id] or create(e)
			pool[e.id] = obj
			used[e.id] = true
			obj.Position = UDim2.fromOffset(e.x, e.y)
			obj.Size = UDim2.fromOffset(e.w, e.h)
			obj.ZIndex = i
			obj.Visible = true
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				local t = obj :: any
				t.Text = e.text or ""
				t.TextSize = e.textSize or HudLayout.MIN_TEXT
			end
			if obj:IsA("TextLabel") then
				obj.TextColor3 = rgb(e.color)
				obj.TextXAlignment = if e.align == "left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			else
				obj.BackgroundColor3 = rgb(e.color)
				obj.BackgroundTransparency = 1 - (e.alpha or 1)
			end
		end
		for id, obj in pool do
			if not used[id] then
				obj.Visible = false
			end
		end
	end

	ContextActionService:BindAction("Refine", function(_, s: Enum.UserInputState, _): Enum.ContextActionResult
		if s == Enum.UserInputState.Begin then
			press(true)
		elseif s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
			set(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H, Enum.KeyCode.DPadDown)

	player.AttributeChanged:Connect(draw)
	draw()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- viewport and input type change without attribute events
		while true do
			task.wait(0.25)
			draw()
		end
	end)
end

return ShellHud
