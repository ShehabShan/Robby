--!strict
-- Weave Loom core (T-020a, D-088): checks a Weave (core move + supports), builds the woven move, works out Path
-- Friction and records the Weave in the journal. Pure; LoomService (T-020c) and LoomUi (T-020d) use it.

local Loom = {}

Loom.FRICTION_FLOOR = -0.2

local function has(tags: { string }?, t: string): boolean
	if not tags then
		return false
	end
	for _, x in tags do
		if x == t then
			return true
		end
	end
	return false
end

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

-- Can this support modify this core move? (requireTags all present, excludeTags none present)
function Loom.fits(move: any, support: any): (boolean, string?)
	for _, t in support.requireTags or {} do
		if not has(move.tags, t) then
			return false, `needs {t}`
		end
	end
	for _, t in support.excludeTags or {} do
		if has(move.tags, t) then
			return false, `not with {t}`
		end
	end
	return true, nil
end

function Loom.check(cfg: any, move: any, supports: { any }): (boolean, string?)
	if not move then
		return false, "no core move"
	end
	local max = cfg.Loom.maxSupports
	if #supports < 1 or #supports > max then
		return false, `pick 1 to {max} supports`
	end
	local seen: { [string]: boolean } = {}
	for _, s in supports do
		if seen[s.id] then
			return false, "same support twice"
		end
		seen[s.id] = true
		local ok, why = Loom.fits(move, s)
		if not ok then
			return false, why
		end
	end
	return true, nil
end

-- The woven move: a copy of the core with each support's delivery multipliers, extra on-hit effects and Qi cost.
function Loom.weave(move: any, supports: { any }, weaveId: string): any
	local m = copy(move)
	m.id = weaveId
	m.baseMove = move.id
	local mult = 1
	for _, s in supports do
		local p = m.delivery and m.delivery.params
		for k, f in s.deliveryMods or {} do
			if p and type(p[k]) == "number" then
				local v = p[k] * f
				p[k] = if math.floor(p[k]) == p[k] then math.floor(v + 0.5) else v
			end
		end
		local add = s.addEffects and s.addEffects.onHit
		if add then
			m.effects = m.effects or {}
			m.effects.onHit = m.effects.onHit or {}
			for _, e in add do
				table.insert(m.effects.onHit, e)
			end
		end
		mult *= s.costMult or 1
	end
	m.costs = m.costs or {}
	m.costs.qi = math.ceil((m.costs.qi or 0) * mult)
	m.tags = m.tags or {}
	table.insert(m.tags, "Weave")
	return m
end

-- Friction on a move of `path`: Σ frictionWith[q] × min(1, Marks in q / frictionFullMarks), floored at −20 %.
function Loom.friction(cfg: any, path: string?, marks: { [string]: number }?): number
	local def = if path then cfg.Loom.paths[path] else nil
	if not def then
		return 0
	end
	local f = 0
	for q, w in def.frictionWith do
		local m = math.max(0, (marks and marks[q]) or 0)
		f += w * math.min(1, m / cfg.Loom.frictionFullMarks)
	end
	return math.max(f, Loom.FRICTION_FLOOR)
end

-- Saves the Weave in the loadout (same id replaces) and the journal. Returns true the first time (Resonance hint).
function Loom.record(data: any, weave: { id: string, core: string, supports: { string } }, now: number): boolean
	data.journal = data.journal or {}
	data.journal.weaves = data.journal.weaves or {}
	local first = data.journal.weaves[weave.id] == nil
	if first then
		data.journal.weaves[weave.id] = now
	end
	data.loadout = data.loadout or {}
	data.loadout.weaves = data.loadout.weaves or {}
	for i, w in data.loadout.weaves do
		if w.id == weave.id then
			data.loadout.weaves[i] = weave
			return first
		end
	end
	table.insert(data.loadout.weaves, weave)
	return first
end

-- One Weave per core move (D-090): "move.crescent_cut" -> "weave.crescent_cut".
function Loom.weaveIdFor(coreId: string): string
	return "weave." .. (string.gsub(coreId, "^move%.", ""))
end

local function supportsOf(built: any, ids: { string }): { any }?
	local list = {}
	for _, id in ids do
		local s = built.supports and built.supports[id]
		if not s then
			return nil
		end
		table.insert(list, s)
	end
	return list
end

-- Sets (or replaces) the Weave on an equipped core move (`allowed` = Loadout.allowedMoves). Server rules (T-020c).
-- Returns ok, reason, first (true the first time this Weave is made: show the Resonance hint).
function Loom.set(
	data: any,
	cfg: any,
	built: any,
	allowed: { [string]: boolean },
	coreId: string,
	supportIds: { string },
	now: number
): (boolean, string?, boolean)
	local move = built.moves[coreId]
	if not move or not allowed[coreId] then
		return false, "core move not equipped", false
	end
	local supports = supportsOf(built, supportIds)
	if not supports then
		return false, "unknown support", false
	end
	local ok, why = Loom.check(cfg, move, supports)
	if not ok then
		return false, why, false
	end
	local w = { id = Loom.weaveIdFor(coreId), core = coreId, supports = table.clone(supportIds) }
	return true, nil, Loom.record(data, w, now)
end

-- Removes the Weave on `coreId` from the loadout (the journal keeps it). Returns true if one was removed.
function Loom.clear(data: any, coreId: string): boolean
	local list = data.loadout and data.loadout.weaves
	for i, w in list or {} do
		if w.core == coreId then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- The move to cast for `coreId` with its saved Weave, or nil (no Weave, or it no longer fits). The woven move keeps
-- the core id, so cooldowns, FX and the client stay keyed by the core move; `weaveId` names the Weave.
function Loom.wovenFor(cfg: any, built: any, weaves: { any }?, coreId: string): any
	local list: { any } = weaves or {}
	for _, w in list do
		if w.core == coreId then
			local move = built.moves[coreId]
			local supports = supportsOf(built, w.supports or {})
			if not move or not supports or not Loom.check(cfg, move, supports) then
				return nil
			end
			local m = Loom.weave(move, supports, w.id)
			m.weaveId = m.id
			m.id = coreId
			return m
		end
	end
	return nil
end

return Loom
