# R-020a — RI creature-tool system in depth (S7, 2026-10-30)

Deepens R-011 §1 and R-019. Sources are fan wikis/summaries, not the novel (depth unverified).
IP rule (D-014): RI terms appear only here, to describe the source. Game content uses the Robby mirror names
(Kith, Core/Qi, Binding, Crucible, Weave, Shards, Stage, Rank, Ascendant).

## 1. Findings (sourced) → Robby mirror

| # | RI finding | Src | Robby mirror (original) |
|---|---|---|---|
| 1 | Taming a wild creature-tool is a war of attrition: the master pours essence in, the wild will pushes it out; progress is kept only if the master keeps replenishing essence. Success replaces the wild will with the master's. | [1][2][3] | **Binding duel:** a tug-of-war bar. You channel Qi; the wild Kith's Will pushes back in pulses. Stop channelling and the bar slides back. Shards top up Qi mid-Binding. Skill + resource tension, not a dice roll. |
| 2 | Every creature-tool eats a specific food. Low ranks eat every few days, high ranks less often. Heavy use makes the next meal come sooner. Starved ones may go dormant and fossilise, or die. | [4][5] | **Upkeep (refine GDD §3):** higher-Rank Kith eat less often; heavy use in a fight drains a Satiety bar faster. A starved Kith goes **Dormant** (unusable until fed a rarer meal). Never lost (keeps GDD §3 "never lost"). |
| 3 | Low-rank tools have limited durability: activating them repeatedly without rest makes them collapse. Some are single- or multi-use consumables. | [6][7] | **Strain:** each Kith has a Strain meter. Spamming fills it; full Strain = Kith **Exhausted** for ~20 s. Rewards rotating a set instead of spamming one move. **Consumable Kith** exist as one-shot loot (traps, burst heals). |
| 4 | The same tool hits harder when fed higher-rank essence. | [8] | **Hue scaling:** a Kith's moves scale with the wielder's Rank (Core hue), so early Kith stay useful for a while. |
| 5 | The inner space has 4 stages per rank. Its wall hardens light → water → stone → crystal membrane; a breakthrough shatters the wall with waves of essence. Partial damage to the wall heals. Shards (stones) refill essence. | [9][10][11] | **Core Shell:** the Stage bar is shown as a shell around the Core that visibly changes material per Stage (mist → water → stone → crystal; original art). A Rank breakthrough = a short trial where you crack the shell in waves; fail and the cracks slowly heal (progress partly kept for a short window). |
| 6 | Fusing tools into a higher rank follows a recipe and needs sustained focus while stones are fed in; dropping focus ends it. Fail rates are brutal at high ranks (worse than 9/10 at rank 4–5); failure wastes materials and can injure or kill parts. | [12][13] | **Crucible (refine GDD §3):** a short focus mini-game while Shards are fed in. Known recipes = safe. Experimental = visible fail chance; on fail the catalyst is lost and a component Kith becomes **Wounded** (weaker for a day), never destroyed. |
| 7 | One "life-bound" tool is linked to the master's life: injury to one hurts the other; losing or replacing it causes heavy injury or death. | [14] | **Heart Kith:** the first Kith you Bind becomes your Heart Kith — a permanent passive bonus and your identity. It cannot be lost. In PvP, breaking a Heart Kith's guard stuns its owner (risk/reward, no permanent loss). |
| 8 | Rank 6+ tools are unique: only one of each kind exists in the world; a duplicate cannot be made while one exists. | [15][16] | **Singular Kith (Ascendant, post-launch):** each exists once per game universe; the holder is visible on a world board and it can be won in sanctioned challenges. A strong long-term hook; needs anti-abuse design. |
| 9 | Stones are both the currency and an essence refill. | [17][18] | **Shards = money and Qi refill:** spending tension (heal Qi now or save for the Crucible). Already partly in GDD; make the dual use explicit. |
| 10 | When a master dies, their tools keep the dead master's will; clans treat them as inheritance. Masters can set tools to self-destruct to deny looters. | [19][20] | **No loss on defeat** (Roblox norms). Flavour only: "inherited" Kith quests where you Bind a fallen elder's Kith (Binding is harder: the old Will is strong). |

## 2. → Implications for Robby (GDD change candidates for P-006)
1. Binding becomes a skill mini-game (tug-of-war), not a timer (row 1).
2. Add Satiety (Upkeep) and Strain meters per Kith; Dormant / Exhausted / Wounded states replace any permanent loss (rows 2, 3, 6).
3. Core Shell visual for Stages + wave-based Rank breakthrough trial (row 5).
4. Heart Kith as the player's identity choice in the first 10 minutes (row 7).
5. Make Shards' dual use explicit in the economy (row 9).
6. Park Singular Kith in the Ascendant/endgame list (row 8).

## 3. Unknowns
- Whether Satiety + Strain + Qi is too many meters for mobile; needs a HUD mock and a playtest.
- Real fusion success numbers in the novel are only partly sourced; Robby numbers are design choices (P-007).

## 4. Sources
1. https://sagaofgu.com/cultivation/refinement/
2. https://sagaofgu.com/cultivation/primeval-essence/
3. https://sagaofgu.com/cultivation/wild-gu/
4. https://sagaofgu.com/cultivation/gu-worms/
5. https://reverend-insanity.fandom.com/wiki/Gu
6. https://sagaofgu.com/cultivation/mortal-gu/
7. https://reverend-insanity.fandom.com/wiki/Category:Consumable_%26_Expendable_Type_Gu
8. https://reverend-insanity.fandom.com/wiki/Primeval_Essence
9. https://sagaofgu.com/cultivation/aperture-and-primeval-essence/
10. https://sagaofgu.com/cultivation/upper-stage/
11. https://sagaofgu.com/cultivation/peak-stage/
12. https://sagaofgu.com/cultivation/gu-fusion/
13. https://sagaofgu.com/cultivation/refinement-failure/
14. https://sagaofgu.com/cultivation/vital-gu/
15. https://sagaofgu.com/cultivation/immortal-gu/
16. https://sagaofgu.com/inheritances/infallible-inheritance/
17. https://sagaofgu.com/cultivation/primeval-stones/
18. https://reverend-insanity.fandom.com/wiki/Immortal_Essence_Stone
19. https://sagaofgu.com/cultivation/wild-gu/ (inheritance)
20. https://reverend-insanity.fandom.com/wiki/Soul