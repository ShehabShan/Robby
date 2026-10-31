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
		TwinCrescent = { -- rank 2 Crucible result (T-019d, D-084): two blades' worth in one wider cut
			cost = 14,
			cooldown = 1.4,
			baseDamage = 34,
			speed = 95,
			range = 65,
			maxHits = 3,
			hitboxSize = { x = 9, y = 1.5, z = 2 },
			spawnOffset = 3,
		},
		-- M1 Kith moves (T-015a). Initial tuning; tune in playtest.
		WindStep = { cost = 8, cooldown = 3, distance = 14, iframes = 0.3, burstSeconds = 0.25 }, -- burstSeconds: client covers `distance` in this time; server speed guard mirrors it (F-08, D-204)
		-- Rimeshard Kith (T-027c, R-028 §2, D-180): Chill sets up (R1/Z/X), Shatter pays off (C). Tune in playtest.
		Rimeshard = {
			chill = { maxStacks = 3, seconds = 3, slowPerStack = 0.15 }, -- -15 % move speed per stack; 3 stacks = Rimed
			needle = { -- R1 left-click chain while Rimeshard is the active Kith; light-chain timing
				chain = { steps = 3, window = 0.8, recovery = 0.25 },
				damage = 4, -- D-183 (was 5): sim parity with Crescent vs Mistmaw
				speed = 120,
				range = 45,
				maxHits = 1,
				hitboxSize = { x = 1, y = 1, z = 3 },
				spawnOffset = 2,
				finisher = { shards = 2, spreadDeg = 6, cost = 3 }, -- shot 3: two shards side by side, resets the chain
				finisherRecovery = 1.2, -- pause after shot 3 before the chain restarts (D-182: keeps Needle ≈ melee DPS)
			},
			shardFan = { -- Z (Volley): close-range crowd clear; a target takes at most 2 of 5 shards
				cost = 10,
				cooldown = 3, -- D-183 (was 1.8): Fan was carrying single-target DPS
				damage = 8,
				count = 5,
				spreadDeg = 30,
				perTargetCap = 2,
				speed = 100,
				range = 35,
				maxHits = 1,
				telegraph = 0.2,
			},
			rimeFall = { -- X (Zone): aimed ground circle, 0.6 s red telegraph then 4 ticks over 1 s
				cost = 18,
				cooldown = 8,
				radius = 7,
				range = 40,
				delay = 0.6,
				ticks = 4,
				duration = 1.0,
				damagePerTick = 6,
			},
			shatter = { -- C (Burst): 12 + 8 per Chill stack, consumes stacks, staggers Rimed targets
				cost = 15,
				cooldown = 10,
				radius = 25,
				maxTargets = 12,
				base = 12,
				perStack = 8,
				staggerSeconds = 0.4,
				telegraph = 0.3,
			},
		},
	},
	-- Movement (T-026b3a, D-163): studs/s; accel in studs/s per second.
	Movement = { walk = 16, sprint = 24, accel = 40 },
	-- Sprint speed guard (T-026b3b, D-166): server planar speed check; slack in studs per 0.25 s sample.
	-- Remote rate limits per client→server event (F-02, D-171): tokens per second + burst.
	RemoteRates = {
		default = { rate = 10, burst = 10 },
		CastRequest = { rate = 10, burst = 10 },
		Action = { rate = 15, burst = 15 },
		Equip = { rate = 4, burst = 8 },
		SelectSlot = { rate = 8, burst = 8 },
		BindStart = { rate = 2, burst = 4 },
		BindInput = { rate = 15, burst = 15 },
		Feed = { rate = 4, burst = 8 },
		Refine = { rate = 4, burst = 8 },
		Breakthrough = { rate = 2, burst = 4 },
		CrucibleStart = { rate = 2, burst = 4 },
		CruciblePress = { rate = 15, burst = 15 },
		WeaveSet = { rate = 4, burst = 8 },
	},
	SpeedGuard = { tolerance = 1.25, slack = 2, burstSeconds = 0.6, strikes = 3 },
	-- Combat core (T-013a, GDD §5): initial tuning, seconds unless noted.
	Combat = {
		chain = { steps = 5, window = 0.8, recovery = 0.3, damage = 6, range = 6, arcDot = 0.3 },
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
	Marks = { perHit = 1, max = 500 }, -- Path Marks per damaging hit (T-020b, D-089); boost via DamageMath.marksBoost
	Loom = { -- Weave Loom (T-020a, D-088); tune in playtests
		maxSupports = 1, -- M1: core + 1 support (2–3 later, unlocked by Mastery)
		frictionFullMarks = 60, -- opposed-Path Marks at which full Friction applies
		supports = { -- support numbers (T-020c, D-090)
			Piercing = { maxHitsMult = 2, rangeMult = 1.25, costMult = 1.4 }, -- Piercing Edge: 2x pierce, +25% range, +40% Qi
		},
		paths = { -- opposed Paths (negative = Friction); allied bonuses later
			["path.moon"] = { frictionWith = { ["path.flame"] = -0.2 } },
			["path.flame"] = { frictionWith = { ["path.moon"] = -0.2, ["path.tide"] = -0.2, ["path.frost"] = -0.2 } },
			["path.frost"] = { frictionWith = { ["path.flame"] = -0.2 } }, -- Rimeshard (T-027c, D-181)
			["path.tide"] = { frictionWith = { ["path.flame"] = -0.2 } },
			["path.wind"] = { frictionWith = { ["path.stone"] = -0.2 } },
			["path.stone"] = { frictionWith = { ["path.wind"] = -0.2 } },
		},
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
		recoilSeconds = 300, -- failed experimental fusion: Qi drained, regen halved 5 min (T-019c)
		recoilRegen = 0.5,
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
		dummyKith = "kith.crescent", -- the training dummy doubles as a wild Kith until the world spawns them -- guided first bind: the bar never drops below this
	},
	Beasts = { -- wild beasts (T-022, D-124); server AI in Shared.BeastBrain; tune in playtests
		respawn = 20, -- seconds after a beast dies or is bound
		corpseSeconds = 2, -- corpse stays this long before Destroy (beasts and bosses; F-08, D-202)
		spread = 35, -- studs from the zone centre
		spawns = { { kind = "beast.mistfang", count = 3 }, { kind = "beast.stonehide", count = 2 } }, -- hunting zone 1
		minTelegraph = 0.4, -- seconds; every beast attack winds up at least this long (ROADMAP T-022)
		kinds = {
			["beast.mistfang"] = { -- quick wolf: short lunge bite in front
				name = "Mistfang",
				rank = 1,
				hp = 60,
				speed = 18,
				aggro = 40,
				leash = 90,
				range = 7,
				arcDot = 0.2,
				telegraph = 0.45,
				recover = 0.6,
				cooldown = 1.6,
				damage = 8,
				shards = 6,
				wildKith = "kith.wind",
			},
			["beast.stonehide"] = { -- heavy boar: slow, all-round ground slam
				name = "Stonehide Boar",
				rank = 1,
				hp = 140,
				speed = 12,
				aggro = 30,
				leash = 80,
				range = 9,
				arcDot = -1,
				telegraph = 0.8,
				recover = 1.2,
				cooldown = 3,
				damage = 18,
				shards = 14,
				wildKith = "kith.crescent",
			},
		},
	},
	Bosses = { -- bosses (T-023, D-137); server AI in Shared.BossBrain; tune in playtests (Rank 1–2 beatable)
		minTelegraph = 0.4, -- seconds; every boss attack winds up at least this long, both phases
		kinds = {
			["boss.mistmaw"] = { -- Mistmaw Elder: old mist wolf, Academy Rank-test boss in the Mistvale arena
				name = "Mistmaw Elder",
				rankTest = "academy", -- killing blow passes the Academy Rank test (D-168)
				rank = 2,
				hp = 800, -- D-169 (was 900)
				speed = 14,
				aggro = 45,
				leash = 70,
				gap = 0.8, -- seconds between attacks
				phase2At = 0.5, -- HP fraction where phase 2 starts
				phase2Recover = 0.7, -- recover-time multiplier in phase 2 (telegraphs stay the same)
				shards = 120,
				respawn = 90, -- seconds after the boss dies
				attacks = {
					bite = { range = 8, arcDot = 0.3, telegraph = 0.6, recover = 0.7, damage = 10 },
					slam = { range = 12, arcDot = -1, telegraph = 1.0, recover = 1.2, damage = 16 },
					lunge = { range = 18, arcDot = 0.6, telegraph = 0.8, recover = 1.0, damage = 13 },
				},
				pattern = { "bite", "bite", "slam", "lunge" },
				pattern2 = { "lunge", "bite", "slam", "slam", "lunge" },
			},
		},
	},
	Refining = { -- utility Kith that speed Refine (T-025, D-112); tune in playtests
		lotusYield = 0.5, -- Mist Lotus: +50 % Stage points per Shard while equipped
		maxYield = 1, -- cap on the bonus (best equipped Kith only, no stacking)
	},
	Loadout = {
		baseSlots = 3, -- Core slots at Rank 1 (GDD)
		slotsPerRank = 1,
		maxSlots = 7, -- Mortal cap
		warnRoles = { "Strike" }, -- loadout screen warns when none is equipped (D-063)
		-- granted to a profile with no Kith (D-064); slots fill in this order, so Rimeshard is the active stance (D-194)
		starter = { "kith.rimeshard", "kith.crescent", "kith.wind" },
		fixedMoves = { "move.wind_step" }, -- live whenever their Kith is equipped, not only when selected (owner, D-217)
		gifts = { "kith.rimeshard" }, -- granted once to existing profiles that lack the species (D-195)
	},
}

return Config
