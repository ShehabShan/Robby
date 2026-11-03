--!strict
-- Aim direction for casts and attacks (D-067). With shift lock on, aim where the character faces (D-164). Otherwise with mouse and keyboard, aim at the mouse pointer: the pointer ray
-- meets the horizontal plane at the character's root. Touch and gamepad keep the camera look direction.
-- The server still validates every aim.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local ShiftLock = require(ReplicatedStorage.Shared.ShiftLock)

local AIM_MAX = 500 -- studs the aim ray searches the world
local MIN_AIM_DIST = 4 -- closer aim points fall back to flat aim

local MOUSE_INPUTS = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Keyboard] = true,
}

local AimDir = {}

function AimDir.look(camera: Camera): Vector3
	local fallback = camera.CFrame.LookVector
	-- Shift lock (D-164): aim where the character faces.
	if Players.LocalPlayer:GetAttribute("ShiftLock") == true then
		local c = Players.LocalPlayer.Character
		local r = if c then c:FindFirstChild("HumanoidRootPart") else nil
		if r and r:IsA("BasePart") then
			local x, z, ok = ShiftLock.flatAim(r.CFrame.LookVector.X, r.CFrame.LookVector.Z)
			if ok then
				return Vector3.new(x, 0, z)
			end
		end
	end
	if not UserInputService.MouseEnabled or not MOUSE_INPUTS[UserInputService:GetLastInputType()] then
		return fallback
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return fallback
	end
	local pos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local target = ray.Origin + ray.Direction * 500
	if math.abs(ray.Direction.Y) > 1e-3 then
		local t = (root.Position.Y - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			target = ray.Origin + ray.Direction * t
		end
	end
	local d = target - root.Position
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 0.5 then
		return fallback
	end
	return flat.Unit
end

-- Free 3D aim (T-053a1, D-383): direction from the blade origin to the world point under the mouse
-- (screen centre under shift lock / LockCenter, gamepad and touch). Removes camera-vs-shoulder parallax.
-- Falls back to the flat direction when the point is too close or behind. The server re-clamps the pitch.
function AimDir.free(camera: Camera, character: Model, origin: Vector3, flat: Vector3, maxPitchDeg: number): Vector3
	local useMouse = UserInputService.MouseEnabled
		and MOUSE_INPUTS[UserInputService:GetLastInputType()] == true
		and Players.LocalPlayer:GetAttribute("ShiftLock") ~= true
		and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
	local ray: Ray
	if useMouse then
		local m = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(m.X, m.Y)
	else
		local s = camera.ViewportSize
		ray = camera:ViewportPointToRay(s.X / 2, s.Y / 2)
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { character }
	rp.RespectCanCollide = true -- FX parts are non-collidable
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * AIM_MAX, rp)
	local p = if hit then hit.Position else ray.Origin + ray.Direction.Unit * AIM_MAX
	-- Beasts and players have non-collidable parts, so the world ray passes through them and aims at the
	-- ground behind (T-053a7, D-393). A second ray that sees every part snaps the aim to a living target's
	-- root when one is under the cursor in front of the world hit, so low (Mistfang) and airborne targets are hit.
	local tp = RaycastParams.new()
	tp.FilterType = Enum.RaycastFilterType.Exclude
	tp.FilterDescendantsInstances = { character }
	tp.RespectCanCollide = false
	local reach = if hit then hit.Distance + 0.5 else AIM_MAX
	for _ = 1, 6 do
		local th = workspace:Raycast(ray.Origin, ray.Direction.Unit * reach, tp)
		if not th then
			break
		end
		local model = th.Instance:FindFirstAncestorOfClass("Model")
		local hum = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local troot = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if hum and hum.Health > 0 and troot and troot:IsA("BasePart") then
			p = troot.Position
			break
		end
		local ex = tp.FilterDescendantsInstances
		table.insert(ex, th.Instance)
		tp.FilterDescendantsInstances = ex
	end
	local dx, dy, dz, ok = Aim.toPoint(origin.X, origin.Y, origin.Z, p.X, p.Y, p.Z, flat.X, flat.Z, MIN_AIM_DIST)
	if not ok then
		return flat
	end
	local x, y, z, okClamp = Aim.clampPitch(dx, dy, dz, maxPitchDeg)
	return if okClamp then Vector3.new(x, y, z) else flat
end

return AimDir
