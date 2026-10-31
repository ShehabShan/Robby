--!strict
-- Core slots and loadout rules (T-016a; GDD "Core slots" + "Role tags"). Pure: no services, Config passed in.
-- `slots` is a dense array of Kith instance uids with "" for an empty slot, so it saves cleanly as JSON (D-063).
-- `owned` is the profile's `kith` table (uid → { speciesId }); `built` is the output of `Registry.build`.

export type Loadout = { slots: { string }, weaves: { any } }

local KithCare = require("./KithCare")

local Loadout = {}

-- The six GDD roles. The loadout screen warns about missing roles from `Config.Loadout.warnRoles`.
Loadout.ROLES = { "Strike", "Guard", "Mend", "Carry", "Stride", "Seek" }

local ROLE_SET: { [string]: boolean } = {}
for _, r in Loadout.ROLES do
	ROLE_SET[r] = true
end

function Loadout.isRole(role: any): boolean
	return type(role) == "string" and ROLE_SET[role] == true
end

-- 3 slots at Rank 1, +1 per Rank, capped (7 in Mortal).
function Loadout.slotCount(cfg: any, rank: number): number
	local c = cfg.Loadout
	local r = math.max(1, math.floor(rank))
	return math.min(c.maxSlots, c.baseSlots + (r - 1) * c.slotsPerRank)
end

local function speciesOf(owned: any, built: any, uid: any): any
	if type(uid) ~= "string" or uid == "" then
		return nil
	end
	local inst = owned[uid]
	if type(inst) ~= "table" then
		return nil
	end
	return built.kith[inst.speciesId]
end

-- Fixes a loaded loadout in place: slot count for the rank, only owned live Kith, no duplicates.
-- Returns one issue string per fix.
function Loadout.sanitize(lo: any, cfg: any, rank: number, owned: any, built: any): { string }
	local issues: { string } = {}
	if type(lo.slots) ~= "table" then
		lo.slots = {}
		table.insert(issues, "slots: missing (reset)")
	end
	if type(lo.weaves) ~= "table" then
		lo.weaves = {}
	end
	local n = Loadout.slotCount(cfg, rank)
	local seen: { [string]: boolean } = {}
	local out: { string } = table.create(n, "")
	for i = 1, n do
		local uid = lo.slots[i]
		if uid ~= nil and uid ~= "" then
			if speciesOf(owned, built, uid) == nil then
				table.insert(issues, `slot {i}: {tostring(uid)} not owned or unknown (cleared)`)
			elseif seen[uid] then
				table.insert(issues, `slot {i}: {uid} duplicate (cleared)`)
			else
				seen[uid] = true
				out[i] = uid
			end
		end
	end
	for k, uid in lo.slots do
		if (type(k) ~= "number" or k > n) and uid ~= "" then
			table.insert(issues, `slot {tostring(k)}: over the Rank limit (removed)`)
		end
	end
	lo.slots = out
	return issues
end

-- Puts Kith `uid` into `slot`. Moving an equipped Kith frees its old slot.
-- With `now` (server), a Dormant or Exhausted Kith is refused: feed or rest it first (T-039b, D-225).
function Loadout.equip(
	lo: any,
	cfg: any,
	rank: number,
	owned: any,
	built: any,
	slot: any,
	uid: any,
	now: number?
): (boolean, string?)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Loadout.slotCount(cfg, rank) then
		return false, "bad slot"
	end
	if speciesOf(owned, built, uid) == nil then
		return false, "not owned"
	end
	local inst = owned[uid]
	if now ~= nil and type(inst) == "table" and cfg.Upkeep then
		KithCare.ensure(inst, cfg)
		if not KithCare.usable(inst, cfg, now) then
			return false, "feed first"
		end
	end
	for i, other in lo.slots do
		if other == uid and i ~= slot then
			lo.slots[i] = ""
		end
	end
	for i = #lo.slots + 1, slot - 1 do
		lo.slots[i] = ""
	end
	lo.slots[slot] = uid
	return true, nil
end

function Loadout.unequip(lo: any, slot: any): boolean
	if type(slot) ~= "number" or lo.slots[slot] == nil then
		return false
	end
	lo.slots[slot] = ""
	return true
end

-- Slot selection (T-036a, D-216): the player selects one core slot; only that slot's Kith is live. `slot` is checked
-- against the Rank's slot count; nil for anything else.
function Loadout.selectSlot(cfg: any, rank: number, slot: any): number?
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Loadout.slotCount(cfg, rank) then
		return nil
	end
	return slot
end

-- The species in the selected slot (its stance and moves are live), or nil for an empty slot.
function Loadout.activeKith(lo: any, owned: any, built: any, slot: number): string?
	local k = speciesOf(owned, built, lo.slots[slot])
	return if k then k.id else nil
end

-- The moves the player may cast now: the selected Kith's moves plus `cfg.Loadout.fixedMoves` whose Kith is equipped
-- anywhere (Wind Step stays on R, owner, D-217). The server refuses casts outside this set.
function Loadout.liveMoves(lo: any, owned: any, built: any, cfg: any, slot: number): { [string]: boolean }
	local live: { [string]: boolean } = {}
	local k = speciesOf(owned, built, lo.slots[slot])
	if k then
		for _, id in k.moves or {} do
			live[id] = true
		end
	end
	local allowed = Loadout.allowedMoves(lo, owned, built)
	for _, id in cfg.Loadout.fixedMoves do
		if allowed[id] then
			live[id] = true
		end
	end
	return live
