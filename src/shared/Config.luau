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
		-- M1 Kith moves (T-015a). Initial tuning; tune in playtest.
		StoneWard = { cost = 15, cooldown = 6, seconds = 1.5 },
		WindStep = { cost = 8, cooldown = 3, distance = 14, iframes = 0.3 },
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
	Breakthrough = { -- Rank breakthrough trial (T-018e, D-077); tune in playtests
		waves = 3,
		crackPerWave = 100,
		waveSeconds = 20,
		healPerSecond = 1, -- cracks heal after a failed trial
		maxRank = 9,
		crackPerDamage = 1, -- crack points per damage dealt during a trial (T-018f, D-080)
	},
	Crucible = { -- Kith fusion (T-019a, D-081); tune in playtests
		recipes = {
			["recipe.twin_crescent"] = {
				inputs = { "kith.crescent", "kith.crescent" },
				output = "kith.twin_crescent", -- rank 2 content: T-019d
				catalystShards = 200,
				baseChance = 0.55, -- experimental odds before focus
			},
		},
		focusBonus = 0.35, -- perfect focus adds +35 %
		maxChance = 0.9, -- experimental fusions never reach 100 %
		woundedSeconds = 86400, -- fail Wounds one component for a day
		woundedPower = 0.7,
		focus = { -- focus mini-game (T-019b, D-082)
			rounds = 3,
			sweepSeconds = 1.2, -- one needle pass across the bar
			zoneWidth = 0.18, -- share of the bar that counts as a hit
			nearMiss = 0.12, -- partial credit beyond the zone edge
			roundSeconds = 4, -- no press in time = 0 for the round
		},
	},
	Stages = { -- 4 Stages per Rank as a Core Shell (T-018c, D-075); tune in playtests
		baseCost = 50, -- points (1 Shard = 1 point) for Rank 1 First Stage
		stageCostStep = 0.25, -- each later Stage costs +25 % of base
		rankCostFactor = 2.5, -- each Rank costs 2.5x the one before
		restRadius = 12, -- studs from a `RestSpot` part that count as resting (T-018d)
		refinePerSecond = 10, -- Shards per second while holding Refine at a rest spot (wiring T-018d)
	},
	Upkeep = { -- Satiety + Strain per Kith (T-018a, D-073); tune in playtests
		satietyMax = 100,
		drainPerMinute = 1.5, -- Rank 1 Kith, not fighting (~66 min from full to Dormant)
		rankDrainFactor = 0.8, -- each species Rank above 1 eats 20 % less often
		fightMultiplier = 3, -- heavy fighting drains faster
		hungryAt = 30, -- below this the Kith is Hungry
		hungryPower = 0.75, -- Hungry Kith hit for 75 %
		meals = { common = 40, rare = 100 }, -- a Dormant Kith wakes only on a rare meal
		strainMax = 100,
		strainDecayPerSecond = 4,
		exhaustSeconds = 20,
		defaultStrain = 15, -- Strain per cast when a move has no `costs.strain` (T-018b)
		fightWindow = 8, -- seconds after a cast that count as fighting for Satiety drain
	},
	Binding = { -- tug-of-war (T-017a, D-070); tune in playtests
		start = 0.25, -- bar position at the start (0..1)
		channelRate = 0.18, -- bar per second while channelling (Will 0)
		qiPerSecond = 8,
		slideRate = 0.06, -- bar per second lost while not channelling
		pulseEvery = 2.5, -- seconds between the Kith's push-backs
		pulseStrength = 0.05, -- bar lost per pulse (Will 0)
		willWeight = 0.1, -- each Will point slows the channel and strengthens pulses by 10 %
		grace = 3, -- an empty bar only counts as a flee after this many seconds
		timeLimit = 45,
		shardQi = 40,
		shardCooldown = 3,
		guidedFloor = 0.1,
		weakenAt = 0.3, -- a wild Kith can be bound at or below this share of its max health (T-017b)
		range = 24, -- studs from the player to the wild Kith
		wildWill = 1, -- Will when the wild Kith has no `Will` attribute
		dummyKith = "kith.stone", -- the training dummy doubles as a wild Kith until the world spawns them -- guided first bind: the bar never drops below this
	},
	Loadout = {
		baseSlots = 3, -- Core slots at Rank 1 (GDD)
		slotsPerRank = 1,
		maxSlots = 7, -- Mortal cap
		warnRoles = { "Strike", "Guard" }, -- loadout screen warns when none is equipped (D-063)
		starter = { "kith.crescent", "kith.stone", "kith.wind" }, -- granted to a profile with no Kith (D-064)
	},
}

return Config
