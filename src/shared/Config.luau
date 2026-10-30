--!strict
-- Tunable game constants. Pure data: no Roblox services.

local Config = {
	Round = {
		minPlayers = 1,
		intermission = 15, -- seconds
		race = 180, -- seconds
		results = 8, -- seconds
	},
	Qi = {
		max = 100, -- rank 1 pool
		regen = 5, -- per second
	},
	Abilities = {
		-- Crescent Cut (.ai/SPIKE.md §1). Tune in playtest.
		CrescentCut = {
			cost = 10, -- Qi per blade
			cooldown = 1.2, -- seconds
			baseDamage = 20,
			rankBonus = 0.25, -- +25% per rank above 1
			speed = 90, -- studs/s
			range = 60, -- studs
			maxHits = 2, -- pierces up to 2 targets
			hitboxSize = { x = 6, y = 1.5, z = 2 }, -- studs
			spawnOffset = 3, -- studs in front of the caster
		},
	},
}

return Config
