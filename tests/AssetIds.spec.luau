--!strict
-- Uploaded art ids and fallback (T-053a2, D-384).
local AssetIds = require("../src/shared/AssetIds")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["asset ids: known keys give rbxassetid urls"] = function()
		eq(AssetIds.image("crescentSlashAdd"), "rbxassetid://122235202607884")
		for key in AssetIds.images do
			local url = AssetIds.image(key)
			assert(url and url:match("^rbxassetid://%d+$"), key)
		end
	end,
	["asset ids: missing key falls back to nil"] = function()
		eq(AssetIds.image("nope"), nil)
		eq(AssetIds.sound("nope"), nil)
	end,
	["asset ids: crescent sounds are uploaded ids (T-053a4b)"] = function()
		for _, key in { "crescentCast", "crescentHit", "crescentThud", "crescentHum" } do
			local u = AssetIds.sound(key)
			assert(u and u:match("^rbxassetid://%d+$"), key)
		end
	end,
}
