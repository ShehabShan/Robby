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
	end,
}
