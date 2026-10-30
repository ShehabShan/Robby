# R-020d — What fans value + consolidated GDD change list (S7, 2026-10-30)

Closes R-020. Sources are review sites, fan wikis, Steam Workshop and Roblox trackers (depth unverified).
IP rule (D-014): RI terms appear only here, to describe the source. Game content uses Robby mirror names.

## 1. Findings (sourced) → Robby mirror

| # | Finding | Src | Robby mirror / response |
|---|---|---|---|
| 1 | Fans name three main draws: the long climb, an unapologetically ruthless lead, and a rigorous, consistent creature-tool system where strategy and resource management beat raw strength. | [1][2][3] | **Systems are the star.** Every Kith/Weave rule must be consistent and learnable; smart builds and resource choices beat raw grind (Friction wheel, role tags, Mastery). |
| 2 | Readers quit over unrelenting darkness with no catharsis, and over pacing / over-exposition. | [1][2][4] | **Grim world, rewarding play.** Keep the cold, survival-of-the-fittest tone in the world and NPCs, but give the player frequent wins, clear goals and little text. Age-appropriate (R-017). |
| 3 | The ruthless lead's appeal = freedom to act purely for yourself. | [2][5] | **Player agency:** the Rogue route lets players play selfishly (bounties, betrayal-flavoured quests, black-market recipes) inside Roblox rules; no forced "hero" story. |
| 4 | Most-cited moments: a rebirth/second-chance device used to rewrite outcomes, and enduring a brutal trial to tame a powerful tool. | [6] | **Second Chance Kith (rare):** one daily "rewind" of a failed Crucible/Binding. **Endurance trials** in Legacy Vaults (R-020c row 8). Original framing only. |
| 5 | Fan-favourite combo moves are signature, identity-defining (e.g. a move summoning many copies of yourself; a compound sword-dragon). | [7][8] | **Signature Weave:** each player can name and colour one Weave; it shows on their profile and in kill feeds. Big identity/showing-off hook. |
| 6 | Fan-favourite early tools are humble utilities — an essence-refining worm, a common moonlight starter, food plants — not just attacks. | [9][10][11] | **Utility Kith matter:** M1 adds a Qi-refining utility Kith (boosts Stage gain) as a sought-after early prize, beside the Crescent starter. |
| 7 | A fan-made card-game mod (Slay the Spire) uses: combo-move recipes drop after fights, you collect the listed tools, then synthesise at a rest site; breakthroughs upgrade the life-bound tool; rank 6+ tools are unique. | [12][13][14] | **Validates our loop:** Weave hint drops → gather Kith → build in the Weave Loom at rest; breakthroughs upgrade the Heart Kith; Singular Kith later. |
| 8 | Roblox cultivation games are small and players complain about repetitive stat grind, sluggish low-impact combat and lack of agency. | [15][16][17] | **Avoid the genre trap:** skill combat with hit-stop (ART.md bar), choices that change builds, no "click to boost stat" loops. |
| 9 | A Roblox game already uses an RI-like name with hatchable creature companions; it peaked ~130 CCU (July 2026) and fell to ~1 CCU, all-time peak listed as 29 elsewhere (sources disagree). | [18][19][20] | **Niche is open but unproven:** a shallow "pet + meditate" take did not hold players. Depth + combat feel are our edge. Avoid any name near "Insanity". |

## 2. Consolidated GDD change list for P-006 (from R-020a–d)
Grouped by GDD section. Each item: change → source row.

**GDD §3 Core loop + §4 Cultivation & power system**
1. Binding = skill tug-of-war against the Kith's Will, Shards top up Qi mid-duel (a1).
2. Per-Kith **Satiety** (Upkeep) and **Strain** meters; states Dormant / Exhausted / Wounded; nothing is ever lost (a2, a3, a6).
3. Consumable Kith as one-shot loot (a3).
4. **Heart Kith:** first Bound Kith = permanent passive + identity; upgraded by Rank breakthroughs (a7, d7).
5. Crucible = short focus mini-game while Shards feed in; fail = lose catalyst + Wounded component (a6). Optional rare Second Chance rewind (d4).
6. **Core Shell** Stage visual (mist → water → stone → crystal) + wave-based Rank breakthrough trial; cracks heal slowly on fail (a5).
7. Shards = currency **and** Qi refill, stated explicitly (a9).

