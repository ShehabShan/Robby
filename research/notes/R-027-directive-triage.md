# R-027 Owner directive list — critical triage (S8, 2026-10-30)

Input: `research/inbox/2026-10-30-owner-directive-list.md` (44 points, written by another AI; a directive, not a source — D-040).
Rules: playability first (D-041); points split into parts; tie-breakers mobile clarity, server cost, IP (D-014: mirror names only).
Verdicts: **Adopt** (as is) · **Adapt** (idea kept, form changed) · **Salvage** (only the named small mechanic kept) · **Park** (later) · **Reject**.
Source checks: R-011, R-019, R-020a–d, F-001 notes first; S8 searches marked [S8] (sources in §4). Unchecked claims are "(unverified)".

## 1. Summary
- 44 points → 86 parts. Most of the list is already in GDD v2 (Kith, Binding, Heart Kith, Crucible, Weaves, Marks, Mastery, Clans/Rogues).
- **New for the vertical slice / M1 (added to GDD, D-042):** Rank lock on equipping Kith; Qi **Reserve** for passive Kith; **Refine** rest action; **Recoil** on a failed experimental Crucible; **Scatter** interrupt on elite NPCs; **Overdraw** (cast past 0 Qi for HP + a temporary Core Crack); **Qi Wells** in boss arenas; **Seek** info layer (stealth, exact Rank, trails); **Bond** level per Kith; **Will** stat.
- **New for M2+ (GDD §7/§9 or §12):** Peerless Talent; Imprints; Relic Kith; Caravan event; escort and Beast Tide quests; arena entry fee; Clan Levy and elder favour seesaw; Rogue Notoriety; spring-anchored settlements and contested Springs; perishable rare goods; summon Kith; Remnant mini-dungeons.
- **Rejected outright:** anything that permanently destroys a player's Kith, Core capacity or character (lifespan countdown, Heart Kith destruction, player death drops, permanent injuries), HUD-off by default, hundreds-of-units scales.

