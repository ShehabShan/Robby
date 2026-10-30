--!strict
-- Crescent Kith content (SCHEMAS §5–§6, R-021 §5): the spike's Crescent Cut as data.
-- Numbers come from `Config` (passed in), so tunables stay in one place and Content stays pure.

local Crescent = {}

function Crescent.content(cfg: any): any
	local c = cfg.Abilities.CrescentCut
	return {
		effects = {
			{
				id = "effect.crescent.hit",
				duration = "Inst",
				ops = { { kind = "Dmg", params = { base = c.baseDamage } } },
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
		},
	}
end

return Crescent