**GDD §4 Cultivation & power + §5 Combat (Paths & Weaves)**
8. 5 launch Paths (Moon, Wind, Flame, Stone, Tide) + **Friction wheel** (allied/opposed) (b1, b6).
9. **Path Marks** = per-Path % power + visible VFX upgrades at thresholds (b2).
10. **Mastery tiers** per Path (Initiate → Paragon), use-based, separate from Rank (b3).
11. **Weave = 1 core + 1–3 supports** in a **Weave Loom** with resonance hints; one named **Signature Weave** (b4, b5, d5).
12. Kith **role tags** (Strike, Guard, Mend, Carry, Stride, Seek) + loadout gap warning (b9).
13. Utility Kith in M1: a Qi-refining Kith (d6).

**GDD §7 World structure + §9 Social (factions)**
14. A society per Reach (Clans, nomad bands, island houses, merit Halls, lawless Hollow) (c1, c5).
15. **Veils:** Rank gate + damping trial; anti-grief in starter Reaches (c2).
16. Clan hub: Elder Council, Mission Hall, contribution stipends, two rival elders' favour (c3, c4).
17. Clans vs Rogues stays morally grey with distinct perks; Rogue route = selfish-play agency (c6, d3).
18. **Path Ground** zones/arenas buff matching Paths (b8).

**GDD §6 Progression & economy (pacing)**
19. Steep visible Rank gap (≈×1.6 potency per Rank, P-007) + warning colours (c9).
20. Rank 3 = "full cultivator" milestone (title, house slot); Talent = soft cap only (c10).

**GDD §2 World & tone (UX)**
21. Grim world, rewarding play; minimal text, frequent wins (d2).
22. Anti-genre-trap rules: no stat-click loops, skill combat, build choices (d8).

**Later milestones (park, not M1)**
23. Wild Surge server event (M2) (c7). 24. Legacy Vaults with Warden rules + endurance trials (M2–M3) (c8, d4).
25. Party Arrays (b10), Hybrid Weaves (b7), Singular Kith (a8) — post-M1/Ascendant.

## 3. Unknowns
- HUD load (Qi + Satiety + Strain + Stage) on phones — needs a mock before M1 build.
- Competitor CCU numbers conflict between trackers (row 9).

## 4. Sources
1. https://www.chapterchronicles.com/blog/books-like-reverend-insanity/
2. https://www.goodnovel.com/qa/revered-insanity-controversial-among-fans
3. https://www.novelcodex.com/novel/004s/reverend-insanity/reviews
4. https://controllerandcape.com/reverend-insanity-review-why-the-most-ruthless-xianxia-was-banned/
5. https://lunoo.com/item/reverend-insanity
6. https://tvtropes.org/pmwiki/pmwiki.php/Awesome/ReverendInsanity
7. https://reverend-insanity.fandom.com/wiki/Myriad_Self_(Killer_Move)
8. https://sagaofgu.com/cultivation/compound-killer-moves/
9. https://sagaofgu.com/cultivation/gu-worms/
10. https://novelwiki.net/reverend-insanity/guides/mystical-gu/
11. https://reverend-insanity.fandom.com/wiki/Reverend_Insanity_Wiki
12. https://steamcommunity.com/workshop/filedetails/?id=3701087103
13. https://discovermods.com/slay-the-spire/3701087103/
14. https://catalogue.smods.ru/archives/431093
15. https://bloxed.gg/games/cultivation-mortal-to-immortal
16. https://devforum.roblox.com/t/breaking-repetitive-paradigms-with-pvpve-rpgs-need-some-ideas/308218
17. https://devforum.roblox.com/t/people-leaving-game-really-early-on/2158
18. https://www.roblox.com/games/92608282987732/Cultivation-Ascendant-Insanity
19. https://www.robloxgo.com/game/92608282987732/2X-LUCK-Cultivation-Ascendant-Insanity
20. https://rivalducks.com/apps/radar/games/10275125174-cultivation-ascendant-insanity