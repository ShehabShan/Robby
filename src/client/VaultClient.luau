--!strict
-- Client vault / ledge climb (T-058f, D-432): on a jump while grounded and moving, probe ahead with the
-- double-ray test (knee + head forward rays, then a ray down onto the top). `Shared.Vault` decides vault /
-- climb / normal jump and the launch velocity. Planar speed never exceeds run speed, so the server speed
-- guard needs no change. Sets character attribute `Vaulting` ("vault" | "climb") briefly for T-058c anims.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Vault = require(ReplicatedStorage.Shared.Vault)

local C: Vault.Cfg = Config.Vault
local VaultClient = {}
local lastAt = -math.huge

local function probe(character: Model, root: BasePart, hum: Humanoid): (Vault.Probe, Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local flat = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	local dir = if flat.Magnitude > 0.1
		then flat.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local feetY = root.Position.Y - (hum.HipHeight + root.Size.Y / 2)
	local function at(h: number): Vector3
		return Vector3.new(root.Position.X, feetY + h, root.Position.Z)
	end
	local knee = workspace:Raycast(at(C.vaultMin * 0.75), dir * C.reach, params)
	local head = workspace:Raycast(at(C.climbMax + 0.5), dir * C.reach, params)
	local p: Vault.Probe = { faceDist = nil, headBlocked = head ~= nil, topHeight = nil, roomAbove = false }
	if knee then
		local faceDist = (Vector3.new(knee.Position.X, 0, knee.Position.Z) - Vector3.new(
			root.Position.X,
			0,
			root.Position.Z
		)).Magnitude
		p.faceDist = faceDist
		local over = at(C.climbMax + 0.5) + dir * (faceDist + 0.6)
		local down = workspace:Raycast(over, Vector3.new(0, -(C.climbMax + 0.5), 0), params)
		if down then
			p.topHeight = down.Position.Y - feetY
			-- Standing room: nothing in the character's height above the top.
			p.roomAbove = workspace:Raycast(down.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 5, 0), params) == nil
		end
	end
	return p, dir
end

function VaultClient.start()
	UserInputService.JumpRequest:Connect(function()
		local character = Players.LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end
		if hum.FloorMaterial == Enum.Material.Air or hum.MoveDirection.Magnitude < 0.1 then
			return
		end
		local now = os.clock()
		if now - lastAt < C.cooldown then
			return
		end
		local p, dir = probe(character, root, hum)
		local kind: Vault.Kind? = Vault.classify(C, p)
		local top = p.topHeight
		if kind == nil or top == nil then
			return
		end
		local k: Vault.Kind = kind
		lastAt = now
		local v = root.AssemblyLinearVelocity
		local up, fwd = Vault.launch(C, k, top, Vector3.new(v.X, 0, v.Z).Magnitude)
		root.AssemblyLinearVelocity = dir * fwd + Vector3.new(0, up, 0)
		character:SetAttribute("Vaulting", k)
		task.delay(0.4, function()
			if character.Parent then
				character:SetAttribute("Vaulting", nil)
			end
		end)
	end)
end

return VaultClient
