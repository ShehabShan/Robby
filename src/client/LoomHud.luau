--!strict
-- Weave Loom wiring (T-020e, D-111): draws Shared.LoomUi. At a rest spot with an equipped core move that a support
-- fits, L / D-pad Left / the Loom button opens the panel; Weave / Unweave sends Blink `WeaveSet` (support "" clears).
-- Reads `Weaves`, `WeaveResult`, `ResonanceHint`, `AtRest`, `Slot<i>` (LoomService, LoadoutService). Server decides.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local All = require(ReplicatedStorage.Shared.Content.All)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local LoomUi = require(ReplicatedStorage.Shared.LoomUi)
local Registry = require(ReplicatedStorage.Shared.Registry)

local built = Registry.build(All.content(Config))

local LoomHud = {}

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

function LoomHud.start(net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Loom"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	local pool: { [string]: GuiObject } = {}
	local open = false
	local acted = false
	local resonance = false

	local function equipped(): { string }
		local list = {}
		for i = 1, (tonumber(player:GetAttribute("SlotCount")) or 0) do
			local sp = player:GetAttribute(`Slot{i}`)
			if type(sp) == "string" then
				table.insert(list, sp)
			end
		end
		return list
	end
	local function pick(): (string?, string?)
		return LoomUi.pickCore(built, equipped())
	end
	local function canOpen(): boolean
		local core = pick()
		return player:GetAttribute("AtRest") == true and core ~= nil
	end
	local function woven(core: string): boolean
		local attr = player:GetAttribute("Weaves")
		return LoomUi.parseWeaves(if type(attr) == "string" then attr else nil)[core] ~= nil
	end
	local function act()
		local core, support = pick()
		if not core or not support then
			return
		end
		acted, resonance = true, false
		net.WeaveSet.Fire({ core = core, support = if woven(core) then "" else support })
	end
	local function close()
		open, acted, resonance = false, false, false
	end
	local function state(): LoomUi.State?
		local core, support = pick()
		local v = if core and support then LoomUi.view(Config, built, core, support, nil) else nil
		if not core or not v then
			return nil
		end
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local res = player:GetAttribute("WeaveResult")
		return {
			width = math.floor(size.X),
			height = math.floor(size.Y),
			platform = platform(),
			core = v.core,
			support = v.support,
			fits = v.fits,
			why = v.why,
			qiBefore = v.qiBefore,
			qiAfter = v.qiAfter,
			friction = v.friction,
			boost = v.boost,
			woven = woven(core),
			result = if acted and type(res) == "string" then res else nil,
			resonance = resonance,
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
			b.Activated:Connect(act)
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
	-- Small "Loom" opener / closer for touch and mouse at a rest spot (above the Crucible opener).
	local opener = Instance.new("TextButton")
	opener.Name = "loomOpen"
	opener.AnchorPoint = Vector2.new(1, 1)
	opener.Position = UDim2.new(1, -12, 1, -232)
	opener.Size = UDim2.fromOffset(120, 44)
	opener.Font = Enum.Font.GothamBold
	opener.TextSize = 16
	opener.TextColor3 = Color3.new(1, 1, 1)
	opener.BackgroundColor3 = Color3.fromRGB(60, 80, 150)
	opener.Visible = false
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0, 10)
	oc.Parent = opener
	opener.Parent = gui
	local draw: () -> ()
	opener.Activated:Connect(function()
		if open then
			close()
		else
			open = true
		end
		draw()
	end)
	draw = function()
		if open and player:GetAttribute("AtRest") ~= true then
			close()
		end
		local s = if open then state() else nil
		opener.Visible = canOpen()
		opener.Text = if open then "Close" else "Loom"
		local used: { [string]: boolean } = {}
		if s then
			for i, e in LoomUi.build(s) do
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
	-- Closed → open; open → Weave / Unweave; after a result → close.
	ContextActionService:BindAction("Loom", function(_, s: Enum.UserInputState, _): Enum.ContextActionResult
		if s ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if not open then
			open = canOpen()
		elseif acted then
			close()
		else
			act()
		end
		draw()
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.L, Enum.KeyCode.DPadLeft)
	player:GetAttributeChangedSignal("ResonanceHint"):Connect(function()
		resonance = acted and player:GetAttribute("ResonanceHint") ~= nil
		draw()
	end)
	for _, name in { "WeaveResult", "Weaves", "AtRest", "SlotCount", "Slot1", "Slot2", "Slot3" } do
		player:GetAttributeChangedSignal(name):Connect(draw)
	end
	draw()
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(function() -- viewport changes without attribute events
		while true do
			task.wait(0.5)
			draw()
		end
	end)
end

return LoomHud
