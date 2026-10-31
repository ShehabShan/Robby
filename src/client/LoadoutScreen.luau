--!strict
-- Loadout screen wiring (T-016d, D-069): draws Shared.LoadoutScreen.build() with Roblox GUI objects.
-- Open/close: the Inventory icon in the top bar, right of Roblox's chat button (all platforms), or Back/Select
-- (gamepad). Tab is left to Roblox's player list (D-213). Buttons work with mouse, touch and
-- gamepad selection (GuiService). Picks go to the server over Blink `Equip`; the server re-checks them (D-064).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LoadoutScreen = require(ReplicatedStorage.Shared.LoadoutScreen)

local Ui = {}

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

function Ui.start(built: any, net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadoutScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui
	local model = LoadoutScreen.new()
	local apply: (action: any) -> ()

	local function readState(): any
		local cam = workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local slots, uids = {}, {}
		for i = 1, tonumber(player:GetAttribute("SlotCount")) or 0 do
			local species = player:GetAttribute(`Slot{i}`)
			local k = if type(species) == "string" then built.kith[species] else nil
			slots[i] = { role = if k then k.role else nil, name = if k then species :: string else nil }
			local uid = player:GetAttribute(`Slot{i}Uid`)
			uids[i] = if type(uid) == "string" then uid else nil
		end
		local roles = {}
		for id, k in built.kith do
			roles[id] = k.role
		end
		return {
			width = size.X,
			height = size.Y,
			platform = platform(),
			refine = player:GetAttribute("RefineYield") :: number?,
			slots = slots,
			slotUids = uids,
			owned = LoadoutScreen.parseOwned(player:GetAttribute("OwnedKith")),
			roles = roles,
			selected = model.selected,
		}
	end

	local function draw()
		for _, c in root:GetChildren() do
			c:Destroy()
		end
		root.Visible = model.open
		if not model.open then
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			return
		end
		local first: GuiObject? = nil
		for i, e in LoadoutScreen.build(readState()) do
			local obj: GuiObject
			if e.kind == "button" then
				local b = Instance.new("TextButton")
				b.Text = e.text or ""
				b.TextColor3 = Color3.new(1, 1, 1)
				b.TextSize = e.textSize or 14
				b.Font = Enum.Font.GothamBold
				b.AutoButtonColor = true
				b.Selectable = true
				local action = e.action
				b.Activated:Connect(function()
					apply(action)
				end)
				obj = b
				if first == nil and e.action.kind == "pick" then
					first = b
				end
			elseif e.kind == "text" then
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Text = e.text or ""
				t.TextColor3 = rgb(e.color)
				t.TextSize = e.textSize or 14
				t.Font = Enum.Font.GothamBold
				t.TextXAlignment = if e.align == "left"
					then Enum.TextXAlignment.Left
					elseif e.align == "right" then Enum.TextXAlignment.Right
					else Enum.TextXAlignment.Center
				obj = t
			else
				obj = Instance.new("Frame")
			end
			if e.kind == "outline" then
				obj.BackgroundTransparency = 1
				local stroke = Instance.new("UIStroke")
				stroke.Color = rgb(e.color)
				stroke.Thickness = 3
				stroke.Parent = obj
			elseif e.kind ~= "text" then
				obj.BackgroundColor3 = rgb(e.color)
				obj.BackgroundTransparency = 1 - (e.alpha or 1)
			end
			obj.BorderSizePixel = 0
			obj.Name = e.id
			obj.Position = UDim2.fromOffset(e.x, e.y)
			obj.Size = UDim2.fromOffset(e.w, e.h)
			obj.ZIndex = i
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = obj
			obj.Parent = root
		end
		if platform() == "gamepad" and first and not GuiService.SelectedObject then
			GuiService.SelectedObject = first
		end
	end

	apply = function(action: any)
		local req
		model, req = LoadoutScreen.reduce(model, action, tonumber(player:GetAttribute("SlotCount")) or 1)
		if req then
			net.Equip.Fire(req)
		end
		draw()
	end

	ContextActionService:BindAction(
		"LoadoutToggle",
		function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				apply({ kind = "toggle" })
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.ButtonSelect -- Tab stays with Roblox's player/server list (D-213)
	)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)

	-- Inventory icon in Roblox's top bar, just right of the chat button, on every platform (D-213).
	-- GuiService.TopbarInset is the free top-bar strip that starts right after Roblox's own buttons.
	local open = Instance.new("TextButton")
	open.Name = "InventoryOpen"
	open.Text = "🎒"
	open.TextScaled = true
	open.Font = Enum.Font.GothamBold
	open.TextColor3 = Color3.new(1, 1, 1)
	open.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	open.BackgroundTransparency = 0.3
	open.AutoButtonColor = true
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.Parent = open
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = open
	local function place()
		local inset = GuiService.TopbarInset
		local h = if inset.Height > 0 then inset.Height else 58
		local size = math.max(LoadoutScreen.MIN_TOUCH, math.floor(h * 0.76))
		local left = if inset.Min.X > 0 then inset.Min.X else 104
		open.Size = UDim2.fromOffset(size, size)
		open.Position = UDim2.fromOffset(left, inset.Min.Y + math.floor((h - size) / 2))
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	open.Activated:Connect(function()
		apply({ kind = "toggle" })
	end)
	open.Parent = gui

	player.AttributeChanged:Connect(function()
		if model.open then
			draw()
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return Ui
