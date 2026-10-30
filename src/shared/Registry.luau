--!strict
-- Content registry (SCHEMAS §1): validates Content records and builds id lookups. Pure rules. No Roblox services.
-- Every Content file passes `Registry.validate` in Lune tests, so broken data never reaches a server.

export type Content = { effects: { any }, moves: { any }, kith: { any }?, supports: { any }? }
export type Built = {
	effects: { [string]: any },
	moves: { [string]: any },
	kith: { [string]: any },
	supports: { [string]: any },
}

local Loadout = require("./Loadout")

local Registry = {}

Registry.DELIVERIES = {
	Projectile = true,
	Melee = true,
	Beam = true,
	AoE = true,
	Zone = true,
	Summon = true,
	Self = true,
	System = true,
}
Registry.DURATIONS = { Inst = true, Timed = true, Chan = true, Pers = true }
Registry.MIN_PERIOD = 0.5

local function index(list: { any }?, prefix: string, errors: { string }): { [string]: any }
	local map: { [string]: any } = {}
	local items: { any } = if list then list else {}
	for i, rec in items do
		local id = rec.id
		if type(id) ~= "string" or string.sub(id, 1, #prefix) ~= prefix then
			table.insert(errors, `{prefix}#{i}: id must start with "{prefix}"`)
		elseif map[id] ~= nil then
			table.insert(errors, `{id}: duplicate id`)
		else
			map[id] = rec
		end
	end
	return map
end

local function checkEffect(e: any, errors: { string })
	if not Registry.DURATIONS[e.duration] then
		table.insert(errors, `{e.id}: bad duration {tostring(e.duration)}`)
	end
	if e.duration == "Timed" and not (type(e.seconds) == "number" and e.seconds > 0) then
		table.insert(errors, `{e.id}: Timed needs seconds > 0`)
	end
	if e.period ~= nil and not (type(e.period) == "number" and e.period >= Registry.MIN_PERIOD) then
		table.insert(errors, `{e.id}: period must be >= {Registry.MIN_PERIOD}`)
	end
	if e.stack ~= nil and not (type(e.stack.cap) == "number" and e.stack.cap >= 1) then
		table.insert(errors, `{e.id}: stack cap must be >= 1`)
	end
end

local function checkMove(m: any, effects: { [string]: any }, kith: { [string]: any }, errors: { string })
	local d = m.delivery
	if type(d) ~= "table" or not Registry.DELIVERIES[d.kind] then
		table.insert(errors, `{m.id}: bad delivery`)
	end
	if not (type(m.cooldown) == "number" and m.cooldown >= 0) then
		table.insert(errors, `{m.id}: cooldown must be >= 0`)
	end
	if type(m.costs) ~= "table" then
		table.insert(errors, `{m.id}: missing costs`)
	end
	for _, slot in { "onCast", "onHit", "onEnd" } do
		for _, effectId in (m.effects or {})[slot] or {} do
			if effects[effectId] == nil then
				table.insert(errors, `{m.id}: unknown effect {effectId} in {slot}`)
			end
		end
	end
	if m.kith ~= nil and kith[m.kith] == nil then
		table.insert(errors, `{m.id}: unknown kith {m.kith}`)
	end
end

-- Weave Loom supports (T-020c, D-090): positive multipliers, known on-hit effects, at least one requireTag.
local function checkSupport(s: any, effects: { [string]: any }, errors: { string })
	if type(s.requireTags) ~= "table" or #s.requireTags < 1 then
		table.insert(errors, `{s.id}: needs requireTags`)
	end
	for k, f in s.deliveryMods or {} do
		if not (type(f) == "number" and f > 0) then
			table.insert(errors, `{s.id}: deliveryMods.{tostring(k)} must be > 0`)
		end
	end
	if s.costMult ~= nil and not (type(s.costMult) == "number" and s.costMult > 0) then
		table.insert(errors, `{s.id}: costMult must be > 0`)
	end
	for _, effectId in (s.addEffects and s.addEffects.onHit) or {} do
		if effects[effectId] == nil then
			table.insert(errors, `{s.id}: unknown effect {effectId}`)
		end
	end
end

-- Returns the lookups plus a list of errors (empty = valid).
function Registry.build(content: Content): (Built, { string })
	local errors: { string } = {}
	local effects = index(content.effects, "effect.", errors)
	local moves = index(content.moves, "move.", errors)
	local kith = index(content.kith, "kith.", errors)
	local supports = index(content.supports, "support.", errors)
	for _, e in effects do
		checkEffect(e, errors)
	end
	for _, m in moves do
		checkMove(m, effects, kith, errors)
	end
	for id, k in kith do
		if k.role ~= nil and not Loadout.isRole(k.role) then
			table.insert(errors, `{id}: unknown role {tostring(k.role)}`)
		end
		local p = k.passive
		if
			p ~= nil
			and (
				type(p) ~= "table"
				or (
					p.refineYield ~= nil
					and (typeof(p.refineYield) ~= "number" or p.refineYield < 0 or p.refineYield > 2)
				)
			)
		then
			table.insert(errors, `{id}: bad passive`)
		end
		for _, moveId in k.moves or {} do
			if moves[moveId] == nil then
				table.insert(errors, `{id}: unknown move {moveId}`)
			end
		end
	end
	for _, s in supports do
		checkSupport(s, effects, errors)
	end
	table.sort(errors)
	return { effects = effects, moves = moves, kith = kith, supports = supports }, errors
end

return Registry
