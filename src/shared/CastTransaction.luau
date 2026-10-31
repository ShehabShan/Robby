--!strict
-- T-043c0b2: non-yielding stance/payment transaction. Validation runs on private
-- copies; failed payment must not consume a chain step or a shot-2 cancel.
local Moves = require("./Moves")
local Stance = require("./Stance")

local CastTransaction = {}

function CastTransaction.pay(
	stance: Stance.State?,
	cfg: Stance.Cfg?,
	kit: Stance.Kit?,
	caster: Moves.Caster,
	move: Moves.Move,
	now: number
): (boolean, string?)
	if now ~= now or math.abs(now) == math.huge then
		return false, "clock"
	end
	local nextStance: Stance.State? = nil
	if stance ~= nil or cfg ~= nil or kit ~= nil then
		if stance == nil or cfg == nil or kit == nil then
			return false, "stance_config"
		end
		local candidate = table.clone(stance)
		candidate.chain = table.clone(stance.chain)
		nextStance = candidate
		if not Stance.verify(candidate, now, cfg, kit, move.id) then
			return false, "stance"
		end
	end
	local nextCaster = table.clone(caster)
	nextCaster.cooldowns = table.clone(caster.cooldowns)
	nextCaster.uses = if caster.uses then table.clone(caster.uses) else nil
	local ok, reason = Moves.pay(nextCaster, move, now)
	if not ok then
		return false, reason
	end
	-- Commit without yielding, preserving table identities held by the adapter.
	if stance and nextStance then
		stance.on = nextStance.on
		stance.chain.step = nextStance.chain.step
		stance.chain.lastAt = nextStance.chain.lastAt
		stance.finisherAt = nextStance.finisherAt
	end
	caster.qi = nextCaster.qi
	caster.strain = nextCaster.strain
	caster.hp = nextCaster.hp
	caster.cooldowns[move.id] = nextCaster.cooldowns[move.id]
	if nextCaster.uses then
		local uses = caster.uses or {}
		uses[move.id] = nextCaster.uses[move.id]
		caster.uses = uses
	end
	return true, nil
end

return CastTransaction
