--!strict
-- Uploaded Roblox asset ids for owner art (T-053a2, D-384). Pure data. No Roblox services.
-- Uploaded with `uv run scripts/upload_images.py` (Open Cloud, assetType Decal, owner user 7738981129, 2026-11-03)
-- from `assets/processed/` (made by `uv run scripts/process_vfx.py`). "-add" = opaque on black, use with
-- LightEmission = 1; "-alpha" = luminance alpha. A missing id means: keep the code-built look (fallback).
-- UNVERIFIED until the first in-engine load (T-053a3): whether each id is directly usable as a texture.

local AssetIds = {}

AssetIds.images = {
	crescentSlashAdd = 122235202607884,
	crescentSlashAlpha = 86498794245239,
	crescentHitAdd = 128970868556906,
	crescentHitAlpha = 135269368271025,
	iconCrescentCut = 92123394268450,
} :: { [string]: number }

-- "rbxassetid://<id>" for a known image key, or nil (caller falls back to the code look).
function AssetIds.image(key: string): string?
	local id = AssetIds.images[key]
	if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
		return nil
	end
	return `rbxassetid://{string.format("%d", id)}`
end

return AssetIds
