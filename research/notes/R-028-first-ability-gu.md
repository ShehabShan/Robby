# R-028 — First proper ability: in-depth Gu research (S40, 2026-10-30)

Owner goal: one Kith made to *very good* final quality, with an R1 (left-click) attack and three specials on Z/X/C.
Source = *Reverend Insanity* (inspiration only, D-014: in-game names, lore and visuals are original).
Sources: sagaofgu.com (Gu entries), master-of-gu.com (rank/range/cost tables), rellseaswiki.com, deepwoken/bloxfruits wikis,
gdquest ranged-attack notes, roclicks VFX budgets. Numbers from the source are "as reported"; game numbers below are initial tuning.

## 1. Candidates (source → what it gives us)
| # | Source Gu (path, rank) | How it works in the source | Visual language | Range / area | Fit with Robby | Verdict |
|---|---|---|---|---|---|---|
| A | **Icicle Gu** (ice/water, R2) + Ice Explosion Gu (R3) | Forms sharp white icicles in the air or at the hand; fires singles **or dense volleys that fall as an "icicle rain" that pierces rock**. Ice Explosion detonates lodged/flying ice; blast scales with ice mass; costs more essence and can hurt the user. | White→pale-blue shards, frost mist, glassy chime; a clear "frost" palette that nothing in Robby uses yet. | Single shot, fan/volley, ground rain = three natural shapes. | Projectile delivery exists; needs Volley + Zone + Burst deliveries and a Chill status. Builds a set-up → payoff loop (shards lodge, then shatter). | **Chosen** |
| B | Moonglow / Moonwhirl Gu (light/moon, R1–R2) | Rank-1 crystal fires a 5 m crescent for 10 % essence; R2 fusion = 3× power, 10 m; Whirlwind fusion = green, **curved** blade. | Blue/green crescents. | Line only. | Already our Crescent Cut (Path.Moon). Curved blade → good *Loom support* later, not a new Kith. | No (redundant) |
| C | Fireball / Fire Lance / Lava Explosion Gu (fire, R2 / R2 / R3) | Fireball 10 m cost 8; Fire Lance 5 m cost 16; Lava Explosion: stonemill-sized arcing lava ball → lava crater. | Red/orange, bright. | Ball, lance, crater AoE. | Great AoE but the crater (R3) breaks Rank 1–2 scope; fire clashes with Mistvale's lantern/mist look. | No (rank/scope) |
| D | Lightning Arrow Gu (lightning, R2–R4) | 15 m arrow, cost 3; Static Step 6 m dash. | Blue-white bolts. | Long line, cheap, single target. | Cheap + long range but thin on area; it is a *better Crescent*, not a different one. | No (thin) |

Why A: it is the only candidate that gives all three shapes (line, fan, ground area) plus a status mechanic, from one coherent source
fantasy, at a rank that matches our Rank 1–2 content. It also reads at a glance in a mist-heavy world (white on grey).

## 2. The Kith: **Rimeshard** (`kith.rimeshard`, Path.Frost)
Original fantasy: a thumb-length frost worm that sleeps as a vein of rime on the back of the hand; when woken it pulls moisture
out of the Mist and freezes it into shards. Lore hook: wild Rimeshards nest where the Mist is thickest (future zone content).
Rank 1 Kith; a Rank 2 Crucible result ("Hoarshard") can follow the Twin Crescent pattern (T-019d) later.

### Core mechanic — Chill
Every Rimeshard hit adds 1 **Chill** stack (max 3, 3 s, refresh on hit): −15 % move speed per stack. At 3 stacks the target is
**Rimed** (visible frost crust). Chill is a pure `Effects` status with a `MoveSpeed` modifier; the server owns it (server authority).
Chill is the thread that makes R1, Z and X *set up* and C *pay off* — the Icicle + Ice Explosion pairing from the source.

### R1 — Needle (left-click)
- **Relation to the light chain:** the light chain stays the default left-click (melee, 5 steps). When Rimeshard is the **active**
  Kith (toggle in the Kith bar / R), left-click becomes the Needle chain. Same `Combat.press` state machine, `steps = 3`,
  `window = 0.8`, `recovery = 0.25`, so timing feels identical and no new input code is needed; only the move table differs.
