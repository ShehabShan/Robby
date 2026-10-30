--!strict
-- Shift lock (T-026e, D-164): pure. While on, the character faces the camera's yaw and attacks/abilities aim
-- where the character faces (not the mouse). Toggle is client-side (LeftControl); the server still validates aim.
local ShiftLock = {}

-- Over-the-shoulder camera offset (studs, right of the character) while locked.
ShiftLock.SHOULDER_X = 1.75

-- Yaw (radians) for CFrame.Angles(0, yaw, 0) so the character faces the flat look direction; nil if near vertical.
function ShiftLock.yaw(lx: number, lz: number): number?
	if lx * lx + lz * lz < 1e-4 then
		return nil
	end
	return math.atan2(-lx, -lz)
end

-- Flat unit aim from the character's facing; ok = false if it has no horizontal part.
function ShiftLock.flatAim(fx: number, fz: number): (number, number, boolean)
	local m = math.sqrt(fx * fx + fz * fz)
	if m < 1e-2 then
		return 0, 0, false
	end
	return fx / m, fz / m, true
end

return ShiftLock
