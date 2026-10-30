--!strict
-- Binding UI wiring (T-017c, D-072): draws Shared.BindingUi with Roblox GUI objects. Reads `BindState`,
-- `BindProgress`, `Shards`, `HeartKith` (BindingService, D-071). Hold B / RB / the Channel button to channel
-- (pressing it near a weakened wild Kith starts the bind); G / D-pad Up / the Shard button spends a Shard.
-- The server decides everything; the client only sends BindStart / BindInput.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local BindingUi = require(ReplicatedStorage.Shared.BindingUi)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)

local RESULT_SECONDS = 3

local BindingHud = {}

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

function BindingHud.start(built: any, net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Binding"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	local pool: { [string]: GuiObject } = {}
	local channel = false
	local heartBefore: any = nil
	local resultUntil = 0

	local function nearest(): Model?
		local character = player.Character
		local root = (if character then character:FindFirstChild("HumanoidRootPart") else nil) :: BasePart?
		if not root then
			return nil
		end
		local models: { Model } = {}
		local cands: { BindingUi.Candidate } = {}
		for _, m in workspace:GetChildren() do
			local pp = if m:IsA("Model") then m.PrimaryPart else nil
			local h = m:FindFirstChildOfClass("Humanoid")
			if pp and h and m:GetAttribute("WildKith") ~= nil then
				table.insert(models, m :: Model)
				table.insert(cands, {
					speciesId = m:GetAttribute("WildKith"),
					hp = h.Health,
					maxHp = h.MaxHealth,
					dist = (pp.Position - root.Position).Magnitude,
				})
			end
		end
		local i = BindingUi.pickTarget(Config, built, cands)
		return if i then models[i] else nil
	end

	local function running(): boolean
		return player:GetAttribute("BindState") == "running"
	end
	local function send(shard: boolean)
		net.BindInput.Fire({ channel = channel, shard = shard })
	end
	local function press()
		if not running() then
			local target = nearest()
			if not target then
				return
			end
			heartBefore = player:GetAttribute("HeartKith")
			net.BindStart.Fire({ target = target })
		end
		channel = true
		send(false)
	end
	local function release()
		if channel then
			channel = false
			send(false)
		end
	end
	local function shard()
		if running() then
			send(true)
		end
	end

	local function state(): BindingUi.State
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local raw = player:GetAttribute("BindState")
		local bs = if type(raw) == "string" then raw else ""
		if (bs == "bound" or bs == "fled") and os.clock() > resultUntil then
			bs = ""
		end
		return {
			width = math.floor(size.X),
			height = math.floor(size.Y),
			platform = platform(),
			bindState = bs,
			progress = tonumber(player:GetAttribute("BindProgress")) or 0,
			shards = tonumber(player:GetAttribute("Shards")) or 0,
			heart = bs == "bound" and heartBefore == nil and player:GetAttribute("HeartKith") ~= nil,
			canBind = bs ~= "running" and nearest() ~= nil,
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
			if e.id == "bindShard" then
				b.Activated:Connect(shard)
			else -- bindStart / bindChannel: hold to channel
				b.InputBegan:Connect(function(input: InputObject)
					local t = input.UserInputType
					if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
						press()
					end
				end)
				b.InputEnded:Connect(function(input: InputObject)
					local t = input.UserInputType
					if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
						release()
					end
				end)
			end
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
			corner.CornerRadius = UDim.new(0, 3)
			corner.Parent = f
			obj = f
		end
		obj.Name = e.id
		obj.Parent = gui
		return obj
	end

	local function draw()
		local used: { [string]: boolean } = {}
		for i, e in BindingUi.build(state()) do
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

	ContextActionService:BindAction("BindChannel", function(_, s: Enum.UserInputState, _): Enum.ContextActionResult
		if s == Enum.UserInputState.Begin then
			press()
		elseif s == Enum.UserInputState.End or s == Enum.UserInputState.Cancel then
			release()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("BindShard", function(_, s: Enum.UserInputState, _): Enum.ContextActionResult
		if s == Enum.UserInputState.Begin then
			shard()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)

	player:GetAttributeChangedSignal("BindState"):Connect(function()
		local v = player:GetAttribute("BindState")
		if v == "bound" or v == "fled" then
			resultUntil = os.clock() + RESULT_SECONDS
			channel = false
		end
		draw()
	end)
	player:GetAttributeChangedSignal("BindProgress"):Connect(draw)
	draw()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- nearby Kith, viewport and result timeout change without attribute events
		while true do
			task.wait(0.2)
			draw()
		end
	end)
end

return BindingHud
