--!strict
-- Moves (SCHEMAS §5): cast checks, costs and cooldowns keyed by (caster, moveId). Pure rules. No Roblox services.
-- Each caster owns its own `cooldowns` table, so the key is effectively (caster, moveId).

export type Costs = { qi: number?, strain: number?, hp: number?, uses: number? }
export type DeliveryKind = "Projectile" | "Melee" | "Beam" | "AoE" | "Zone" | "Summon" | "Self" | "System"
export type Move = {
	id: string,
	kith: string?,
	trigger: "Press" | "Hold" | "Passive" | "OnHit" | "OnDamaged" | "System",
	target: "Aim" | "Self" | "Area" | "Lock",
	delivery: { kind: DeliveryKind, params: { [string]: any } },
	costs: Costs,
	cooldown: number,
	channel: { tick: number, maxTime: number, interruptBy: { string } }?,
	effects: { onCast: { string }?, onHit: { string }?, onEnd: { string }? },
	tags: { string },
	fx: { [string]: string },
}
export type Caster = {
	qi: number,
	strain: number,
	strainMax: number,
	hp: number,
	cooldowns: { [string]: number }, -- moveId -> ready time
	uses: { [string]: number }?, -- moveId -> times used (consumables)
}

local Moves = {}

-- Returns ok plus a reason code: "cooldown" | "badCost" | "qi" | "strain" | "hp" | "uses".
function Moves.check(c: Caster, move: Move, now: number): (boolean, string?)
	local ready = c.cooldowns[move.id]
	if ready ~= nil and ready > now then
		return false, "cooldown"
	end
	local k = move.costs
	local qi, strain, hp = k.qi or 0, k.strain or 0, k.hp or 0
	if qi < 0 or strain < 0 or hp < 0 then
		return false, "badCost"
	end
	if c.qi < qi then
		return false, "qi"
	end
	if c.strain + strain > c.strainMax then
		return false, "strain"
	end
	if hp > 0 and c.hp <= hp then
		return false, "hp" -- an HP cost never kills the caster
	end
	local limit = k.uses
	if limit ~= nil then
		local used = if c.uses then c.uses[move.id] or 0 else 0
		if used >= limit then
			return false, "uses"
		end
	end
	return true, nil
end

-- Checks, then pays every cost and starts the cooldown. Nothing changes when the check fails.
function Moves.pay(c: Caster, move: Move, now: number): (boolean, string?)
	local ok, reason = Moves.check(c, move, now)
	if not ok then
		return false, reason
	end
	local k = move.costs
	c.qi -= k.qi or 0
	c.strain += k.strain or 0
	c.hp -= k.hp or 0
	c.cooldowns[move.id] = now + move.cooldown
	if k.uses ~= nil then
		local uses = c.uses or {}
		uses[move.id] = (uses[move.id] or 0) + 1
		c.uses = uses
	end
	return true, nil
end

function Moves.remaining(c: Caster, moveId: string, now: number): number
	local ready = c.cooldowns[moveId]
	return if ready then math.max(ready - now, 0) else 0
end

return Moves
