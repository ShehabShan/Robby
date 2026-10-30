--!strict
-- Crucible UI wiring (T-019e, D-085): draws Shared.CrucibleUi. At a rest spot with two fusable Kith, C / D-pad Right /
-- the Crucible button opens the confirm panel; Fuse sends CrucibleStart, then each press sends CruciblePress.
-- Reads CrucibleRound / Zone / RoundStart / Odds / Result (CrucibleService, D-083). The server decides everything.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CrucibleFocus = require(ReplicatedStorage.Shared.CrucibleFocus)
local CrucibleUi = require(ReplicatedStorage.Shared.CrucibleUi)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local LoadoutScreen = require(ReplicatedStorage.Shared.LoadoutScreen)

local CrucibleHud = {}

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

function CrucibleHud.start(net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crucible"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	local pool: { [string]: GuiObject } = {}
	local open = false
	local showResult = false
	local recipeId: string? = nil

	local function pick(): (string?, string?, string?)
		return CrucibleUi.pickPair(Config, LoadoutScreen.parseOwned(player:GetAttribute("OwnedKith")))
	end
	local function canOpen(): boolean
		local a = pick()
		return player:GetAttribute("AtRest") == true and a ~= nil
	end
	local function phase(): string?
		if player:GetAttribute("CrucibleRound") ~= nil then
			return "focus"
		elseif showResult then
			return "result"
		elseif open then
			return "confirm"
		end
		return nil
	end

	local function fuse()
		local a, b, id = pick()
		if a and b then
			recipeId = id
			net.CrucibleStart.Fire({ a = a, b = b })
		end
	end
	local function press()
		net.CruciblePress.Fire({ press = true })
	end
	local function close()
		open, showResult = false, false
	end

	local function state(ph: string): CrucibleUi.State
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local r = if recipeId then Config.Crucible.recipes[recipeId] else nil
		local f = Config.Crucible.focus
		local odds = tonumber(player:GetAttribute("CrucibleOdds"))
		local rs = tonumber(player:GetAttribute("CrucibleRoundStart"))
		local res = player:GetAttribute("CrucibleResult")
		return {
			width = math.floor(size.X),
			height = math.floor(size.Y),
			platform = platform(),
			phase = ph,
			recipe = if r then CrucibleUi.recipeLabel(r) else "?",
			odds = odds or (if r then r.baseChance else 0),
			known = (odds or 0) >= 1,
			catalyst = if r then r.catalystShards else 0,
			woundHours = Config.Crucible.woundedSeconds // 3600,
			round = tonumber(player:GetAttribute("CrucibleRound")),
			rounds = f.rounds,
			needle = if rs
				then CrucibleFocus.needle({ roundStart = rs } :: any, Config, workspace:GetServerTimeNow())
				else nil,
			zone = tonumber(player:GetAttribute("CrucibleZone")),
			zoneWidth = f.zoneWidth,
			result = if type(res) == "string" then res else nil,
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
			b.Activated:Connect(function()
				if e.id == "crucibleFuse" then
					fuse()
				elseif e.id == "focusPress" then
					press()
				else
					close()
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
			corner.CornerRadius = UDim.new(0, 3)
			corner.Parent = f
			obj = f
		end
		obj.Name = e.id
		obj.Parent = gui
		return obj
	end

	-- Small "Crucible" opener for touch / mouse when idle at a rest spot.
	local opener = Instance.new("TextButton")
	opener.Name = "crucibleOpen"
	opener.AnchorPoint = Vector2.new(1, 1)
	opener.Position = UDim2.new(1, -12, 1, -180)
	opener.Size = UDim2.fromOffset(120, 44)
	opener.Font = Enum.Font.GothamBold
	opener.TextSize = 16
	opener.TextColor3 = Color3.new(1, 1, 1)
	opener.BackgroundColor3 = Color3.fromRGB(90, 60, 140)
	opener.Text = "Crucible"
	opener.Visible = false
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0, 10)
	oc.Parent = opener
	opener.Parent = gui
	opener.Activated:Connect(function()
		local _, _, id = pick()
		if id then
			recipeId = id
			open = true
		end
	end)

	local function draw()
		local ph = phase()
		opener.Visible = ph == nil and canOpen()
		local used: { [string]: boolean } = {}
		if ph then
			for i, e in CrucibleUi.build(state(ph)) do
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
		end
		for id, obj in pool do
			if not used[id] then
				obj.Visible = false
			end
		end
	end

	-- One key does the obvious thing for the current phase.
	ContextActionService:BindAction("Crucible", function(_, s: Enum.UserInputState, _): Enum.ContextActionResult
		if s ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local ph = phase()
		if ph == "focus" then
			press()
		elseif ph == "result" then
			close()
		elseif ph == "confirm" then
			fuse()
		elseif canOpen() then
			local _, _, id = pick()
			recipeId = id
			open = true
		end
		draw()
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.DPadRight)

	player:GetAttributeChangedSignal("CrucibleResult"):Connect(function()
		if player:GetAttribute("CrucibleResult") ~= nil then
			showResult = true
		end
		draw()
	end)
	for _, name in { "CrucibleRound", "CrucibleOdds", "AtRest", "OwnedKith" } do
		player:GetAttributeChangedSignal(name):Connect(draw)
	end
	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("CrucibleRound") ~= nil then
			draw() -- needle moves every frame
		end
	end)
	draw()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- viewport changes without attribute events
		while true do
			task.wait(0.5)
			draw()
		end
	end)
end

return CrucibleHud
