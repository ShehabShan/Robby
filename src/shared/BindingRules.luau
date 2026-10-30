--!strict
-- Binding rules around the pure duel (T-017b, D-071): who may start a bind, Shard spending, and what a
-- successful bind grants. Pure; `BindingService` is the thin server wiring.
-- A wild Kith must be weakened (health ≤ `weakenAt` of max) and within `range`. The first Kith ever bound
-- becomes the Heart Kith (`data.heartKith` = its uid) and that duel is guided, so it cannot fail (GDD "Heart").

local Binding = require("./Binding")

local BindingRules = {}

-- Returns (ok, reason). `speciesId` comes from the target's `WildKith` attribute (set by the server only).
function BindingRules.canStart(
	cfg: any,
	built: any,
	speciesId: any,
	hp: number,
	maxHp: number,
	distance: number
): (boolean, string?)
	local c = cfg.Binding
	if type(speciesId) ~= "string" or not built.kith[speciesId] then
		return false, "not a wild Kith"
	end
	if maxHp <= 0 or hp <= 0 then
		return false, "gone"
	end
	if hp / maxHp > c.weakenAt then
		return false, "not weakened"
	end
	if distance > c.range then
		return false, "too far"
	end
	return true, nil
end

-- True while the profile has no Heart Kith: the next bind is guided and becomes the Heart Kith.
function BindingRules.guided(data: any): boolean
	local h = data.heartKith
	return not (type(h) == "string" and type(data.kith) == "table" and data.kith[h] ~= nil)
end

function BindingRules.start(cfg: any, data: any, will: number, qi: number): Binding.Duel
	return Binding.new(cfg, will, qi, BindingRules.guided(data))
end

-- Spends one Shard from the wallet to refill duel Qi. False on cooldown, finished duel or no Shards.
function BindingRules.useShard(d: Binding.Duel, cfg: any, data: any, qiMax: number): boolean
	local shards = data.wallet.shards or 0
	if not Binding.useShard(d, cfg, shards, qiMax) then
		return false
	end
	data.wallet.shards = shards - 1
	return true
end

-- Adds the bound Kith to the profile with a fresh uid. Returns (uid, becameHeart).
function BindingRules.grant(data: any, speciesId: string): (string, boolean)
	local heart = BindingRules.guided(data)
	local base = "bound." .. (string.gsub(speciesId, "^kith%.", ""))
	local n = 1
	while data.kith[`{base}.{n}`] do
		n += 1
	end
	local uid = `{base}.{n}`
	data.kith[uid] = { uid = uid, speciesId = speciesId }
	if heart then
		data.heartKith = uid
	end
	return uid, heart
end

return BindingRules
