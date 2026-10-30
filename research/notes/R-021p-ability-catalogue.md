# R-021p Ability needs catalogue (S8, 2026-10-30)

Purpose: the concrete test set R-021 scores every ability/effect framework against (D-039). Every GDD v2 mechanic plus the R-027 additions (rows 1–37) and 15 iconic source effect *roles* (rows 38–52; mirror roles only, no source names — D-014) and Fighting Styles, Armament Kith and Talismans (rows 53–60, D-048). No row is copied from the novel: rows 1–37 and 53–60 are Robby's own mechanics; rows 38–52 are generic effect types (beam, poison, stealth…).

## 1. Primitive codes
- **Trigger:** Pr press · Ho hold/channel · Co combo step · Ps passive (always on) · Eq on equip/loadout change · OH on hit dealt · OD on damage taken · Ev system event (low HP, Strain full, Crucible fail, rest) · Ar enter area · Tm timer.
- **Target:** Aim (direction) · Self · Lock (target/nearest) · Gnd (ground point) · Rad (radius around source) · Allies.
- **Delivery:** Mel melee box · Proj projectile · Beam · AoE instant area · Zone persistent area · Sum spawned entity · Self · Inh (inherits the core's delivery — Weave supports) · Sys (non-combat system).
- **Effect:** Dmg · Heal · Res (change a resource: Qi, HP, Strain) · Drain (per-tick transfer) · Stat (modifier) · Sts (status/state tag) · Disp (move/displace) · Inv (i-frames) · Intr (interrupt) · Spawn · Reveal (per-viewer info) · Rewind · Xform (swap moveset/model).
- **Duration:** Inst · Timed · Chan (channel) · Pers (until removed) · Stack (stacks with cap) · Refr (re-apply refreshes).
- **Cost:** Qi · Str (Strain) · HP · Rsv (reserved max Qi) · Use (consumable charge) · CD (cooldown) · Sat (Satiety) · Mat (Shards/materials) · None.
- **Net:** Srv (server decides) · Pred (client plays it instantly) · Rep (replicated entity) · View (per-viewer render) · Save (persists in profile).

## 2. Catalogue
| # | Ability (origin) | Trigger | Target | Delivery | Effect | Duration | Cost | States/tags | FX hooks | Net |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Crescent Cut (spike) | Pr | Aim | Proj | Dmg | Inst | Qi+CD+Str | Moon, Strike, pierce 2 | cast, travel, hit | Srv+Pred |
| 2 | Light chain, 5 hits (§5) | Co | Aim | Mel | Dmg | Inst | None | combo step, hit-stop | cast, hit | Srv+Pred |
| 3 | Dash (§5) | Pr | Aim | Self | Disp+Inv | Timed | CD | iframe | cast, end | Srv+Pred |
| 4 | Parry (§5) | Pr | Self | Self | Sts+Intr | Timed | CD | parry window, staggers attacker | cast, hit | Srv |
| 5 | Guard (§5) | Ho | Self | Self | Stat | Chan | Str | guarding | loop | Srv+Pred |
| 6 | Guard break (§5) | Co | Aim | Mel | Dmg+Sts | Inst | Str | breaks guarding | hit | Srv |
| 7 | Strength line passive (F-001) | Ps | Self | Self | Stat | Pers | Rsv | Strike, passive | loop | Srv |
| 8 | Stone skin (T-015) | Pr | Self | Self | Stat+Sts | Timed | Qi+CD+Str | Stone, Guard, shielded | cast, loop, end | Srv |
| 9 | Wind dash Kith (T-015) | Pr | Aim | Self | Disp | Inst | Qi+CD+Str | Wind, Stride | cast, travel | Srv+Pred |
| 10 | Qi-refining utility (T-025) | Ps | Self | Sys | Stat | Pers | Rsv | Seek, Stage gain + | loop | Save |
| 11 | Burst-heal consumable (§4) | Pr | Self | Self | Heal | Inst | Use | Mend, consumable | cast | Srv |
| 12 | Trap consumable (§4) | Pr | Gnd | Zone | Dmg+Sts | Timed | Use | trap, entity | cast, loop, hit | Srv+Rep |
| 13 | Heart Kith passive (§4) | Ps | Self | Self | Stat | Pers | None | heart, Path-scoped −10% cost | — | Save |
| 14 | Weave core (Crescent + pierce) | Pr | Aim | Proj | Dmg+Stat | Inst | Qi+Str+CD | weave, support mods | cast, travel, hit | Srv+Pred |
| 15 | Weave support: slow | OH | Lock | Inh | Sts | Timed+Refr | None | slowed | hit | Srv |
| 16 | Path Marks (§4) | Ps | Self | Sys | Stat | Pers+Stack | None | Path-scoped, tiers | loop | Save |
| 17 | Friction ≤ −20% (§4) | Eq | Self | Sys | Stat | Pers | None | opposed Path | — | Srv |
| 18 | Path Ground zone (§7) | Ar | Rad | Zone | Stat | Pers | None | Path-scoped zone | loop | Srv |
| 19 | Strain full → Exhausted (§4) | Ev | Self | Sys | Sts | Timed | Str | exhausted | end | Srv |
| 20 | Satiety → Dormant (§4) | Tm | Self | Sys | Sts | Pers | Sat | hungry, dormant | — | Save |
| 21 | Wounded after Crucible fail (§4) | Ev | Self | Sys | Stat+Sts | Timed | None | wounded | — | Save |
| 22 | Binding tug-of-war (§4) | Ho | Lock | Beam | Res+Drain | Chan | Qi | channel, interruptible | loop, end | Srv+Rep |
| 23 | Crucible focus (§4) | Ho | Self | Sys | Spawn | Chan | Mat+Qi | crucible | loop, end | Srv+Save |
| 24 | Second Chance rewind (§4) | Pr | Self | Sys | Rewind | Inst | Use+CD | rewind, daily | cast | Srv+Save |
| 25 | Array ward totem, ≤3 Kith (§12) | Pr | Gnd | Zone+Sum | Stat+Sts | Timed | Qi+Use | array, entity | cast, loop, end | Srv+Rep |
| 26 | Aura: allies +Qi regen | Ps | Allies | Zone | Stat | Pers | Rsv | aura | loop | Srv+Rep |
| 27 | Qi Reserve (R-027) | Eq | Self | Sys | Res | Pers | Rsv | reserve | — | Srv |
| 28 | Overdraw (R-027) | Pr | Self | Self | Res+Sts | Timed+Stack | HP | core crack | hit | Srv |
| 29 | Scatter, NPC (R-027) | Ev | Self | Self | Spawn | Chan | None | channel, interruptible | loop, end | Srv+Rep |
| 30 | Qi Well (R-027) | Ar | Rad | Zone | Res | Pers | None | well, destructible | loop, hit | Srv+Rep |
| 31 | Seek reveal (R-027) | Pr | Rad | AoE | Reveal | Timed | Qi+CD | Seek, per-viewer | cast, loop | View |
| 32 | Summon Kith (R-027) | Pr | Gnd | Sum | Spawn+Drain | Pers | Qi+Rsv | summon, Will cap | cast, loop | Srv+Rep |
| 33 | Imprint (R-027) | Ps | Self | Self | Stat | Pers | None | Path-scoped, counts as Marks | — | Save |
| 34 | Recoil (R-027) | Ev | Self | Sys | Res+Stat | Timed | None | recoil | — | Srv |
| 35 | Path Sense (R-027) | Ps | Self | Sys | Reveal | Pers | None | per-viewer telegraph | loop | View |
| 36 | Bond scaling (R-027) | OH | Self | Sys | Stat | Pers+Stack | None | per-instance | — | Save |
| 37 | Shard Qi refill (§4) | Pr | Self | Self | Res | Inst | Mat+CD | refill | cast | Srv |
| 38 | Lightning beam (role) | Ho | Aim | Beam | Dmg | Chan | Qi+Str | beam, channel | loop, hit | Srv+Pred |
| 39 | Bouncing bolt ×3 (role) | Pr | Lock | Proj | Dmg | Inst | Qi+CD | bounce | travel, hit | Srv |
| 40 | Poison on hit (role) | OH | Lock | Inh | Dmg+Sts | Timed+Stack | Qi | DoT | loop | Srv |
| 41 | Stealth (role) | Pr | Self | Self | Sts | Timed | Qi+CD | stealthed, per-viewer | cast, end | Srv+View |
| 42 | Ally shield bubble (role) | Pr | Allies | AoE | Stat+Sts | Timed | Qi+CD | Guard, shield HP | cast, loop, end | Srv+Rep |
| 43 | Blink (role) | Pr | Gnd | Self | Disp | Inst | Qi+CD | Stride | cast, end | Srv+Pred |
| 44 | Beast form (role) | Pr | Self | Self | Xform+Stat | Timed | Qi+Str | transformed, moveset swap | cast, loop, end | Srv+Rep |
| 45 | Gravity pull (role) | Pr | Gnd | AoE | Disp+Dmg | Inst | Qi+CD | pull | cast, hit | Srv |
| 46 | Life drain (role) | Ho | Lock | Beam | Dmg+Heal | Chan | Qi | drain, channel | loop | Srv |
| 47 | Decoy clone (role) | Pr | Self | Sum | Spawn | Timed | Qi+CD | decoy, entity | cast, end | Srv+Rep |
| 48 | Charm, Will check (role) | OH | Lock | Proj | Sts | Timed | Qi | charmed, resisted by Will | hit | Srv |
| 49 | Knockback slam (role) | Pr | Rad | AoE | Dmg+Disp | Inst | Qi+Str | knockback | cast, hit | Srv |
| 50 | Counter on damage (role) | OD | Lock | Mel | Dmg | Inst | CD | counter | hit | Srv |
| 51 | Regen passive (role) | Ps | Self | Self | Heal | Pers | Rsv | Mend | loop | Srv |
| 52 | Stone wall (role) | Pr | Gnd | Sum | Spawn | Timed | Qi+CD | wall, blocks movement | cast, end | Srv+Rep |
| 53 | Style heavy attack (A1) | Ho | Aim | Mel | Dmg+Disp | Inst | Str | Style, charged, guard-break | cast, hit | Srv+Pred |
| 54 | Spear sweep (A1) | Pr | Rad | Mel | Dmg+Disp | Inst | Str+CD | Style.Spear, knockback | cast, hit | Srv+Pred |
| 55 | Bow charged shot (A1/A2) | Ho | Aim | Proj | Dmg | Chan | Qi | Style.Bow, charge | loop, travel, hit | Srv+Pred |
| 56 | Form Armament (A2) | Eq | Self | Self | Xform | Pers | Rsv | Armament, weapon model, unlocks Style moves | cast | Srv+Rep |
| 57 | Armament Path infusion (A2) | OH | Lock | Inh | Dmg+Sts | Inst | None | Path tag on Style hits | hit | Srv |
| 58 | Resonance (A4) | OH | Lock | Inh | Stat+Dmg | Timed | None | 1 s window, same Path | hit | Srv |
| 59 | Talisman passive (A3) | Ps | Self | Self | Stat | Pers | None | Talisman, tradable gear | — | Save |
| 60 | Talisman ward charge (A3) | OD | Self | Self | Sts+Inv | Timed | Use+CD | Talisman | cast | Srv |

## 3. Primitive frequency
Counted by script over 60 rows (a row can use several codes).

| Primitive | Counts (most used first) |
|---|---|
| Trigger | Pr 24, Ps 9, Ho 7, OH 6, Ev 4, Eq 3, Co 2, Ar 2, OD 2, Tm 1 |
| Target | Self 29, Aim 9, Lock 9, Gnd 6, Rad 5, Allies 2 |
| Delivery | Self 19, Sys 12, Proj 5, Mel 5, Zone 5, Inh 4, Sum 4, AoE 4, Beam 3 |
| Effect | Stat 19, Dmg 17, Sts 16, Disp 7, Res 6, Spawn 5, Heal 3, Inv 2, Drain 2, Reveal 2, Xform 2, Intr 1, Rewind 1 |
| Duration | Timed 20, Pers 17, Inst 16, Chan 7, Stack 4, Refr 1 |
| Cost | Qi 23, CD 19, None 16, Str 12, Rsv 7, Use 5, Mat 2, Sat 1, HP 1 |
| Net | Srv 50, Rep 12, Pred 11, Save 10, View 3 |

## 4. Hard edge cases
- **Rewind (24):** needs a server snapshot of the Kith instances, materials and Shards taken before each Crucible/Binding; one use per day; never client state. Not a combat-time rewind.
- **Channels (5, 22, 23, 29, 38, 46):** one shared Channel primitive — ticks, per-tick cost, interrupt tags (stagger, parry, burst), a cancel event. Binding, Scatter and beams must all use it.
- **Auras & zones (18, 26, 30):** a persistent effect attached to an entity or place, ticking ~0.5 s; same-source auras do not stack; zones can be destroyed (Qi Well) — so zones need HP.
- **Summons (32, 47, 52):** entities with owner, HP, lifetime, Qi drain per second and a cap from Will; despawn when the owner leaves; count toward a per-player entity cap.
- **Terrain-changing Arrays/walls (25, 52):** server-owned parts with collision; per-player cap; must work with StreamingEnabled.
- **Cross-Kith synergies (14, 15, 40):** Weave supports modify the core's delivery parameters (range, pierce, bounce) or add on-hit effects; conditional tags ("+X vs slowed"). Supports have no delivery of their own (Inh).
- **Moveset swap (44):** temporary override of the equipped moves; restore cleanly on expiry or death.
- **Cost forms (27, 28):** reservation of max Qi and cost substitution (HP for Qi) — not just "spend N Qi".
- **Per-viewer info (31, 35, 41):** the server sends tags (stealthed, exact Rank); each client decides what to render. Stealth must still be validated server-side for targeting.
- **Non-combat sources (19–21, 34):** Crucible, Upkeep and Strain apply the same status/modifier types as combat.
- **Persistent modifiers (13, 16, 33, 36):** Path-scoped modifiers saved in the profile, recomputed at login, never stored as final numbers (ARCH §9).

## 5. Spike code review (Crescent Cut)
- `src/shared/Kith/CrescentCut.luau` (pure, tested): `damageFor`, `tryCast` (cost + cooldown check), aim validation and flattening, projectile stepping, pierce via `registerHit`.
  - **Keep:** the pure-module pattern, aim validation, server-simulated projectile stepping and pierce counting — they become the generic **Projectile delivery** with parameters from data.
  - **Refactor:** `damageFor` → the R-022 damage pipeline (Core hue, Marks, Friction); per-Kith modules → one data record per move.
- `src/shared/Qi.luau` (pool, regen, spend): **keep**, extend into a Resource module with reserve, regen modifiers and HP substitution.
- `src/server/Abilities.luau`: per-player pools, one `lastCast` per player, a shot list swept each Heartbeat with blockcasts.
  - **Keep:** intent-only remote (aim direction), server sweep, publish of Qi.
  - **Refactor:** cooldowns keyed by (caster, moveId); one generic `CastRequest(moveId, aim)` remote; effects applied through one Effect pipeline.
- `src/client/CrescentFx.luau`, `AbilityInput.luau`: **keep** the instant-play feel; key FX by `fxId` from data (cast/travel/hit/loop/end hooks) instead of per-ability scripts.
- `src/shared/Config.luau`: values move into move data; Config keeps global tuning only.

## 6. Pass/fail checklist for R-021
A framework passes only if every row in §2 can be written as **data** (no new code per Kith) and it supports:
1. All triggers in §1, including passive, on-hit, on-damaged, system events and area enter.
2. All deliveries, including Inh (supports modify the core) and Sum (entities with HP, owner, lifetime).
3. Effects as composable lists (e.g. Dmg + Heal, Disp + Dmg) in one move.
4. Timed, channelled, persistent and stacking effects with stack caps and refresh rules.
5. Costs: Qi, Strain, HP substitution, max-Qi reservation, charges, cooldowns keyed per move.
6. One Channel primitive with interrupt tags (rows 5, 22, 29, 38, 46).
7. Tags/states queried by other effects (guarding, slowed, stealthed, transformed) and by conditions.
8. Path-scoped modifiers (Marks, Heart, Imprints, Friction cap) feeding one stat calculation (R-022).
9. Non-combat systems (Crucible, Upkeep, Strain) applying the same status/modifier types.
10. Per-viewer information without trusting the client.
11. Server authority for every hit, cost and state; client prediction for animation and FX only.
12. FX hooks (cast, travel, hit, loop, end) referenced by id.
13. Moveset override with clean restore.
14. Save-safe: persistent parts store sources (Marks, Imprints, Bond), never final numbers.
15. Mobile/server budget: aura/zone ticks ≥ 0.5 s; caps on entities per player.
Scoring: a framework that fails any of 1–11 is rejected; 12–15 may be added on top.