- Shots 1–2: one thin shard, **5 dmg**, speed 120, range 45, hitbox 1×1×3, maxHits 1, Chill +1, **0 Qi**.
- Shot 3 (finisher): two shards side by side (**5 + 5**), spawnOffset ±1.2, slight knock-back, **3 Qi**. Then chain resets.
- DPS ≈ 12 at range (melee chain ≈ 12 at 6 studs) — parity on paper; ranged safety is paid for with Qi on the finisher and no guard-break.
- Telegraph: none needed (fast, low damage); 0.12 s hand-raise so the shot is readable in PvP.
- VFX: white-blue shard mesh with a short `Trail`, frost puff at the hand, small ice-chip burst + 2-frame hit-pause on hit.
- SFX: glassy "tink" per shot, slightly higher pitch on the finisher. Anim: alternating hand flicks, finisher is a two-hand push.

### Z — Shard Fan (Volley)
- 5 shards in a 30° horizontal fan, **8 dmg** each, speed 100, range 35, each shard maxHits 1; **a target takes at most 2 shards (16)**.
  Chill +1 per shard hit (so a point-blank hit = +2). **10 Qi, 1.8 s cooldown.**
- Role: close-range shotgun / crowd clear vs Mistfang packs. Rewards aiming at a group, punishes spamming (cost ≈ Crescent for less single-target damage).
- Telegraph: 0.2 s wind-up with a visible frost ring on the hand (parryable = yellow cue per Rell Seas convention).
- VFX: five shards leave a widening frost mist "V"; hits chip ice. SFX: layered tinks + whoosh. Anim: wide sweep of the arm.

### X — Rime Fall (Zone)
- Aimed ground circle, **radius 7**, cast up to **40 studs** away (server validates: within range, on ground via raycast).
- Telegraph **0.6 s**: frost decal grows on the ground, shards gather overhead (≥ `minTelegraph` 0.4 s; **red** for enemies — dodge).
- Then **1.0 s rain: 4 ticks × 6 dmg = 24**, Chill +1 per tick (hits 3 stacks fast). Zone leaves a thin frost patch (cosmetic) for 2 s.
- **18 Qi, 8 s cooldown.** Role: area denial and the fast way to Rime a group before C.
- VFX: falling shard meshes (pooled, ~12), snow particles, one impact crack ring. SFX: rising hiss during telegraph → shatter crackle.
  Anim: raise palm to the sky, fist close on the drop.

### C — Shatter (Burst)
- Instant: every Chilled target within **25 studs** takes **12 + 8 per Chill stack** (max 36) and loses all stacks; a Rimed (3-stack)
  target is **staggered 0.4 s**. Targets with no Chill take nothing (no free AoE). Source echo: ice explodes, mass sets the blast.
- **15 Qi, 10 s cooldown.** Role: payoff. Full loop: Z (Chill +2) → R1 → C = 36 for 28 Qi over ~2.5 s; X → C on a group = 60 each.
- Telegraph: 0.3 s clap wind-up, frost veins race from caster to each Chilled target (reads as "this is coming").
- VFX: each target's crust bursts into shards; 3-frame hit-pause and a short screen shake for the caster. SFX: single deep crack + chimes.
- **Key conflict:** C is the Crucible key today (PC C). Decision D-176: Crucible moves to **B** (rest-spot menu, not a combat key);
  Z/X/C become the three Kith special slots for every Kith. Owner may veto.

## 3. Balance vs Rank 1–2 (initial, tune in T-027g)
- Damage per Qi: Crescent 2.0; Needle finisher 3.3 (chain-gated), Fan 1.6 single / up to 8.0 vs a pack, Rime Fall 1.3 + control, Shatter up to 2.4 with set-up.
  Rimeshard trades raw Crescent damage for area and control, so it should not out-DPS Crescent on a single target.
