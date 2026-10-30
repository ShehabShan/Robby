--!strict
-- Combat core state machines (T-013a, GDD §5 "Moves", ARCHITECTURE §3 Combat core). Pure: the server's
-- CombatService owns one state per player and passes `now` (server clock) and Config.Combat in.
-- Light chain (5 hits), Parry (tight window → stagger), Guard (meter; guard-break).

export type ChainCfg = { steps: number, window: number, recovery: number }
export type ParryCfg = { window: number, cooldown: number }
export type GuardCfg = { max: number }

export type Chain = { step: number, lastAt: number }
export type Parry = { openedAt: number, lastAt: number, window: number }
export type Guard = { up: boolean, meter: number }

local NEVER = -math.huge

local Combat = {}

-- Light chain --------------------------------------------------------------------------------------
function Combat.newChain(): Chain
	return { step = 0, lastAt = NEVER }
end

-- Returns the chain step (1..steps) this press performs, or nil while still recovering from the last.
-- A press after the window, or after the last step, starts the chain again at 1.
function Combat.press(chain: Chain, now: number, cfg: ChainCfg): number?
	if now - chain.lastAt < cfg.recovery then
		return nil
	end
	if chain.step == 0 or chain.step >= cfg.steps or now - chain.lastAt > cfg.window then
		chain.step = 1
	else
		chain.step += 1
	end
	chain.lastAt = now
	return chain.step
end

-- Parry --------------------------------------------------------------------------------------------
function Combat.newParry(): Parry
	return { openedAt = NEVER, lastAt = NEVER, window = 0 }
end

function Combat.parry(parry: Parry, now: number, cfg: ParryCfg): boolean
	if now - parry.lastAt < cfg.cooldown then
		return false
	end
	parry.lastAt = now
	parry.openedAt = now
	parry.window = cfg.window
	return true
end

-- True when a hit landing at `hitAt` falls inside the open parry window (the attacker is staggered).
function Combat.parries(parry: Parry, hitAt: number): boolean
	local dt = hitAt - parry.openedAt
	return dt >= 0 and dt <= parry.window
end

-- Guard --------------------------------------------------------------------------------------------
export type GuardOutcome = "open" | "blocked" | "broken"

function Combat.newGuard(cfg: GuardCfg): Guard
	return { up = false, meter = cfg.max }
end

function Combat.setGuard(guard: Guard, up: boolean)
	guard.up = up and guard.meter > 0
end

-- Resolves a hit against the guard. "open": take full damage. "blocked": the meter absorbs `amount`.
-- "broken": a guard-break hit, or a meter emptied by blocking; the guard drops (counters turtling).
function Combat.hitGuard(guard: Guard, amount: number, breaks: boolean): GuardOutcome
	if not guard.up then
		return "open"
	end
	if breaks then
		guard.up = false
		guard.meter = 0
		return "broken"
	end
	guard.meter = math.max(0, guard.meter - math.max(0, amount))
	if guard.meter <= 0 then
		guard.up = false
		return "broken"
	end
	return "blocked"
end

-- Refills the meter (call while not guarding).
function Combat.regenGuard(guard: Guard, dt: number, perSecond: number, cfg: GuardCfg)
	guard.meter = math.min(cfg.max, guard.meter + math.max(0, dt) * perSecond)
end

return Combat
