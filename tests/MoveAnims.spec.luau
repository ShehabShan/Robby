local MoveAnims = require("../src/shared/MoveAnims")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["moveanims: every slot and land has a numeric asset id"] = function()
		for _, slot in MoveAnims.slots do
			eq(string.match(MoveAnims.ids[slot] or "", "^%d+$") ~= nil, true, slot)
		end
		eq(string.match(MoveAnims.ids.land, "^%d+$") ~= nil, true, "land")
		eq(MoveAnims.assetUrl("12"), "rbxassetid://12")
	end,
	["moveanims: land only after a real fall"] = function()
		eq(MoveAnims.shouldLand(5), false, "hop")
		eq(MoveAnims.shouldLand(MoveAnims.landMinFall), true, "edge")
		eq(MoveAnims.shouldLand(80), true, "drop")
		eq(MoveAnims.shouldLand(0 / 0), false, "NaN")
	end,
}
