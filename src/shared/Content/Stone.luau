--!strict
-- Stone Kith content (T-015a, GDD §8 M1 "a Stone guard Kith"): Stone Ward as data.
-- Self-delivered ward: for a short time incoming hits are blocked. Numbers come from `Config`.

local Stone = {}

function Stone.content(cfg: any): any
	local c = cfg.Abilities.StoneWard
	return {
		effects = {
			{
				id = "effect.stone.ward",
				duration = "Timed",
				seconds = c.seconds,
				grantTags = { "State.Warded" },
				fx = "fx.stone.ward",
			},
		},
		moves = {
			{
				id = "move.stone_ward",
				kith = "kith.stone",
				trigger = "Press",
				target = "Self",
				delivery = { kind = "Self", params = {} },
				costs = { qi = c.cost },
				cooldown = c.cooldown,
				effects = { onSelf = { "effect.stone.ward" } },
				tags = { "Path.Stone", "Role.Guard", "Delivery.Self" },
				fx = { cast = "fx.stone.cast" },
			},
		},
		kith = {
			{
				id = "kith.stone",
				rank = 1,
				path = "path.stone",
				role = "Guard",
				tags = { "Path.Stone" },
				moves = { "move.stone_ward" },
				food = "food.stonemoss",
				rarity = "Common",
			},
		},
	}
end

return Stone
