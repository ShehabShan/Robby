# R-023 Economy & progression (S8, 2026-10-30)

R-023a = §1–§3 (research + sim plan). R-023b = §4 (sim results, next session).

## 1. Findings
- **Faucets vs sinks:** list every way currency enters (core-loop rewards, dailies, events, logins) and leaves (upgrades, crafting, consumables, cosmetics). Sinks must keep pace with rising income, especially during events. Otherwise late-game prices lose meaning. Sinks should feel like progress, not tax. Track earned vs spent [1][2][3].
- **Trading moves currency, it does not remove it.** Only a fee or tax makes trading a sink. Sinks that block progression for poor players frustrate them [3][4].
- **Dupes and exploits** come from client trust and stale saves. The guards are: server-side atomic trades, session-locked profiles (ProfileService/ProfileStore), unique item ids, a trade state that reverts on disconnect, and sanitised remotes [5][6][7].
- **Benchmarks:** Blox Fruits reaches max level in ~40–60 h. Its farmable currency (Beli) is separate from a raid currency (Fragments) that sinks into progression (Awakenings) [8][9]. Robby's Rank 5 target of ~40 h sits at the fast end of that range.

## 2. Robby faucet/sink map (GDD v2 + R-027)
| Faucets (Shards in) | Sinks (Shards out) |
|---|---|
| Kills, nodes (income per hour capped by zone tier, §6) | **Refine** → Stage/Rank progress (largest, §3/§4) |
| Quests, Mission Hall bounties | Crucible catalysts (+ Shards fed during focus) |
| Clan Academy / Elder Council stipends (minus Levy tax) | Upkeep meals when not gathered |
| Contested Springs trickle | Shard Qi refill in combat (with cooldown) |
| Beast Tide / events | Respec (Talent, Path, Imprints) |
| Arena prizes | Arena entry fee, elder favour, Caravan goods |
| — | Trade fee (D-045), cosmetic hub items |
- **Risk:** once a player is capped at Rank 5 Peak, Refine stops absorbing Shards and balances pile up. Post-cap sinks are needed: Crucible chase, cosmetics, respec, Caravan.
- **Risk:** Shards also refill Qi, so combat-heavy players drain faster. The sim checks they still meet the pacing targets.

## 3. Sim plan (R-023b, `research/sim/economy_sim.py`, stdlib only)
- **Inputs (one config dict):**
  - income per hour by zone tier;
  - stipend per real day;
  - Stage cost per Rank (×1.6 Rank gap, R-022);
  - Refill use per combat hour;
  - Crucible attempts and fail odds;
  - Upkeep cost by Rank;
  - cosmetic and respec spend rates;
  - trade volume × fee.
- **Player profiles:** casual (0.5 h/day), regular (2 h/day), grinder (6 h/day), refill-heavy fighter, trader.
- **Loop:** hour steps. Earn → spend on fixed costs (Upkeep, Refill) → Refine the rest → Rank gates (zone tier rises with Rank). Monte Carlo (≥200 runs) for Crucible fails.
- **Outputs:**
  - hours to each Rank vs GDD §6 targets (R1→2 ~2 h, R2→3 ~5 h, R5 ~40 h);
  - Shard balance over time;
  - share of income per sink;
  - capped-player balance growth over 100 h after Rank 5.
- **Pass criteria:**
  - regular-profile pacing within ±20% of the targets;
  - no profile is blocked by fixed costs;
  - capped-player balance growth stays bounded or has sinks shown to absorb it.
- **Then:** propose tuned numbers for GDD §6 and Config.

## 4. Sim results (R-023b, S8)
Script: `research/sim/economy_sim.py` (200 runs per profile, seed 42); raw output `research/sim/economy_results.json`. All numbers are first targets (unverified in play).
- **Calibrated Rank costs** (Shards to fill all Stages of a Rank, regular profile): [1000.0, 3700.0, 13200.0, 32300.0] for Rank 1→2 … 4→5 (growth ×[3.7, 3.57, 2.45]). Cost grows faster than the ×1.6 Rank gap because income per hour also rises with zone tier.
- **Hours = play hours** to reach Rank 2 / 3 / 4 / 5 (median); regular vs GDD targets (2 / 7 / 19 / 40 h): [10, 3, 0, -2] %.

| Profile | h to R2 / R3 / R4 / R5 | blocked runs | Refine share | capped +Shards/h | capped +Shards/h with post-cap sinks |
|---|---|---|---|---|---|
| casual | 1.5 / 4.8 / 12.8 / 25.2 | 0 | 0.82 | 3672 | 1962 |
| regular | 2.2 / 7.2 / 19.0 / 39.2 | 0 | 0.74 | 2071 | 361 |
| grinder | 2.2 / 7.8 / 21.0 / 44.5 | 0 | 0.7 | 1744 | 34 |
| fighter | 2.2 / 8.2 / 22.5 / 48.2 | 0 | 0.59 | 1542 | -168 |
| trader | 2.2 / 7.2 / 19.2 / 40.0 | 0 | 0.73 | 2049 | 339 |

- **Pass:** regular pacing within ±20% of every target; no profile is ever blocked by fixed costs (Upkeep + Refill). (v1 counted a Crucible payment as "blocked" — a sim bug, fixed.)
- **Casual** players are faster per play hour (25 h to Rank 5) because the stipend is paid per real day; in calendar days they are still slowest (~50 days vs ~20 for regular). Acceptable as catch-up.
- **Refill-heavy fighters** are ~20% slower (48 h); the sim does not credit their extra kills, so the real gap is smaller.
- **Fail:** after Rank 5 Peak, balances grow ~2,000 Shards/h. With post-cap sinks (an hourly Crucible chase at ×2 catalyst + Caravan goods at 15% of income) growth drops to ~360/h for regular players and ≤0 for grinders/fighters.

### Tuning proposals (D-046)
1. Use the calibrated Rank costs above as the first Config values (T-002 onward); retune after playtests.
2. Refill cost grows ×1.4 per Rank instead of ×1.6, so fighters stay within ±20%.
3. Cap the daily stipend payout at 7 unclaimed days, so long-absent players don't bank large sums.
4. Post-cap sinks are a launch requirement for Rank 5 players: Crucible chase for rare Kith, Caravan goods, cosmetics, respec. Ascendant Ranks later become the main sink.
5. Track earned vs spent per player in analytics from day one (§1).

## 5. Sources
1. https://create.roblox.com/docs/en-us/production/game-design/balance-virtual-economies.md
2. https://santozstudios.com/blog/roblox-game-economy-design/
3. https://blakeir.com/sinks-faucets-lessons-on-designing-effective-virtual-game-economies
4. https://aaltodoc.aalto.fi/handle/123456789/107498
5. https://create.roblox.com/docs/en-us/scripting/security/client-server-boundary.md
6. https://devforum.roblox.com/t/session-locking-explained-datastore/846799
7. https://devforum.roblox.com/t/preventing-item-duplication-via-trading/277460
8. https://outputlag.com/guides/blox-fruits-leveling-guide-complete-route-from-level-1-to-max-level/
9. https://rblxwiki.com/articles/roblox-game-economy-and-inflation-control