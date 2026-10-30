--!strict
-- Crescent Kith content (SCHEMAS §5–§6, R-021 §5): the spike's Crescent Cut as data.
-- Numbers come from `Config` (passed in), so tunables stay in one place and Content stays pure.

local Crescent = {}

function Crescent.content(cfg: any): any
	local c = cfg.Abilities.CrescentCut
	local t = cfg.Abilities.TwinCrescent
	local pierce = cfg.Loom.supports.Piercing
	return {
		effects = {
			{
				id = "effect.crescent.hit",
				duration = "Inst",
				ops = { { kind = "Dmg", params = { base = c.baseDamage } } },
				fx = "fx.crescent.hit",
			},
			{
				id = "effect.twin_crescent.hit",
				duration = "Inst",
				ops = { { kind = "Dmg", params = { base = t.baseDamage } } },
				fx = "fx.crescent.hit",
			},
		},
		moves = {
			{
				id = "move.crescent_cut",
				kith = "kith.crescent",
				trigger = "Press",
				target = "Aim",
				delivery = {
					kind = "Projectile",
					params = {
						speed = c.speed,
						range = c.range,
						maxHits = c.maxHits,
						hitbox = c.hitboxSize,
						spawnOffset = c.spawnOffset,
					},
				},
				costs = { qi = c.cost },
				cooldown = c.cooldown,
				effects = { onHit = { "effect.crescent.hit" } },
				tags = { "Path.Moon", "Role.Strike", "Delivery.Proj" },
				fx = { cast = "fx.crescent.cast", travel = "fx.crescent.travel", hit = "fx.crescent.hit" },
			},
			{
				id = "move.twin_crescent",
				kith = "kith.twin_crescent",
				trigger = "Press",
				target = "Aim",
				delivery = {
					kind = "Projectile",
					params = {
						speed = t.speed,
						range = t.range,
						maxHits = t.maxHits,
						hitbox = t.hitboxSize,
						spawnOffset = t.spawnOffset,
					},
				},
				costs = { qi = t.cost },
				cooldown = t.cooldown,
				effects = { onHit = { "effect.twin_crescent.hit" } },
				tags = { "Path.Moon", "Role.Strike", "Delivery.Proj" },
				fx = { cast = "fx.crescent.cast", travel = "fx.crescent.travel", hit = "fx.crescent.hit" },
			},
		},
		supports = { -- Weave Loom supports (T-020c, D-090): modify a core move that has all requireTags
			{
				id = "support.piercing",
				name = "Piercing Edge",
				requireTags = { "Delivery.Proj" },
				deliveryMods = { maxHits = pierce.maxHitsMult, range = pierce.rangeMult },
				costMult = pierce.costMult,
			},
		},
		kith = {
			{
				id = "kith.crescent",
				rank = 1,
				path = "path.moon",
				role = "Strike",
				tags = { "Path.Moon" },
				moves = { "move.crescent_cut" },
				food = "food.moonleaf",
				rarity = "Common",
			},
			{
				id = "kith.twin_crescent", -- Crucible only (recipe.twin_crescent, T-019d)
				rank = 2,
				path = "path.moon",
				role = "Strike",
				tags = { "Path.Moon" },
				moves = { "move.twin_crescent" },
				food = "food.moonleaf",
				rarity = "Uncommon",
			},
		},
	}
end

return Crescent
