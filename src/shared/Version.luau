--!strict
-- Game version (T-029, D-192). Roblox numbers place uploads itself (v16, v17, …); that counter cannot be set.
-- This is Robby's own version, shown in the HUD and printed by scripts/publish.py. Bump PATCH on every publish.

local Version = {}

Version.MAJOR = 0
Version.MINOR = 0
Version.PATCH = 17
Version.STRING = `{Version.MAJOR}.{Version.MINOR}.{Version.PATCH}`

export type Parts = { major: number, minor: number, patch: number }

-- "0.0.17" -> { major = 0, minor = 0, patch = 17 }; nil when the text is not three dot-separated integers.
function Version.parse(text: string): Parts?
	local a, b, c = string.match(text, "^v?(%d+)%.(%d+)%.(%d+)$")
	if a == nil or b == nil or c == nil then
		return nil
	end
	return { major = tonumber(a) :: number, minor = tonumber(b) :: number, patch = tonumber(c) :: number }
end

-- -1 when a < b, 0 when equal, 1 when a > b (numeric, so 0.0.9 < 0.0.17).
function Version.compare(a: Parts, b: Parts): number
	for _, k in { "major", "minor", "patch" } do
		local x, y = (a :: any)[k] :: number, (b :: any)[k] :: number
		if x ~= y then
			return if x < y then -1 else 1
		end
	end
	return 0
end

-- Text for the HUD corner, with the Roblox place version when known: "v0.0.17 (Roblox 18)".
function Version.label(placeVersion: number?): string
	if placeVersion ~= nil and placeVersion > 0 then
		return `v{Version.STRING} (Roblox {placeVersion})`
	end
	return `v{Version.STRING}`
end

return Version
