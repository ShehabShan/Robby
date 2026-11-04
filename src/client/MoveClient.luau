--!strict
-- MoveClient (T-059c, D-468): runs `Shared.MoveRules` for the local character. Owns the jump
-- (`Config.Jump`: UseJumpPower=false, explicit JumpHeight), coyote time, the one-slot input buffer and
-- slide-jump / edge vector carry. Ground speed, slide and ground dash stay in SprintClient; their modes are
-- read from its attributes (`Sliding`, `Dashing`, `Vaulting`). Publishes `MoveMode`, `MoveConsumed`,
-- `AirDashCharges` for MoveTraceClient. Air dash (Q in air) and slam (V) are wired in T-059d/e.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MoveRules = require(Shared:WaitForChild("MoveRules"))

local T: MoveRules.Tuning = Config.MoveRules
local MAX_RAY = 50

local MoveClient = {}

local state: MoveRules.State = MoveRules.new(T)
local lastCharacter: Model? = nil
local jumpEnabled: boolean? = nil
local wantJump = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function clearance(root: BasePart, hum: Humanoid, character: Model): number
	rayParams.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -MAX_RAY, 0), rayParams)
	local feet = root.Size.Y / 2 + hum.HipHeight
	return if hit then math.max(0, root.Position.Y - hit.Position.Y - feet) else MAX_RAY
end

local function dashSeconds(kind: any): number?
	if type(kind) ~= "string" then
		return nil
	end
	local k = (Config.Dash :: any)[kind]
	return if k then k.seconds else nil
end

-- Executes a MoveRules jump ourselves (coyote / buffered / dash-jump), keeping the horizontal vector.
local function doJump(root: BasePart, hum: Humanoid, carry: boolean)
	local v = root.AssemblyLinearVelocity
	local vx, vz = v.X, v.Z
	if carry then
		vx, vz = MoveRules.carry(T, vx, vz)
	end
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	jumpEnabled = true
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	local up = math.sqrt(2 * workspace.Gravity * Config.Jump.height)
	root.AssemblyLinearVelocity = Vector3.new(vx, math.max(v.Y, up), vz)
end

local function syncModes(character: Model, grounded: boolean)
	local sliding = character:GetAttribute("Sliding") == true
	local dashing = character:GetAttribute("Dashing") ~= nil
	local vaulting = character:GetAttribute("Vaulting") ~= nil
	local m = state.mode
	if vaulting then
		if m ~= "Vault" then
			state = MoveRules.enter(T, state, "Vault")
		end
	elseif m == "Vault" then
		state = MoveRules.enter(T, state, if grounded then "Ground" else "Air")
	elseif m == "Ground" and grounded and sliding then
		state = MoveRules.enter(T, state, "Slide")
	elseif m == "Ground" and grounded and dashing then
		state = MoveRules.enter(T, state, "Dash")
	elseif m == "Slide" and grounded and not sliding then
		state = MoveRules.enter(T, state, "Ground")
	end
end

function MoveClient.start()
	UserInputService.JumpRequest:Connect(function()
		wantJump = true
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local character = Players.LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end
		if character ~= lastCharacter then
			lastCharacter = character
			state = MoveRules.new(T)
			jumpEnabled = nil
			hum.UseJumpPower = false
			hum.JumpHeight = Config.Jump.height
		end
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		local ctx: MoveRules.Context = {
			grounded = grounded,
			clearance = clearance(root, hum, character),
			stamina = (character:GetAttribute("Stamina") :: number?) or 0,
			dashSeconds = dashSeconds(character:GetAttribute("Dashing")),
		}
		syncModes(character, grounded)

		local consumed: MoveRules.Result? = nil
		local before = state.mode
		if wantJump then
			wantJump = false
			local r: MoveRules.Result?
			state, r = MoveRules.press(T, state, "jump", ctx)
			if r == "jump" then
				consumed = r
				-- a grounded Ground jump is the engine's own (same frame); slide/coyote/dash jumps we execute,
				-- keeping the horizontal vector capped (plan §2)
				if not (grounded and before == "Ground") then
					doJump(root, hum, true)
				end
			end
		end
		local fired: MoveRules.Result?
		local pre = state.mode
		state, fired = MoveRules.step(T, state, dt, ctx)
		if fired == "jump" then
			consumed = fired
			doJump(root, hum, pre == "Slide" or pre == "Dash")
		end

		-- block the engine's jump whenever MoveRules would refuse it (early dash, slam recovery)
		local allow = MoveRules.resolve(T, state, "jump", ctx) ~= nil or not grounded
		if allow ~= jumpEnabled then
			jumpEnabled = allow
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, allow)
		end
		character:SetAttribute("MoveMode", state.mode)
		character:SetAttribute("AirDashCharges", state.charges)
		if consumed then
			character:SetAttribute("MoveConsumed", consumed)
		end
	end)
end

return MoveClient
