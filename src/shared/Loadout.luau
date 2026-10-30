--!strict
-- Core slots and loadout rules (T-016a; GDD "Core slots" + "Role tags"). Pure: no services, Config passed in.
-- `slots` is a dense array of Kith instance uids with "" for an empty slot, so it saves cleanly as JSON (D-063).
-- `owned` is the profile's `kith` table (uid → { speciesId }); `built` is the output of `Registry.build`.

export type Loadout = { slots: { string }, weaves: { any } }

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
function Loadout.equip(lo: any, cfg: any, rank: number, owned: any, built: any, slot: any, uid: any): (boolean, string?)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Loadout.slotCount(cfg, rank) then
		return false, "bad slot"
	end
	if speciesOf(owned, built, uid) == nil then
		return false, "not owned"
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
