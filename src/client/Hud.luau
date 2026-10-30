--!strict
-- HUD wiring (T-016c, D-068): draws HudLayout.build() with Roblox GUI objects.
-- Reads player attributes from Abilities (Qi, QiMax) and LoadoutService (SlotCount, Slot<i>, LoadoutGaps, D-064).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(ReplicatedStorage.Shared.HudLayout)

local Hud = {}

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

local function create(e: HudLayout.Element, parent: Instance): GuiObject
	local obj: GuiObject
	if e.kind == "text" then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextStrokeTransparency = 0.4
		obj = t
	else
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if e.kind == "dot"
			then UDim.new(0.5, 0)
			else UDim.new(0, if e.kind == "slot" then 10 else 3)
		corner.Parent = f
		if e.kind == "slot" then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Transparency = 0.3
			stroke.Thickness = 2
			stroke.Parent = f
		end
		obj = f
	end
	obj.Name = e.id
	obj.Parent = parent
	return obj
end

local function readState(player: Player, built: any): HudLayout.State
	local cam = workspace.CurrentCamera
	local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local health, healthMax = 0, 100
	local char = player.Character
	local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
	if hum then
		health, healthMax = hum.Health, hum.MaxHealth
	end
	local slots: { HudLayout.SlotState } = {}
	for i = 1, tonumber(player:GetAttribute("SlotCount")) or 0 do
		local species = player:GetAttribute(`Slot{i}`)
		local k = if type(species) == "string" then built.kith[species] else nil
		table.insert(slots, { role = if k then k.role else nil, name = if k then species :: string else nil })
	end
	local gaps = {}
	local raw = player:GetAttribute("LoadoutGaps")
	if type(raw) == "string" then
		for _, g in string.split(raw, ",") do
			if g ~= "" then
				table.insert(gaps, g)
			end
		end
	end
	return {
		width = size.X,
		height = size.Y,
		platform = platform(),
		health = health,
		healthMax = healthMax,
		qi = tonumber(player:GetAttribute("Qi")) or 0,
		qiMax = tonumber(player:GetAttribute("QiMax")) or 0,
		slots = slots,
		gaps = gaps,
	}
end

function Hud.start(built: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local pool: { [string]: GuiObject } = {}

	local function draw()
		local used: { [string]: boolean } = {}
		for i, e in HudLayout.build(readState(player, built)) do
			local obj = pool[e.id] or create(e, gui)
			pool[e.id] = obj
			used[e.id] = true
			obj.Position = UDim2.fromOffset(e.x, e.y)
			obj.Size = UDim2.fromOffset(e.w, e.h)
			obj.ZIndex = i
			obj.Visible = true
			if obj:IsA("TextLabel") then
				obj.Text = e.text or ""
				obj.TextColor3 = rgb(e.color)
				obj.TextSize = e.textSize or HudLayout.MIN_TEXT
				obj.TextXAlignment = if e.align == "left"
					then Enum.TextXAlignment.Left
					elseif e.align == "right" then Enum.TextXAlignment.Right
					else Enum.TextXAlignment.Center
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

	player.AttributeChanged:Connect(draw)
	draw()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- health, viewport and input type change without attribute events
		while true do
			task.wait(0.25)
			draw()
		end
	end)
end

return Hud
