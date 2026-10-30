--!strict
-- Aim direction for casts and attacks (D-067). With mouse and keyboard, aim at the mouse pointer: the pointer ray
-- meets the horizontal plane at the character's root. Touch and gamepad keep the camera look direction.
-- The server still validates every aim.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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

return AimDir
