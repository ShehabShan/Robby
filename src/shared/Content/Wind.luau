--!strict
-- Wind Kith content (T-015a, GDD §8 M1 "a Wind dash Kith"): Wind Step as data.
-- Self-delivered dash: a burst of movement with brief i-frames. Numbers come from `Config`.

local Wind = {}

function Wind.content(cfg: any): any
	local c = cfg.Abilities.WindStep
	return {
		effects = {
			{
				id = "effect.wind.step",
				duration = "Timed",
				seconds = c.iframes,
				grantTags = { "State.Iframes" },
				fx = "fx.wind.step",
			},
		},
		moves = {
			{
				id = "move.wind_step",
				kith = "kith.wind",
				trigger = "Press",
				target = "Self",
				delivery = { kind = "Self", params = { distance = c.distance } },
				costs = { qi = c.cost },
				cooldown = c.cooldown,
				effects = { onSelf = { "effect.wind.step" } },
				tags = { "Path.Wind", "Role.Stride", "Delivery.Self" },
				fx = { cast = "fx.wind.cast" },
			},
		},
		kith = {
			{
				id = "kith.wind",
				rank = 1,
				path = "path.wind",
				role = "Stride",
				tags = { "Path.Wind" },
				moves = { "move.wind_step" },
				food = "food.windseed",
				rarity = "Common",
			},
		},
	}
end

return Wind
