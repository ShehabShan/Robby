--!strict
-- Rimeshard Kith content (T-027c, R-028 §2, D-180): the first proper ability Kith as data.
-- Chill (Frost) sets up on every hit (R1 Needle, Z Shard Fan, X Rime Fall); C Shatter pays off.
-- Numbers come from `Config.Abilities.Rimeshard` (passed in), so Content stays pure and tunables live in one place.
-- Deliveries: Projectile (Needle), Volley (finisher, Shard Fan), Zone (Rime Fall), Burst (Shatter) — T-027b.

local Frost = require("../Frost")

local Rimeshard = {}

local TAGS_PROJ = { "Path.Frost", "Role.Strike", "Delivery.Proj" }

function Rimeshard.content(cfg: any): any
	local r = cfg.Abilities.Rimeshard
	local n = r.needle
	local fan = r.shardFan
	local fall = r.rimeFall
	local sh = r.shatter
	-- Lists are `{ any }`: records differ in shape (Luau strict would otherwise unify them).
	local effects: { any } = {
		Frost.chillEffect(r.chill), -- effect.rime.chill: stacks by target, -slowPerStack MoveSpeed each
		{
			id = "effect.rime.needle.hit",
			duration = "Inst",
			ops = { { kind = "Dmg", params = { base = n.damage } } },
			fx = "fx.rime.hit",
		},
		{
			id = "effect.rime.fan.hit",
			duration = "Inst",
			ops = { { kind = "Dmg", params = { base = fan.damage } } },
			fx = "fx.rime.hit",
		},
		{
			id = "effect.rime.fall.tick",
			duration = "Inst",
			ops = { { kind = "Dmg", params = { base = fall.damagePerTick } } },
			fx = "fx.rime.fall.tick",
		},
		{
			-- Shatter payoff: damage scales with the target's Chill stacks and consumes them (Frost.consume on the
			-- server); a Rimed target is staggered. No Chill → no damage (no free area damage, note §2 C).
			id = "effect.rime.shatter",
			duration = "Inst",
			requireTags = { Frost.CHILLED_TAG },
			ops = {
				{
					kind = "DmgPerStack",
					params = { status = Frost.CHILL_ID, base = sh.base, perStack = sh.perStack, consume = true },
				},
				{ kind = "Stagger", params = { seconds = sh.staggerSeconds, requireTag = Frost.RIMED_TAG } },
			} :: { any },
			fx = "fx.rime.shatter",
		},
	}
	local moves: { any } = {
		{
			-- R1 left-click chain while Rimeshard is the active Kith (T-027d): shots 1–2 (step 3 = finisher below).
			id = "move.rime.needle",
			kith = "kith.rimeshard",
			trigger = "Press",
			target = "Aim",
			chain = n.chain, -- same Combat.press state machine as the light chain (steps/window/recovery)
			delivery = {
				kind = "Projectile",
				params = {
					speed = n.speed,
					range = n.range,
					maxHits = n.maxHits,
					hitbox = n.hitboxSize,
					spawnOffset = n.spawnOffset,
				},
			},
			costs = { qi = 0 },
			cooldown = n.chain.recovery,
			effects = { onHit = { "effect.rime.needle.hit", Frost.CHILL_ID } },
			tags = TAGS_PROJ,
			fx = { cast = "fx.rime.needle.cast", travel = "fx.rime.needle.travel", hit = "fx.rime.hit" },
		},
		{
			-- Needle shot 3: two shards side by side, costs Qi, then the chain resets.
			id = "move.rime.needle_finisher",
			kith = "kith.rimeshard",
			trigger = "Press",
			target = "Aim",
			delivery = {
				kind = "Volley",
				params = {
					count = n.finisher.shards,
					spreadDeg = n.finisher.spreadDeg,
					perTargetCap = n.finisher.shards,
					speed = n.speed,
					range = n.range,
					maxHits = n.maxHits,
				},
			},
			costs = { qi = n.finisher.cost },
			cooldown = n.chain.recovery,
			knockback = true,
			effects = { onHit = { "effect.rime.needle.hit", Frost.CHILL_ID } },
			tags = TAGS_PROJ,
			fx = { cast = "fx.rime.needle.finisher", travel = "fx.rime.needle.travel", hit = "fx.rime.hit" },
		},
		{
			-- Z Shard Fan (Volley): close-range shotgun / crowd clear; a target takes at most perTargetCap shards.
			id = "move.rime.shard_fan",
			kith = "kith.rimeshard",
			trigger = "Press",
			target = "Aim",
			telegraph = fan.telegraph, -- yellow (parryable) hand ring
			delivery = {
				kind = "Volley",
				params = {
					count = fan.count,
					spreadDeg = fan.spreadDeg,
					perTargetCap = fan.perTargetCap,
					speed = fan.speed,
					range = fan.range,
					maxHits = fan.maxHits,
				},
			},
			costs = { qi = fan.cost },
			cooldown = fan.cooldown,
			effects = { onHit = { "effect.rime.fan.hit", Frost.CHILL_ID } },
			tags = TAGS_PROJ,
			fx = { cast = "fx.rime.fan.cast", travel = "fx.rime.needle.travel", hit = "fx.rime.hit" },
		},
		{
			-- X Rime Fall (Zone): aimed ground circle; red telegraph for `delay`, then `ticks` over `duration`.
			id = "move.rime.fall",
			kith = "kith.rimeshard",
			trigger = "Press",
			target = "Point",
			telegraph = fall.delay,
			delivery = {
				kind = "Zone",
				params = {
					radius = fall.radius,
					range = fall.range,
					delay = fall.delay,
					ticks = fall.ticks,
					duration = fall.duration,
				},
			},
			costs = { qi = fall.cost },
			cooldown = fall.cooldown,
			effects = { onHit = { "effect.rime.fall.tick", Frost.CHILL_ID } },
			tags = { "Path.Frost", "Role.Zone", "Delivery.Zone" },
			fx = { cast = "fx.rime.fall.telegraph", travel = "fx.rime.fall.rain", hit = "fx.rime.fall.tick" },
		},
		{
			-- C Shatter (Burst): every Chilled target in `radius` around the caster; only Chilled targets are candidates.
			id = "move.rime.shatter",
			kith = "kith.rimeshard",
			trigger = "Press",
			target = "Self",
			telegraph = sh.telegraph, -- clap wind-up; frost veins race to each Chilled target
			delivery = { kind = "Burst", params = { radius = sh.radius, maxTargets = sh.maxTargets } },
			targetTags = { Frost.CHILLED_TAG },
			costs = { qi = sh.cost },
			cooldown = sh.cooldown,
			effects = { onHit = { "effect.rime.shatter" } },
			tags = { "Path.Frost", "Role.Burst", "Delivery.Burst" },
			fx = { cast = "fx.rime.shatter.cast", hit = "fx.rime.shatter" },
		},
	}
	return {
		effects = effects,
		moves = moves,
		supports = {}, -- Piercing Edge (Crescent content) fits Needle/Fan through the shared "Delivery.Proj" tag
		kith = {
			{
				id = "kith.rimeshard",
				rank = 1,
				path = "path.frost",
				role = "Strike",
				tags = { "Path.Frost" },
				moves = {
					"move.rime.needle",
					"move.rime.needle_finisher",
					"move.rime.shard_fan",
					"move.rime.fall",
					"move.rime.shatter",
				},
				food = "food.frostcap",
				rarity = "Common",
			},
		},
	}
end

return Rimeshard
