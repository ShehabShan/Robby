--!strict
-- Mist Lotus (T-025, D-112, GDD §4 "Qi-refining utility Kith", R-020d): a passive utility Kith. No active move:
-- while it sits in a Core slot, Refine at a rest spot turns each Shard into more Stage progress
-- (`passive.refineYield`, from `Config.Refining`). Found wild in Mistvale (placement in T-021c).

local Lotus = {}

function Lotus.content(cfg: any): any
	local c = cfg.Refining
	return {
		kith = {
			{
				id = "kith.lotus",
				rank = 1,
				path = "path.moon",
				role = "Mend",
				tags = { "Path.Moon", "Role.Utility" },
				moves = {},
				passive = { refineYield = c.lotusYield },
				food = "food.dewdrop",
				rarity = "Uncommon",
			},
		},
	}
end

return Lotus
