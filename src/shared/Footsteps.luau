--!strict
-- Footstep logic (T-026b2, D-162): pure. Material name → surface, step interval from speed, and a
-- no-repeat sound pick. Data lives in `Shared.FootstepSounds`. No game services here.
local Sounds = require("./FootstepSounds")

local Footsteps = {}

Footsteps.FALLBACK = "Concrete"
Footsteps.MIN_INTERVAL = 0.22
Footsteps.MAX_INTERVAL = 0.6
Footsteps.WALK_INTERVAL = 0.35 -- seconds per step at REF_SPEED
Footsteps.REF_SPEED = 16
Footsteps.MIN_SPEED = 1 -- below this, no steps

-- Surface for a `Enum.Material` name; nil in the air.
function Footsteps.surfaceFor(materialName: string): string?
	if materialName == "Air" then
		return nil
	end
	return Sounds.materials[materialName] or Footsteps.FALLBACK
end

-- Seconds between steps at a planar speed (studs/s); nil when standing still.
function Footsteps.interval(speed: number): number?
	if speed < Footsteps.MIN_SPEED then
		return nil
	end
	local t = Footsteps.WALK_INTERVAL * (Footsteps.REF_SPEED / speed)
	return math.clamp(t, Footsteps.MIN_INTERVAL, Footsteps.MAX_INTERVAL)
end

-- Pick a sound for `surface` with roll r in [0, 1); never repeats `last` when there is a choice.
function Footsteps.pick(surface: string, last: number?, r: number): (string?, number)
	local list = Sounds.surfaces[surface] or Sounds.surfaces[Footsteps.FALLBACK]
	local n = if list then #list else 0
	if n == 0 then
		return nil, 0
	end
	if n == 1 then
		return list[1], 1
	end
	if last and last >= 1 and last <= n then
		local j = math.clamp(1 + math.floor(r * (n - 1)), 1, n - 1)
		if j >= last then
			j += 1
		end
		return list[j], j
	end
	local i = math.clamp(1 + math.floor(r * n), 1, n)
	return list[i], i
end

return Footsteps
