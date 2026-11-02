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

-- Crescent Cut sounds (T-053a4b, D-389): made by `uv run scripts/make_sfx.py` (Lyria tone +
-- synthesised layers) and uploaded as Audio with `uv run scripts/upload_sounds.py` (owner user 7738981129, 2026-11-03).
-- Owner picked cast 3, hit 1, hum 1, thud 2 (D-392, research/inbox/2026-11-03-crescent-sound-pick.md).
AssetIds.sounds = {
	crescentCast = 87079460123178, -- cast-3 (owner pick, D-392)
	crescentHit = 106802928512060,
	crescentThud = 87225410328230, -- thud-2 (owner pick, D-392)
	crescentHum = 111656096434014,
} :: { [string]: number }

local function url(id: number?): string?
	if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then
		return nil
	end
	return `rbxassetid://{string.format("%d", id)}`
end

-- "rbxassetid://<id>" for a known image key, or nil (caller falls back to the code look).
function AssetIds.image(key: string): string?
	return url(AssetIds.images[key])
end

-- "rbxassetid://<id>" for a known sound key, or nil (caller falls back to a built-in rbxasset sound).
function AssetIds.sound(key: string): string?
	return url(AssetIds.sounds[key])
end

return AssetIds