- Mistmaw Elder (800 hp, Rank-1 kill ≈ 102 s with Crescent): Rimeshard rotation ≈ 15 DPS sustained if Qi regen allows one special per ~6 s → ≈ 55–65 s. Too fast → lower Shatter per-stack to 6. Check in sim.
- PvP: Chill max −45 % speed for 3 s; Wind Step (i-frames) and Dash clear nothing but let you escape — intended counterplay. Shatter stagger 0.4 s is below parry stagger (1.0 s).
- Study-top-games note (D-079): Blox Fruits ice stuns disable all input for 2 s on 9–26 s cooldowns; Deepwoken Frostdraw uses chill + area denial.
  Robby borrows area denial + stacking slow and **does better** by never removing player control (slow + short stagger, not a 2 s freeze).

## 4. Framework fit
- `Shared.Content/Rimeshard.luau` built from `Config.Abilities.Rimeshard` (Crescent.luau pattern); tags `Path.Frost`, `Role.Strike|Control`, `Delivery.Proj|Volley|Zone|Burst`.
- New pure deliveries in `src/shared/Deliveries/`: `Volley` (n × Projectile with spread), `Zone` (aim point, radius, delay, ticks), `Burst` (radius, status filter). Lune specs each.
- New effect ops: `Status` (id, stacks, max, duration, modifiers), `DmgPerStack`, `Stagger`. `Effects` already does stack/tick/expire (R-021).
- `Combat`: Kith-stance flag selects which chain table `press` uses. `RemoteGuard`: existing per-player rate guard covers Z/X/C; Zone adds aim-point validation.
- `FxRegistry` ids `fx.rime.needle|fan|fall|shatter|chill`; client `RimeFx.register`. Piercing Edge (Loom) applies to Needle/Fan automatically via `Delivery.Proj`.
- Blink: `CastRequest` already carries (moveId, aim, seq); Zone needs aim as a point, not a direction → one optional field.

## 5. Unknowns
- Qi regen rate vs the proposed costs (read `Config.Resources` in T-027g). Mistfang/Boar HP for pack-clear tuning.
- Whether a 3-step ranged R1 feels too slow on gamepad (test in T-027h).
- Icicle Gu's rank is R2 in the source while Rimeshard is a Rank 1 Kith here — accepted (fantasy, not lore).
## 6. Addendum (S40, owner asked): what top Roblox kits do, and what Rimeshard borrows
Sources: deepwoken.fandom/deepwoken.co (Frostdraw), arcaneodyssey wikis + forum, bloxism/TSB wikis, rellseaswiki, AO forum threads.
- **Deepwoken Frostdraw:** Chill status on most mantras; a build path turns Chill into crystal stacks that **detonate** (same loop as our Chill → Shatter). Ice Lance is parryable on impact *and* on detonation; Ice Eruption is the one unblockable, unparryable move (encases). Stones scale size/count or add detonation/duration — our Loom supports already do this. → Keep Shatter parryable (0.3 s clap), make only Rime Fall the "dodge, don't parry" move.
- **Arcane Odyssey:** explicit size↔damage trade (−10 % size = +3–4 % dmg); Freezing (10 s) upgrades to Frozen (1 s, −50 % speed, +20 % follow-up dmg) via a second element. Forum consensus: AO PvP suffers from stunlock + AoE spam and projectile desync. → Confirms slow-not-freeze (D-177) and a hard cap on Chill (3 stacks, 3 s); add an optional Loom support later that trades Fan spread for damage.
- **TSB / Rell Seas kit shape:** M1 string (4 hits, last hit launches) + 4 specials on 15–30 s cooldowns; combos come from cancelling M1 into a special after hit 3; awakening swaps the special set for ~45 s. → Rimeshard's specials sit at 1.8/8/10 s because Qi, not cooldown, is the main gate (Warframe-style reserve, D-044); allow **Needle shot 2 → Z/X/C cancel** so the kit combos the way players expect (T-027d AC).
- **Player feedback themes:** VFX clutter, long stuns and unreadable moves are the top complaints across all four games; depth and readable telegraphs are the praise. → Rime Fall telegraph 0.6 s with a decal (readable), stagger 0.4 s (short), pooled shards capped at ~12 per cast (clutter budget, T-027e AC).
- **Verdict on R-028 depth:** candidate choice, source lore and framework fit are solid; the top-game study was the thin section and is now covered. No overhaul; refine during T-027g with the sim.
