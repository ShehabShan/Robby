--!strict
-- Owner-only admin panel (T-054c, D-401). F2 toggles it, but only while the server has set `IsAdmin` on this
-- player; the server still re-checks every `AdminRequest` (AdminService, D-400), so this UI grants nothing itself.
-- Shows the last `AdminResult` and the owned Kith from `AdminKith` ("uid|speciesId,..."). Everything granted here
-- is test-only and removed by "Clean up test grants".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local AdminRules = require(ReplicatedStorage.Shared.AdminRules)

local AdminPanel = {}

local function button(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.Text = text
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

local function label(parent: Instance, text: string, order: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 20)
	t.LayoutOrder = order
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(255, 220, 120)
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = text
	t.Parent = parent
	return t
end

local function box(parent: Instance, placeholder: string, text: string, order: number): TextBox
	local b = Instance.new("TextBox")
	b.Size = UDim2.new(1, 0, 0, 24)
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.PlaceholderText = placeholder
	b.Text = text
	b.ClearTextOnFocus = false
	b.Parent = parent
	return b
end

function AdminPanel.start(built: any, net: any)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(0, 300, 0.8, 0)
	frame.Position = UDim2.new(1, -310, 0.1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	frame.BackgroundTransparency = 0.1
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.ScrollBarThickness = 6
	frame.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 6), UDim.new(0, 12), UDim.new(0, 6)
	pad.Parent = frame

	local function send(req: any)
		net.AdminRequest.Fire(req)
	end

	label(frame, "ADMIN (test only) — F2 to close", 1)
	local result = label(frame, "", 2)
	local order = 10
	local function nextOrder(): number
		order += 1
		return order
	end

	label(frame, "Give Kith (any rank):", nextOrder())
	for _, s in AdminRules.species(built) do
		button(frame, `+ {string.gsub(s.id, "^kith%.", "")}  (Rank {s.rank})`, nextOrder(), function()
			send({ action = "giveKith", speciesId = s.id })
		end)
	end

	label(frame, "Owned Kith (tap to remove):", nextOrder())
	local owned = Instance.new("Frame")
	owned.Size = UDim2.fromScale(1, 0)
	owned.AutomaticSize = Enum.AutomaticSize.Y
	owned.BackgroundTransparency = 1
	owned.LayoutOrder = nextOrder()
	owned.Parent = frame
	local ownedList = Instance.new("UIListLayout")
	ownedList.Padding = UDim.new(0, 2)
	ownedList.Parent = owned

	button(frame, "Refill Qi + reset cooldowns", nextOrder(), function()
		send({ action = "refill" })
	end)

	local amount = box(frame, "amount", "100", nextOrder())
	button(frame, "Add shards (negative removes)", nextOrder(), function()
		send({ action = "addShards", amount = tonumber(amount.Text) })
	end)
	local foodSeen: { [string]: boolean } = {}
	for _, k in built.kith do
		if type(k.food) == "string" and not foodSeen[k.food] then
			foodSeen[k.food] = true
			local food = k.food
			button(frame, `Add {food}`, nextOrder(), function()
				send({ action = "addFood", foodId = food, amount = tonumber(amount.Text), rare = false })
			end)
			button(frame, `Add {food} (rare)`, nextOrder(), function()
				send({ action = "addFood", foodId = food, amount = tonumber(amount.Text), rare = true })
			end)
		end
	end

	local dist =
		box(frame, `distance {Config.Admin.spawnDistance.min}-{Config.Admin.spawnDistance.max}`, "12", nextOrder())
	for kind, k in Config.Beasts.kinds :: { [string]: any } do
		button(frame, `Spawn {k.name} in front`, nextOrder(), function()
			send({ action = "spawnBeast", kind = kind, distance = tonumber(dist.Text) })
		end)
	end

	button(frame, "Clean up test grants", nextOrder(), function()
		send({ action = "cleanup" })
	end)

	local function redrawOwned()
		for _, c in owned:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local raw = player:GetAttribute("AdminKith")
		if type(raw) ~= "string" then
			return
		end
		for i, pair in string.split(raw, ",") do
			local uid, species = string.match(pair, "^([^|]+)|(.+)$")
			if uid and species then
				button(owned, `- {uid}  ({species})`, i, function()
					send({ action = "removeKith", uid = uid })
				end)
			end
		end
	end
	player:GetAttributeChangedSignal("AdminKith"):Connect(redrawOwned)
	player:GetAttributeChangedSignal("AdminResult"):Connect(function()
		local r = player:GetAttribute("AdminResult")
		result.Text = if type(r) == "string" then r else ""
	end)
	player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") ~= true then
			gui.Enabled = false
		end
	end)
	redrawOwned()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.F2 then
			return
		end
		if player:GetAttribute("IsAdmin") ~= true then
			return -- non-admins never see the panel; the server would refuse them anyway
		end
		gui.Enabled = not gui.Enabled
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

return AdminPanel
