local Footsteps = require("../src/shared/Footsteps")
local Sounds = require("../src/shared/FootstepSounds")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["surfaceFor: air, mapped, unknown"] = function()
		eq(Footsteps.surfaceFor("Air"), nil, "air")
		eq(Footsteps.surfaceFor("Grass"), "Grass", "grass")
		eq(Footsteps.surfaceFor("WoodPlanks"), "Wood", "planks")
		eq(Footsteps.surfaceFor("NotAMaterial"), Footsteps.FALLBACK, "fallback")
	end,
	["data: every mapped surface has sounds"] = function()
		for mat, s in Sounds.materials do
			local list = Sounds.surfaces[s]
			eq(list ~= nil and #list > 0, true, "sounds for " .. mat)
		end
		eq(Sounds.surfaces[Footsteps.FALLBACK] ~= nil, true, "fallback exists")
	end,
	["interval: still none, walk, clamped"] = function()
		eq(Footsteps.interval(0), nil, "still")
		eq(Footsteps.interval(16), 0.35, "walk")
		eq(Footsteps.interval(1000), Footsteps.MIN_INTERVAL, "fast clamp")
		eq(Footsteps.interval(3), Footsteps.MAX_INTERVAL, "slow clamp")
	end,
	["pick: in range, never repeats"] = function()
		local last: number? = nil
		for k = 0, 50 do
			local id, i = Footsteps.pick("Grass", last, (k % 10) / 10)
			eq(id ~= nil, true, "id")
			eq(i ~= last, true, "no repeat")
			eq(i >= 1 and i <= #Sounds.surfaces.Grass, true, "range")
			last = i
		end
	end,
}