## 2. Triage table
| # | Point (part) | Verdict | Mechanic kept / reason | Robby mirror | GDD / system |
|---|---|---|---|---|---|
| 1a | Kith rank vs wielder rank set power | Adopt | power = Kith base × wielder Core hue (already) | Core hue | §4 |
| 1b | Higher-rank Gu needs higher master rank | Adopt | can't equip a Kith above your Rank; clear, prevents twinking | Rank lock | §4, Equip |
| 2a | Mass-produced mortal Gu (R1–5) | Adopt | species can have many copies | Kith species | data model |
| 2b | Immortal Gu absolute uniqueness | Park | one per world needs a global lock + anti-hoard rule (return to world after 14 days inactive) | Singular Kith | §12, ARCH §9 |
| 3a | Mortal vs immortal essence tiers | Adapt | one Qi bar; tier shown by hue; Ascendant tier later | Qi / Ascendant Qi | §4, §12 |
| 3b | Essence tier limits activation | Adopt | same rule as 1b | Rank lock | §4 |
| 4a | Aptitude grades A–D set pool | Adopt | already | Talent grade | §4 |
| 4b | Grade sets cultivation limit | Adapt | soft cap only, never a hard lock (R-020d) | Talent | §6 |
| 4c | Ten Extreme Physiques | Salvage | rare ~1% **Peerless** grade: max pool, but Core is unstable — a questline must be finished before Rank 3 [S8: extreme grade is separate from A–D, 100% capacity, and inherently unstable] | Peerless Talent | §4, M2 quest |
| 5a | Paths | Adopt | already (5 at launch) | Paths | §4 |
| 5b | Must specialise or body conflicts | Adapt | soft: Friction cuts Weave power; main + secondary viable | Friction wheel | §4 |
| 6a | Attainment tiers | Adopt | already | Mastery | §4 |
| 6b | Faster refinement | Adopt | better Crucible odds (already) | Mastery | §4 |
| 6c | Combat instincts | Salvage | at Master tier, enemy moves of that Path get an earlier telegraph flash | Path Sense | §5 |
| 6d | Mimic other paths | Park | Paragon: one off-Path support ignores Friction | Paragon perk | §12 |
| 7a | Core + supplementary Gu | Adopt | already | Weaves | §4 |
| 7b | Hundreds of supports | Reject | mobile clarity; 1–3 supports (up to 5 via Mastery later) | — | — |
| 8a | Marks give passive Path power | Adopt | already | Path Marks | §4 |
| 8b | Thousands of marks, massive multipliers | Adapt | shown as tiers; diminishing returns per R-022 | Mark tiers | §4, R-022 |
| 8c | Marks only for immortals | Adapt | Marks from Rank 1 (already) | — | §4 |
| 9a | Absorb stones to progress | Adopt | Shards fill the Stage bar (already) | Shards | §4 |
| 9b | Actively push against aperture walls | Adapt | **Refine**: a hold-to-channel action at rest spots that turns Shards into Stage progress with a cracking-shell VFX; no idle AFK gain | Refine | §3, §4 |
| 9c | Minor stages Initial→Peak | Adopt | 4 Stages (already) | Stages | §4 |
| 10a | Each Gu eats specific items | Adopt | already | Upkeep | §4 |
| 10b | Constant gathering | Adapt | higher Ranks eat less; meals buyable | Upkeep | §4 |
| 10c | Starved Gu die | Reject | Dormant instead (already; R-020a) | — | — |
| 11a | Combine lower into higher Gu with recipes | Adopt | already | Crucible | §4 |
| 11b | Backlash injury on failure | Adapt | **Recoil**: failed experimental Crucible drains current Qi and halves Qi regen for 5 min; no permanent harm | Recoil | §4 |
| 12a | Mixed loadout roles | Adopt | role tags + gap warning (Storage = Carry) | Role tags | §4 |
| 12b | Limited essence must be budgeted across the set | Adapt | **Reserve**: each equipped passive Kith reserves a % of max Qi, so Talent shapes builds | Qi Reserve | §4, R-021p |
| 13a | Beast-tide scouting | Adopt | **Beast Tide** timed defence event (= Wild Surge, M2) | Beast Tide | §7, §12 |
| 13b | Resource node management | Adapt | contested Springs (see 38) | Springs | §7 |
| 13c | Caravan guarding | Adopt | escort quest type | Escort | §7 |
| 13d | Arena wagers | Adapt | fixed entry fee + fixed prizes, no player-to-player betting (Roblox gambling policy) | Arena fee | §9 |
| 13e | Clan political sabotage | Salvage | elder **favour seesaw**: helping one rival elder costs favour with the other | Elder favour | §7 |
| 14a | Stones = money = EXP | Adopt | already | Shards | §6 |
| 14b | Stones refill mana in battle | Adopt | already; refill gets a short cooldown to stop spam | Shard refill | §4 |
| 15a | Clan stipend vs freedom | Adopt | already | Clans / Rogues | §9 |
| 15b | Blood-refinement shortcuts | Adapt | Rogue black-market recipes: faster, higher fail chance; no blood (Mild) | Black-market recipes | §9 |
| 15c | Demonic players constantly hunted | Adapt | **Notoriety** from PvP-zone kills summons NPC hunter patrols; player bounties only in PvP zones | Notoriety | §9 |
| 16 | Inheritance dungeons (puzzles, traps, recipes, legacy Gu, springs) | Park | already planned; rewards = recipe + a guaranteed Kith + a Qi Well | Legacy Vault | §12 |
| 17 | Immortal aperture city-building to feed Gu | Adapt + Park | Sanctum = personal plot producing Upkeep materials; light building; a plot in a shared hub, not a private server (server cost) | Sanctum | §12, ARCH §9 |
| 18 | Tribulations on immortal rank-up | Adopt + Park | Trials of Heaven = wave defence of the Sanctum; Rank trial is the mortal version | Trials of Heaven | §12 |
| 19a | First refined Gu bound to life | Adopt | already | Heart Kith | §4 |
| 19b | Lower essence cost | Adapt | Heart Kith gives −10% Qi cost to its Path's moves | Heart passive | §4 |
| 19c | Severe trauma if destroyed | Reject | Heart Kith is never lost (R-020a; Roblox norms) [S8: in the source destruction means heavy injury or death] | — | — |
| 20 | Dying masters destroy their Gu; suppress to loot | Salvage | elite NPCs start a visible 2 s **Scatter** channel at low HP; interrupt it (stagger, parry, burst) for the bonus drop [R-020a; S8 confirms self-detonation] | Scatter | §5 |
| 21 | Wild Gu capture mini-game | Adopt | already (tug-of-war, Kith pushes back) | Binding | §4 |
| 22a | Permanent body carving, zero-mana passives | Adapt | **Imprints**: permanent passive slots earned at Rank breakthroughs; no Qi; count as Path Marks of their Path | Imprints | §4 (M2) |
| 22b | Hard to switch later | Adapt | respec costs Shards; never impossible | Respec | §6 |
| 23 | Relic Gu skip minor bottlenecks | Adapt | **Relic Kith**: rare world-drop consumable that completes one Stage (never a Rank); never sold [S8: natural, rank 1, one small realm] | Relic Kith | §4 |
| 24a | Terrain buffs Path (water near river) | Adapt | fixed Path Ground zones only, no dynamic terrain checks | Path Ground | §7 |
| 24b | Fight over springs for mana in boss fights | Salvage | **Qi Wells** in boss arenas: standing in one gives fast Qi regen; the boss attacks Wells | Qi Wells | §5, §7 |
| 25a | No standard radar | Reject | mobile clarity: minimap and HP bars stay | — | — |
| 25b | Sensory Gu detect stealth, appraise rank, track | Adapt | **Seek** Kith reveal stealthed foes, exact Rank and loadout, and bounty trails; default shows a Rank colour band | Seek layer | §5 |
| 26a | Spamming too many Gu overloads | Salvage | **Overdraw**: cast at 0 Qi by paying HP; adds a Core Crack (−10% max Qi until rest) | Overdraw | §5 |
| 26b | Permanent capacity loss until rare cure | Reject | no permanent loss | — | — |
| 27 | Seasonal merchant caravans | Adapt | **Caravan** hub event every ~2 real hours: rotating recipes, hint scrolls, rare meals (no Kith or catalysts — scarcity rule) | Caravan | §6, §7 |
| 28 | Lifespan countdown | Reject | character expiry kills retention; lore only (NPC elders seek longevity) [S8: Lifespan Gu are natural, limited by Heaven's Will] | — | §2 lore |
| 29a | Each Gu an individual entity with hunger, food, tags | Adopt | instance record separate from species data | Kith instance | ARCH §9 |
| 29b | Loyalty / will | Adapt | **Bond** level rises with use (+small bonus); no disobedience | Bond | §4 |
| 30 | Dao Mark conflict forces non-hybrid builds | Adapt | opposed-Path Marks cut opposed moves, capped at −20%; hybrids of allied Paths stay viable | Friction | §4 |
| 31 | HUD hidden by default | Reject | bounce risk on mobile; info depth via Seek (25b) | — | — |
| 32 | Perishable goods, Storage Gu pause decay | Salvage | only rare meals and some materials perish (real-time hours) unless held in a Carry Kith; normal bag otherwise; expiry = stored timestamp | Perishables | §6 (M2) |
| 33 | Two time flows (world vs aperture) | Adapt + Park | Sanctum produces at a multiplier, computed from timestamps; no live dual clock | Sanctum time | §12, ARCH §9 |
| 34a | Formation arrays from deployed Gu | Adapt + Park | Arrays = placed totem of ≤3 Kith making a timed zone (ward, slow, harvester) fed by world Qi | Arrays | §12 |
| 34b | Hundreds of Gu deployed | Reject | server cost, clarity | — | — |
| 35 | Gu House pilotable fortress pooling mana | Park | party vessel with pooled Qi for one big skill; post-launch | Kith Vessel | §12 |
| 35b | Thousands of fused Gu | Reject | scale | — | — |
| 36a | Soul as separate stat | Adapt | **Will**: profile stat (not on HUD) that sets Binding strength, summon cap and control resistance [R-020a Soul] | Will | §4 |
| 36b | Enemies steal Gu mid-battle | Reject | item loss in combat | — | — |
| 37a | Clan hierarchy taxes and drafts | Salvage | **Levy**: periodic Clan defence calls (skip = lose contribution) and a stipend tax | Clan Levy | §7 |
| 37b | Bribery | Adapt | spend Shards for elder favour | Elder favour | §7 |
| 37c | Blackmail, hidden alliances | Reject | complexity, tone | — | — |
| 38a | Springs anchor villages and respawns | Adopt | level-design rule: every settlement sits on a Spring | Springs | §2, §7 |
| 38b | Springs generate currency, territory control | Adapt + Park | a few contested Springs in hunting zones as PvE capture points with a Shard trickle; Clan territory war later | Contested Springs | §7, §12 |
| 39a | Actions leave traces, trackers hunt you | Salvage | bounty trails via Seek (25b) | Trails | §5 |
| 39b | Cleansing Gu wipe traces | Salvage | a Cleanse consumable lowers Notoriety | Cleanse | §9 |
| 39c | Every action leaves world traces | Reject | server cost | — | — |
| 40a | Summoner army limited by soul and drain | Adapt | summon Kith: 1–3 active, capped by Will, constant Qi drain | Summon Kith | §4, R-021p |
| 40b | Hundreds of beasts | Reject | server cost | — | — |
| 41 | Currency tiers without inflation | Adapt | ledger supports tiers now; one-way upward exchange with a sink; R-023 simulates | Shard tiers | §6, ARCH §9 |
| 42 | Variant human races with own economies | Adapt + Park | original non-human peoples in Reaches 2–5 with favour perks (e.g. Crucible odds); no source race names | Peoples | §7, §12 |
| 43 | Phantom second aperture | Park | data model holds a list of Cores (default 1) | Twin Core | §12, ARCH §9 |
| 44a | Dead NPC drops aperture as raidable mini-dungeon | Salvage | slain world bosses leave a 10-min **Remnant** instance for the party | Remnant | §7 (M2) |
| 44b | Player death drops everything | Reject | defeat = stagger + respawn (Mild, Roblox norms) | — | — |

## 3. Open questions for R-021p (ability catalogue input)
Add these abilities/rules to the catalogue and test the framework against them:
1. **Qi Reserve** (12b): passives that reserve max Qi — does the framework support reservation, not just cost?
2. **Overdraw** (26a): cost-substitution (HP for Qi) plus a stacking debuff that clears on rest.
3. **Scatter** (20): an NPC channel that an interrupt cancels — same primitive as the player Binding channel?
4. **Qi Wells** (24b): an area that modifies regen and can be destroyed by an attack.
5. **Seek layer** (25b): per-viewer information effects (reveal stealth, show Rank) — client-side visibility driven by server tags.
6. **Summon Kith** (40a): persistent entities with upkeep drain and a cap from a stat (Will).
7. **Imprints / Heart passive** (22a, 19b): permanent modifiers scoped to one Path.
8. **Recoil** (11b): a debuff applied by a non-combat system (Crucible).
9. **Path Sense** (6c): a modifier that changes how *enemy* telegraphs render for one viewer.
10. **Rank lock** (1b) and **Friction cap** (30): equip-time and calc-time rule checks.
11. **Bond** (29b): per-instance scaling that grows with use.

## 4. Sources
- Repo notes: `research/notes/R-011`, `R-019`, `R-020a` (Gu care, Soul, self-destruct row 10), `R-020b` (Paths, attainment, Friction), `R-020c` (inheritance, blessed land, Ranks), `R-020d`, `R-022`, `F-001`.
- [S8] https://reverend-insanity.fandom.com/wiki/Ten_Extreme_Physiques · https://sagaofgu.com/cultivation/aptitude/
- [S8] https://reverend-insanity.fandom.com/wiki/Lifespan_Gu · https://sagaofgu.com/gu/lifespan-gu/
- [S8] https://reverend-insanity.fandom.com/wiki/Soul · https://sagaofgu.com/chapters/196/
- [S8] https://sagaofgu.com/gu/green-copper-relic-gu/ · https://reverend-insanity.fandom.com/wiki/Relic_Gu
- [S8] https://sagaofgu.com/cultivation/vital-gu/ · https://sagaofgu.com/cultivation/refinement-failure/
- Points 13, 27, 31–35, 37, 39, 41–42 rely on the directive text and R-019/R-020 context only (unverified in the source this session); verdicts rest on playability, not on fidelity.