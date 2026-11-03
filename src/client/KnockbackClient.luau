--!strict
-- Applies server knocks to the local character (T-057c3, D-419). The client owns its own root, so the
-- server writes KnockX/KnockZ/KnockAt (server time) on the character; we apply each fresh knock once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerHitReact = require(ReplicatedStorage.Shared.PlayerHitReact)

local KnockbackClient = {}

local function bind(character: Model)
	local lastAt: number? = nil
	character:GetAttributeChangedSignal("KnockAt"):Connect(function()
		local k = PlayerHitReact.toApply(
			character:GetAttribute("KnockX"),
			character:GetAttribute("KnockZ"),
			character:GetAttribute("KnockAt"),
			workspace:GetServerTimeNow(),
			lastAt
		)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not k or not root or not root:IsA("BasePart") then
			return
		end
		lastAt = k.at
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(k.x, math.max(v.Y, 8), k.z) -- small hop so floor friction doesn't eat it
	end)
end

function KnockbackClient.start()
	local player = Players.LocalPlayer
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
end

return KnockbackClient
