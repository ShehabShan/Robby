--!strict
-- Frost (T-027a, D-175): the Rimeshard Kith's Chill status and Shatter math as pure data + functions.
-- Chill is an ordinary `Effects` status (stacks, MoveSpeed modifier, State.Chilled tag); Shatter reads the stacks,
-- turns them into damage + stagger, and consumes them. Numbers come from `Config.Abilities.Rimeshard` (passed in).

local Effects = require("./Effects")

local Frost = {}

Frost.CHILL_ID = "effect.rime.chill"
Frost.CHILLED_TAG = "State.Chilled"
Frost.RIMED_TAG = "State.Rimed"

export type ChillCfg = { maxStacks: number, seconds: number, slowPerStack: number }
export type ShatterCfg = { base: number, perStack: number, staggerSeconds: number }
export type Shatter = { damage: number, stagger: number, stacks: number }

-- The Chill effect record (Registry-validated through Content/Rimeshard, T-027c).
function Frost.chillEffect(cfg: ChillCfg): Effects.Effect
	return {
		id = Frost.CHILL_ID,
		duration = "Timed",
		seconds = cfg.seconds,
		stack = { cap = cfg.maxStacks, by = "target", refresh = true },
		modifiers = { { attr = "MoveSpeed", bucket = "Boost" :: Effects.Bucket, value = -cfg.slowPerStack } },
		grantTags = { Frost.CHILLED_TAG },
		fx = "fx.rime.chill",
	}
end

-- Current Chill stacks on a holder (0 when not chilled). Chill stacks by target, so at most one entry exists.
function Frost.stacks(holder: Effects.Holder): number
	for _, a in holder.active do
		if a.effectId == Frost.CHILL_ID then
			return a.stacks
		end
	end
	return 0
end

-- A target at max stacks is Rimed: the visible frost crust and the stagger trigger.
function Frost.isRimed(stacks: number, cfg: ChillCfg): boolean
	return stacks >= cfg.maxStacks
end

-- Shatter payoff for a given stack count. No Chill → nothing (no free area damage, note §2 C).
function Frost.shatter(stacks: number, chill: ChillCfg, cfg: ShatterCfg): Shatter
	if stacks <= 0 then
		return { damage = 0, stagger = 0, stacks = 0 }
	end
	local n = math.min(stacks, chill.maxStacks)
	return {
		damage = cfg.base + cfg.perStack * n,
		stagger = if Frost.isRimed(n, chill) then cfg.staggerSeconds else 0,
		stacks = n,
	}
end

-- Reads, computes and consumes the Chill on a holder in one step (server cast path for move.rime.shatter).
function Frost.consume(
	holder: Effects.Holder,
	lookup: Effects.Lookup,
	ctx: Effects.Ctx,
	chill: ChillCfg,
	cfg: ShatterCfg
): Shatter
	local result = Frost.shatter(Frost.stacks(holder), chill, cfg)
	if result.stacks > 0 then
		Effects.remove(holder, Frost.CHILL_ID, lookup, ctx)
	end
	return result
end

return Frost
