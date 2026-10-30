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

## 4. Sim results
(R-023b.)

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