end

function Loadout.canCastLive(lo: any, owned: any, built: any, cfg: any, slot: number, moveId: string): boolean
	return Loadout.liveMoves(lo, owned, built, cfg, slot)[moveId] == true
end

-- Kith species records in slot order (empty and unknown slots skipped).
function Loadout.equipped(lo: any, owned: any, built: any): { any }
	local list = {}
	for _, uid in lo.slots do
		local k = speciesOf(owned, built, uid)
		if k then
			table.insert(list, k)
		end
	end
	return list
end

function Loadout.roleCounts(lo: any, owned: any, built: any): { [string]: number }
	local counts: { [string]: number } = {}
	for _, k in Loadout.equipped(lo, owned, built) do
		if k.role then
			counts[k.role] = (counts[k.role] or 0) + 1
		end
	end
	return counts
end

-- Roles from `Config.Loadout.warnRoles` with nothing equipped, in Config order.
function Loadout.gaps(lo: any, owned: any, built: any, cfg: any): { string }
	local counts = Loadout.roleCounts(lo, owned, built)
	local missing: { string } = {}
	for _, role in cfg.Loadout.warnRoles do
		if not counts[role] then
			table.insert(missing, role)
		end
	end
	return missing
end

-- Server load step (T-016b): a profile with no Kith gets the starter Kith; the loadout is sanitized; an
-- all-empty loadout is filled from owned Kith (uid order). Mutates `data` in place; returns sanitize issues.
function Loadout.prepare(data: any, cfg: any, built: any): { string }
	if type(data.kith) ~= "table" then
		data.kith = {}
	end
	local starterUids: { string }? = nil
	if next(data.kith) == nil then
		local list: { string } = {}
		for _, speciesId in cfg.Loadout.starter do
			if built.kith[speciesId] then
				local uid = "starter." .. (string.gsub(speciesId, "^kith%.", ""))
				data.kith[uid] = { uid = uid, speciesId = speciesId }
				table.insert(list, uid)
			end
		end
		starterUids = list
	end
	-- One-time gifts (D-195): an existing profile gets each gift species once if it owns none of it.
	if type(data.gifts) ~= "table" then
		data.gifts = {}
	end
	for _, speciesId in cfg.Loadout.gifts or {} do
		if built.kith[speciesId] and not data.gifts[speciesId] then
			data.gifts[speciesId] = true
			local has = false
			for _, k in data.kith do
				if type(k) == "table" and k.speciesId == speciesId then
					has = true
					break
				end
			end
			if not has then
				local uid = "gift." .. (string.gsub(speciesId, "^kith%.", ""))
				data.kith[uid] = { uid = uid, speciesId = speciesId }
			end
		end
	end
	if type(data.loadout) ~= "table" then
		data.loadout = { slots = {}, weaves = {} }
	end
	local lo = data.loadout
	local issues = Loadout.sanitize(lo, cfg, data.rank or 1, data.kith, built)
	if #Loadout.equipped(lo, data.kith, built) == 0 then
		local uids: { string } = starterUids or {}
		if not starterUids then
			for uid in data.kith do
				if speciesOf(data.kith, built, uid) then
					table.insert(uids, uid)
				end
			end
			table.sort(uids)
		end
		for i, uid in uids do
			if i > #lo.slots then
				break
			end
			lo.slots[i] = uid
		end
	end
	-- Gifts go into slot 1 once (D-211): an unequipped gift is unreachable for players who never open the loadout
	-- screen (S56: the owner could not find the Rimeshard stance). Later unequips are respected.
	if type(data.giftsEquipped) ~= "table" then
		data.giftsEquipped = {}
	end
	for _, speciesId in cfg.Loadout.gifts or {} do
		if built.kith[speciesId] and not data.giftsEquipped[speciesId] then
			data.giftsEquipped[speciesId] = true
			local already = false
			for _, k in Loadout.equipped(lo, data.kith, built) do
				if k.id == speciesId then
					already = true
					break
				end
			end
			local uid: string? = nil
			if not already then
				local giftUid = "gift." .. (string.gsub(speciesId, "^kith%.", ""))
				local g = data.kith[giftUid]
				if type(g) == "table" and g.speciesId == speciesId then
					uid = giftUid
				else
					for u, k in data.kith do
						if type(k) == "table" and k.speciesId == speciesId then
							uid = u
							break
						end
					end
				end
			end
			if uid then
				local n = Loadout.slotCount(cfg, data.rank or 1)
				local len = math.min(n, math.max(#lo.slots, 1))
				local slots: { string } = { uid }
				for _, other in lo.slots do
					if #slots >= len then
						break
					end
					if other ~= "" and other ~= uid then
						table.insert(slots, other)
					end
				end
				for i = #slots + 1, len do
					slots[i] = ""
				end
				lo.slots = slots
			end
		end
	end
	return issues
end

-- True when `moveId` belongs to an equipped Kith.
function Loadout.canCast(lo: any, owned: any, built: any, moveId: string): boolean
	return Loadout.allowedMoves(lo, owned, built)[moveId] == true
end

-- The set of move ids the equipped Kith grant. The server refuses casts outside it (T-016b).
function Loadout.allowedMoves(lo: any, owned: any, built: any): { [string]: boolean }
	local allowed: { [string]: boolean } = {}
	for _, k in Loadout.equipped(lo, owned, built) do
		for _, moveId in k.moves or {} do
			allowed[moveId] = true
		end
	end
	return allowed
end

return Loadout
