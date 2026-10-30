# GDD — Robby v1

Status: **§1–6 written (P-002a, S6); §7–12 in P-002b.** The obby draft is in `.ai/archive/GDD-obby-v0.md` (superseded, D-013).
Inputs: VISION.md, RESEARCH.md (R-011…R-019), D-025 (concept A, RI-like structure), SPIKE.md. All names are working names; nothing from RI is used (D-014).
Numbers are first targets to tune in playtests.

## 1. Pitch: one line plus three pillars
**A cunning-cultivation action RPG: bind living Kith, grow your Core, and outwit rivals across an open world of Five Reaches.**
1. **Living powers.** Every move comes from a Kith you found, bound, fed and fused. The build is the collection.
2. **Rell Seas-grade combat.** Instant, readable and weighty: hit-stop, VFX and SFX on every hit, server-decided (R-013).
3. **Climb by wits.** Scarce resources, risky fusions and rival cultivators reward planning over grinding.

## 2. World & tone
- **Setting:** an original mountain-and-mist world split into **Five Reaches** by impassable barriers. Each Reach has its own climate, Paths and factions. Players start in one Reach (named in P-002b) and later cross the barriers.
- **Tone:** ambitious, sly, scarce; mentor figures who are not trustworthy; victories bought with planning. The darkness comes through **strategy and rivalry, never cruelty**.
- **Maturity:** Roblox **Mild** (D-024). Stylised hits with no blood, corpses or gore. Kith **merge**, never devour. Defeat means a stagger and a respawn.
- **IP line (D-014):** use only mirror concepts from R-019. No RI names, places, characters, plot or text.

## 3. Core loop
- **Moment-to-moment (seconds):**
  - Move, aim and fire Kith moves.
  - Chain light attacks into a move, then dash, parry or break guard.
  - Manage **Qi** (spend, regen) and cooldowns.
- **Session (15–30 min):**
  - Leave a safe hub and take one or two goals (hunt, gather, Binding attempt, rival bounty).
  - Fight through a zone, collect **Shards** and Upkeep materials, and Bind one wild Kith.
  - Return to rest, feed the Kith, try a **Crucible** fusion or advance a **Stage**.
- **Long-term (weeks):**
  - Climb Ranks 1→5 (Mortal).
  - Master a **Path** (Marks), build signature **Weaves**, and choose **Clans or Rogues**.
  - Unlock further Reaches. Ranks 6–9 (Ascendant) are endgame, after launch.

## 4. Cultivation & power system
| Step | System (R-019 mirror) | Rule |
|---|---|---|
| Start | **Opening Rite** | Tutorial: the Core opens; a **Talent grade** (A–D) sets the Qi pool size. It can be improved later and is never a hard lock. |
| Acquire | **Binding** | Weaken a wild Kith, then win a short timing mini-fight to bind it. Failure means it flees. Kith drop from the world and are not bought. |
| Equip | **Core slots** | 3 active Kith at Rank 1, +1 per Rank (max 7 in Mortal). Each Kith grants 1–2 moves. |
| Feed | **Upkeep** | Each Kith eats one material per in-game day (light upkeep; it is never lost, but a hungry Kith is weaker until fed). |
| Combine | **Crucible** | Merge 2–3 Kith plus a catalyst into a higher-rank Kith. Known recipes are safe. Experimental ones carry a visible fail chance (lose the catalyst, keep the Kith). |
| Combo | **Weaves** | Trigger an ordered sequence of equipped Kith moves to unleash a stronger move at a higher Qi cost. Discovered, then recorded in a journal. |
| Rank up | **Ranks 1–9 × Stages** | Each Rank has 4 Stages (First, Second, Third, Peak). Shards plus Path Marks fill the bar; a Rank breakthrough is a short trial fight. |
| Identity | **Paths** | Moon, Flame, Stone, Wind… Same-Path moves gain Marks. Mixing Paths costs +Qi. |
- **Qi:** Rank 1 pool of 100, regen 5/s (Config). Pool size scales with Rank and Talent. Each Rank has its own **Core hue** for UI and VFX.
- **First Kith:** Crescent Kith → Crescent Cut (SPIKE.md). Its natural Crucible upgrade is a rank 2 twin-crescent.

## 5. Combat
- **Controls (one binding set via ContextActionService):**
  | Input | PC | Mobile | Gamepad |
  |---|---|---|---|
  | Moves | E / left-click (Crescent Cut), Q, R | on-screen buttons | X / Y / B |
  | Light chain | left-click | tap | RT |
  | Dash | Shift | dash button | B |
  | Parry/guard | F | guard button | LB |
- **Moves:** a 5-hit light chain. Each Kith move is a ranged or melee ability. Dash has i-frames. A parry in a tight window staggers the attacker. A guard-break counters turtling. Weaves are high-cost finishers.
- **Feel targets (R-013):** the client animates instantly; hit-stop of about 3 frames; spark, flash and number on every hit; small non-drifting camera shake; bosses telegraph every big attack.
- **Server validation (AGENTS §6):**
  - The server owns Qi, cooldowns, hit detection (it simulates projectiles and blockcasts itself) and damage.
  - Clients send only intent plus an aim direction. Rewind tolerance is decided in P-004 (R-016).
  - Proven in the spike (T-004).
- **PvE first.** PvP rules are in §9 (P-002b).

## 6. Progression & economy
- **Currencies:**
  - **Shards** (soft): from kills, nodes and quests; used for Stage progress, Crucible catalysts and the shop.
  - **Marks** (per Path, not tradable): earned by using same-Path moves.
  - A premium currency is defined only in §10, with no pay-to-win.
- **Sinks:**
  - Stage and Rank progress, which costs the most Shards.
  - Crucible catalysts.
  - Upkeep materials, which can be bought when not gathered.
  - Cosmetic hub items.
  - Respec of Talent and Path.
- **Pacing targets:**
  | Milestone | Target |
  |---|---|
  | First Kith bound | ≤ 5 min |
  | Rank 1 → 2 | ~2 h |
  | Rank 2 → 3 | ~5 h |
  | Rank 5 (end of Mortal) | ~40 h |
  - Every session must move a bar (Stage, Marks or a new Kith), even a 15-minute one.
- **Scarcity rule:** Kith and catalysts are earned in the world, never sold. Shard income per hour is capped by zone tier so that higher Reaches matter.

## 7. World structure
TODO (P-002b)
## 8. First 10 minutes
TODO (P-002b)
## 9. Social
TODO (P-002b)
## 10. Monetisation
TODO (P-002b)
## 11. Vertical slice definition
TODO (P-002b)
## 12. Out of scope (for now)
TODO (P-002b)