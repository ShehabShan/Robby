--!strict
-- Qi pool (the energy stored in a caster's Core): pure rules. No Roblox services.

export type Pool = {
	current: number,
	max: number,
	regenRate: number,
}

local Qi = {}

function Qi.new(max: number, regenRate: number): Pool
	return { current = max, max = max, regenRate = regenRate }
end

-- Refills by regenRate * dt, capped at max. A negative dt does nothing.
function Qi.regen(p: Pool, dt: number)
	if dt <= 0 then
		return
	end
	p.current = math.min(p.max, p.current + p.regenRate * dt)
end

function Qi.canSpend(p: Pool, amount: number): boolean
	return amount >= 0 and p.current >= amount
end

-- Spends amount if possible. Returns whether it was spent.
function Qi.spend(p: Pool, amount: number): boolean
	if not Qi.canSpend(p, amount) then
		return false
	end
	p.current -= amount
	return true
end

return Qi
