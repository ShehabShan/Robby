--!strict
-- Tunable game constants. Pure data: no Roblox services.

local Config = {
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
	-- Combat core (T-013a, GDD §5): initial tuning, seconds unless noted.
	Combat = {
		chain = { steps = 5, window = 0.8, recovery = 0.3, damage = 6, range = 6, arcDot = 0.3 },
		dash = { cooldown = 1.2, iframes = 0.25, speed = 60 },
		parry = { window = 0.2, cooldown = 1.0, stagger = 1.0 },
		guard = { max = 100, regenPerSecond = 25, breakStagger = 1.5 },
		rate = { perSecond = 12, burst = 6 }, -- Action remote token bucket
	},
	-- Hit feel for every hit (T-014, ART §5 items 2 and 5). Seconds unless noted.
	HitFeel = {
		hitStopFrames = 3, -- clamped to 2–4
		shakeSeconds = 0.15,
		shakeAmplitude = 0.25, -- studs
		flashSeconds = 0.1,
		numberSeconds = 0.6,
		numberRise = 2, -- studs
		sparks = 24,
	},
}

return Config
