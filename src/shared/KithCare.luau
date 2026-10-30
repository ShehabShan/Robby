--!strict
-- Kith Upkeep (Satiety) and Strain (T-018a, D-073, GDD "Feed" / "Rest"). Pure: works on an owned Kith instance
-- (SCHEMAS §5 KithInstance) with explicit time. Nothing is ever lost: a starved Kith goes Dormant until fed a
-- rare meal; a Kith at full Strain is Exhausted for `exhaustSeconds`, then recovers fully.
-- States: "Dormant" > "Exhausted" > "Hungry" > "Ready". Dormant and Exhausted Kith cannot cast.

local KithCare = {}

-- Fills missing care fields so old saves keep working (satiety full, no Strain).
function KithCare.ensure(inst: any, cfg: any)
	local c = cfg.Upkeep
	if typeof(inst.satiety) ~= "number" then
		inst.satiety = c.satietyMax
	end
	if typeof(inst.strain) ~= "number" then
		inst.strain = 0
	end
	inst.dormant = inst.dormant == true
end

-- Satiety lost per second for a Kith of species `rank`; higher Ranks eat less, fighting drains faster.
function KithCare.drainRate(cfg: any, rank: number, fighting: boolean): number
	local c = cfg.Upkeep
	local rate = c.drainPerMinute / 60 * c.rankDrainFactor ^ (math.max(rank, 1) - 1)
	return if fighting then rate * c.fightMultiplier else rate
end

function KithCare.drain(inst: any, cfg: any, rank: number, dt: number, fighting: boolean)
	if dt <= 0 or inst.dormant then
		return
	end
	inst.satiety = math.max(0, inst.satiety - KithCare.drainRate(cfg, rank, fighting) * dt)
	if inst.satiety <= 0 then
		inst.dormant = true
	end
end

function KithCare.exhausted(inst: any, now: number): boolean
	return typeof(inst.exhaustedUntil) == "number" and now < inst.exhaustedUntil
end

function KithCare.state(inst: any, cfg: any, now: number): string
	if inst.dormant then
		return "Dormant"
	elseif KithCare.exhausted(inst, now) then
		return "Exhausted"
	elseif inst.satiety < cfg.Upkeep.hungryAt then
		return "Hungry"
	end
	return "Ready"
end

function KithCare.usable(inst: any, cfg: any, now: number): boolean
	local s = KithCare.state(inst, cfg, now)
	return s == "Ready" or s == "Hungry"
end

-- Power multiplier for the Kith's moves: Hungry = weaker, Dormant/Exhausted = 0.
function KithCare.power(inst: any, cfg: any, now: number): number
	local s = KithCare.state(inst, cfg, now)
	if s == "Ready" then
		return 1
	elseif s == "Hungry" then
		return cfg.Upkeep.hungryPower
	end
	return 0
end

-- Adds move Strain. Reaching `strainMax` makes the Kith Exhausted. Returns true if it just became Exhausted.
function KithCare.addStrain(inst: any, cfg: any, amount: number, now: number): boolean
	local c = cfg.Upkeep
	if amount <= 0 or KithCare.exhausted(inst, now) then
		return false
	end
	inst.strain = math.min(c.strainMax, inst.strain + amount)
	if inst.strain >= c.strainMax then
		inst.exhaustedUntil = now + c.exhaustSeconds
		return true
	end
	return false
end

-- Strain decays over time; an Exhausted Kith recovers to 0 Strain once its timer ends.
function KithCare.recover(inst: any, cfg: any, dt: number, now: number)
	if typeof(inst.exhaustedUntil) == "number" then
		if now < inst.exhaustedUntil then
			return
		end
		inst.exhaustedUntil = nil
		inst.strain = 0
		return
	end
	inst.strain = math.max(0, inst.strain - cfg.Upkeep.strainDecayPerSecond * math.max(dt, 0))
end

-- Feeds one meal ("common" | "rare"). A Dormant Kith only wakes on a rare meal. Returns ok.
function KithCare.feed(inst: any, cfg: any, meal: string): boolean
	local c = cfg.Upkeep
	local amount = c.meals[meal]
	if amount == nil or (inst.dormant and meal ~= "rare") then
		return false
	end
	inst.dormant = false
	inst.satiety = math.min(c.satietyMax, inst.satiety + amount)
	return true
end

return KithCare
