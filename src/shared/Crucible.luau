--!strict
-- Crucible fusion core (T-019a, D-081, GDD "Combine"): two bound Kith + a Shard catalyst merge into a higher-rank
-- Kith. Known recipes (in `journal.recipes`) are safe. Experimental ones show odds that the focus mini-game raises.
-- Fail = catalyst lost + one component Wounded (weaker for a day), never destroyed. Pure; wiring/UI are T-019b–d.

local Crucible = {}

export type Result = { success: boolean, outputUid: string?, woundedUid: string?, recipeId: string }

local function recipeOf(cfg: any, a: string, b: string): (string?, any)
	for id, r in cfg.Crucible.recipes do
		local x, y = r.inputs[1], r.inputs[2]
		if (x == a and y == b) or (x == b and y == a) then
			return id, r
		end
	end
	return nil, nil
end

function Crucible.wounded(inst: any, now: number): boolean
	return typeof(inst.woundedUntil) == "number" and now < inst.woundedUntil
end

-- Power multiplier from Wounded (combine with `KithCare.power` in wiring).
function Crucible.powerFactor(inst: any, cfg: any, now: number): number
	return if Crucible.wounded(inst, now) then cfg.Crucible.woundedPower else 1
end

-- Recipe for two owned Kith uids, or (nil, reason).
function Crucible.recipe(data: any, cfg: any, uidA: any, uidB: any, now: number): (string?, any)
	if type(uidA) ~= "string" or type(uidB) ~= "string" or uidA == uidB then
		return nil, "pick two different Kith"
	end
	local a, b = data.kith[uidA], data.kith[uidB]
	if not a or not b then
		return nil, "unknown Kith"
	end
	if Crucible.wounded(a, now) or Crucible.wounded(b, now) then
		return nil, "a Kith is Wounded"
	end
	if a.dormant or b.dormant then
		return nil, "a Kith is Dormant"
	end
	local id, r = recipeOf(cfg, a.speciesId, b.speciesId)
	if not id then
		return nil, "no recipe"
	end
	if ((data.wallet and data.wallet.shards) or 0) < r.catalystShards then
		return nil, "not enough Shards"
	end
	return id, r
end

-- Success chance shown before fusing; `focus` (0..1) comes from the mini-game.
function Crucible.odds(data: any, cfg: any, recipeId: string, focus: number): number
	if data.journal and data.journal.recipes and data.journal.recipes[recipeId] then
		return 1
	end
	local r = cfg.Crucible.recipes[recipeId]
	return math.clamp(r.baseChance + cfg.Crucible.focusBonus * math.clamp(focus, 0, 1), 0, cfg.Crucible.maxChance)
end

local function replaceSlots(data: any, old: string, new: string?)
	local slots = data.loadout and data.loadout.slots
	if type(slots) ~= "table" then
		return
	end
	for k, v in slots do
		if v == old then
			slots[k] = new
		end
	end
end

-- Pays the catalyst and fuses. `roll` is a server random in [0,1). Returns nil + reason when not allowed.
function Crucible.fuse(
	data: any,
	cfg: any,
	uidA: any,
	uidB: any,
	focus: number,
	roll: number,
	now: number
): (Result?, string?)
	local id, r = Crucible.recipe(data, cfg, uidA, uidB, now)
	if not id then
		return nil, r
	end
	local recipeId = id :: string
	local chance = Crucible.odds(data, cfg, recipeId, focus)
	data.wallet.shards -= r.catalystShards
	if roll >= chance then
		data.kith[uidB].woundedUntil = now + cfg.Crucible.woundedSeconds
		return { success = false, woundedUid = uidB, recipeId = recipeId }, nil
	end
	local base = "fused." .. (string.gsub(r.output, "^kith%.", ""))
	local n = 1
	while data.kith[`{base}.{n}`] do
		n += 1
	end
	local uid = `{base}.{n}`
	local heart = data.heartKith == uidA or data.heartKith == uidB
	data.kith[uidA], data.kith[uidB] = nil, nil
	data.kith[uid] = { uid = uid, speciesId = r.output }
	replaceSlots(data, uidA, uid)
	replaceSlots(data, uidB, nil)
	if heart then
		data.heartKith = uid
	end
	data.journal = data.journal or {}
	data.journal.recipes = data.journal.recipes or {}
	data.journal.recipes[recipeId] = true
	return { success = true, outputUid = uid, recipeId = recipeId }, nil
end

return Crucible
