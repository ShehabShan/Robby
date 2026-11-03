--!strict
-- Crescent Kith content (SCHEMAS §5–§6, R-021 §5): the spike's Crescent Cut as data.
-- Numbers come from `Config` (passed in), so tunables stay in one place and Content stays pure.

local Crescent = {}

function Crescent.content(cfg: any): any
	local c = cfg.Abilities.CrescentCut
	local t = cfg.Abilities.TwinCrescent
	local r = cfg.Abilities.FullMoonRing
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
				fx = "fx.twin.hit",
			},
			{
				id = "effect.twin_crescent.third", -- 3rd blade, 2× one blade's damage (T-056, D-404)
				duration = "Inst",
				ops = { { kind = "Dmg", params = { base = t.baseDamage * t.third.damageMult } } },
				fx = "fx.twin.hit",
			},
			{
				id = "effect.full_moon_ring.hit", -- Full Moon Ring blade (T-053c, D-407)
				duration = "Inst",
				ops = { { kind = "Dmg", params = { base = r.baseDamage } } },
				fx = "fx.fullmoon.hit",
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
						aim = "Free", -- free 3D aim (T-053a1, D-383)
						maxPitch = c.maxPitchDeg,
						stopOnWorld = true, -- blade ends on walls/ground (owner D-380)
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
					kind = "Volley", -- two blades on a Scissor path (T-053b, D-394)
					params = {
						count = 2,
						spreadDeg = 0,
						perTargetCap = t.perTargetCap,
						curve = "Scissor",
						width = t.width,
						crossAt = t.crossAt,
						speed = t.speed,
						range = t.range,
						maxHits = t.maxHits,
						hitbox = t.hitboxSize,
						spawnOffset = t.spawnOffset,
						stopOnWorld = true, -- blades end on walls / solid parts (T-056, D-404)
						third = t.third, -- 3rd blade tuning; Scissor.thirdParams builds its params (T-056)
						thirdEffect = "effect.twin_crescent.third",
						thirdFx = "fx.twin.third", -- client draws the 3rd blade (T-056c)
					},
				} :: any, -- Volley params differ from Crescent Cut's Projectile ones (sibling literal type)
				costs = { qi = t.cost },
				cooldown = t.cooldown,
				effects = { onHit = { "effect.twin_crescent.hit" } },
				tags = { "Path.Moon", "Role.Strike", "Delivery.Proj" },
				fx = { cast = "fx.twin.cast", travel = "fx.twin.travel", hit = "fx.twin.hit" },
			},
			{
				id = "move.full_moon_ring", -- rank 3 on X (T-053c, D-407): 4 blades form a ring, then burst outward
				name = "Full Moon Ring",
				kith = "kith.full_moon",
				trigger = "Press",
				target = "Aim",
				delivery = {
					kind = "Volley",
					params = {
						count = r.count,
						spreadDeg = 0,
						perTargetCap = r.perTargetCap,
						curve = "Ring",
						radius = r.radius,
						speed = r.speed,
						range = r.range,
						maxHits = r.maxHits,
						hitbox = r.hitboxSize,
						stopOnWorld = true,
					},
				} :: any,
				costs = { qi = r.cost },
				cooldown = r.cooldown,
				effects = { onHit = { "effect.full_moon_ring.hit" } },
				tags = { "Path.Moon", "Role.Strike", "Delivery.Proj" },
				fx = { cast = "fx.twin.cast", travel = "fx.fullmoon.travel", hit = "fx.fullmoon.hit" },
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
				id = "kith.full_moon", -- rank 3, working name; admin panel only until the owner picks name + recipe (T-053c)
				rank = 3,
				path = "path.moon",
				role = "Strike",
				tags = { "Path.Moon" },
				moves = { "move.crescent_cut", "move.twin_crescent", "move.full_moon_ring" }, -- left click / Z / X (D-396)
				food = "food.moonleaf",
				rarity = "Rare",
			},
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
				moves = { "move.crescent_cut", "move.twin_crescent" }, -- left click Crescent Cut, Z Scissor (T-053b)
				food = "food.moonleaf",
				rarity = "Uncommon",
			},
		},
	}
end

return Crescent
