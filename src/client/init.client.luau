--!strict
-- Client entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md): input, effects, Qi readout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityInput = require(script.AbilityInput)
local CrescentFx = require(script.CrescentFx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest") :: RemoteEvent
local castFx = remotes:WaitForChild("CastFx") :: RemoteEvent
local hitFx = remotes:WaitForChild("HitFx") :: RemoteEvent

AbilityInput.start(castRequest)

castFx.OnClientEvent:Connect(function(caster: Player, origin: Vector3, dir: Vector3)
	if caster == player then
		return -- the caster already played it locally
	end
	local character = caster.Character
	if character then
		CrescentFx.swipe(character)
	end
	CrescentFx.crescent(origin, dir)
end)

hitFx.OnClientEvent:Connect(function(caster: Player, target: Model?, amount: number, position: Vector3)
	CrescentFx.hit(caster, target, amount, position)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "QiHud"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -90)
label.Size = UDim2.fromOffset(180, 28)
label.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
label.BackgroundTransparency = 0.4
label.TextColor3 = Color3.fromRGB(150, 205, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.Parent = gui

local function refresh()
	label.Text = string.format(
		"Qi %s / %s",
		tostring(player:GetAttribute("Qi") or "-"),
		tostring(player:GetAttribute("QiMax") or "-")
	)
end
player:GetAttributeChangedSignal("Qi"):Connect(refresh)
player:GetAttributeChangedSignal("QiMax"):Connect(refresh)
refresh()
gui.Parent = player:WaitForChild("PlayerGui")
