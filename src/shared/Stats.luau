--!strict
-- Attribute aggregation (SCHEMAS §2, R-022): the one formula every stat uses. Pure rules. No Roblox services.
-- value = (base + ΣAdd) × (1 + ΣBoost) × min(ΠSurge, SURGE_CAP); Override (last wins) replaces it; then caps.

export type Bucket = "Add" | "Boost" | "Surge" | "Override"
export type Modifier = { attr: string, bucket: Bucket, value: number, requireTags: { string }? }
export type Caps = { min: number?, max: number? }
export type HasTags = (tags: { string }) -> boolean

local Stats = {}

Stats.SURGE_CAP = 3

local function applies(mod: Modifier, attr: string, hasTags: HasTags?): boolean
	if mod.attr ~= attr then
		return false
	end
	if mod.requireTags and #mod.requireTags > 0 then
		return hasTags ~= nil and hasTags(mod.requireTags)
	end
	return true
end

function Stats.compute(attr: string, base: number, mods: { Modifier }, hasTags: HasTags?, caps: Caps?): number
	local add, boost, surge = 0, 0, 1
	local override: number? = nil
	for _, mod in mods do
		if applies(mod, attr, hasTags) then
			if mod.bucket == "Add" then
				add += mod.value
			elseif mod.bucket == "Boost" then
				boost += mod.value
			elseif mod.bucket == "Surge" then
				surge *= mod.value
			else
				override = mod.value
			end
		end
	end
	local value = (base + add) * (1 + boost) * math.min(surge, Stats.SURGE_CAP)
	if override ~= nil then
		value = override
	end
	if caps then
		if caps.min ~= nil then
			value = math.max(value, caps.min)
		end
		if caps.max ~= nil then
			value = math.min(value, caps.max)
		end
	end
	return value
end

-- Rebuilds every attribute from base values (saves never hold derived numbers, D-047).
function Stats.computeAll(
	bases: { [string]: number },
	mods: { Modifier },
	hasTags: HasTags?,
	caps: { [string]: Caps }?
): { [string]: number }
	local out: { [string]: number } = {}
	for attr, base in bases do
		out[attr] = Stats.compute(attr, base, mods, hasTags, caps and caps[attr])
	end
	return out
end

return Stats
