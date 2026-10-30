# GDD — Robby v1

Status: **v1 complete (P-002a/b, S6)** — awaiting owner review in P-006. The obby draft is in `.ai/archive/GDD-obby-v0.md` (superseded, D-013).
Inputs: VISION.md, RESEARCH.md (R-011…R-019), D-025 (concept A, RI-like structure), SPIKE.md. All names are working names; nothing from RI is used (D-014).
Numbers are first targets to tune in playtests.

## 1. Pitch: one line plus three pillars
**A cunning-cultivation action RPG: bind living Kith, grow your Core, and outwit rivals across an open world of Five Reaches.**
1. **Living powers.** Every move comes from a Kith you found, bound, fed and fused. The build is the collection.
2. **Rell Seas-grade combat.** Instant, readable and weighty: hit-stop, VFX and SFX on every hit, server-decided (R-013).
3. **Climb by wits.** Scarce resources, risky fusions and rival cultivators reward planning over grinding.

## 2. World & tone
- **Setting:** an original mountain-and-mist world split into **Five Reaches** by **Veils** (see §7). Each Reach has its own climate, Paths and factions. Players start in one Reach (named in P-002b) and later cross the barriers.
- **Tone:** ambitious, sly, scarce; mentor figures who are not trustworthy; victories bought with planning. The darkness comes through **strategy and rivalry, never cruelty**.
- **Grim world, rewarding play (R-020d):** the world is cold and survival-of-the-fittest, but the player gets frequent wins, clear goals and very little text. Systems are the star: every rule is consistent and learnable, and smart builds beat raw grind.
- **Anti-genre-trap rules (R-020d):** no "click to boost a stat" loops; skill-based combat; every progression step offers a build choice.
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
| Acquire | **Binding** | Weaken a wild Kith, then win a **tug-of-war** against its Will: channel Qi while it pushes back in pulses; stop channelling and the bar slides back; Shards top up Qi mid-duel. Failure means it flees. Kith drop from the world and are never bought (R-020a). |
| Heart | **Heart Kith** | The first Kith you Bind becomes your Heart Kith: a permanent passive and your identity. It can never be lost and is upgraded by each Rank breakthrough (R-020a/d). |
| Equip | **Core slots** | 3 active Kith at Rank 1, +1 per Rank (max 7 in Mortal). Each Kith grants 1–2 moves. |
| Feed | **Upkeep (Satiety)** | Each Kith eats its own material. Higher-Rank Kith eat less often; heavy fighting drains Satiety faster. Hungry = weaker; starved = **Dormant** (unusable until fed a rarer meal). Never lost (R-020a). |
| Rest | **Strain** | Each Kith move adds Strain; full Strain = the Kith is **Exhausted** for ~20 s. Rewards rotating a set over spamming one move. One-shot **consumable Kith** (traps, burst heals) drop as loot. |
| Roles | **Role tags** | Every Kith has one role: Strike, Guard, Mend, Carry, Stride or Seek. The loadout screen warns about gaps (e.g. no Guard) (R-020b). |
| Combine | **Crucible** | Merge 2–3 Kith plus a catalyst into a higher-rank Kith through a short **focus mini-game** while Shards are fed in. Known recipes are safe. Experimental ones show a fail chance: on fail the catalyst is lost and one component is **Wounded** (weaker for a day), never destroyed. A rare **Second Chance** Kith allows one rewind of a failed Crucible or Binding per day. |
| Combo | **Weaves** | A Weave = **1 core Kith + 1–3 supports**, built at rest in the **Weave Loom**. The core sets the effect; each support adds one modifier (range, burst, slow, pierce). Costs more Qi and Strain. Hint scrolls reveal partial Weaves; the Loom glows ("resonance") on a valid pair, so there is no blind guessing. Each player names and colours one **Signature Weave**, shown on their profile and in kill feeds (R-020b/d). |
| Rank up | **Ranks 1–9 × Stages** | Each Rank has 4 Stages (First, Second, Third, Peak), shown as a **Core Shell** whose material changes per Stage (mist → water → stone → crystal). Shards plus Path Marks fill the bar. A Rank breakthrough is a short trial: crack the shell in waves; on fail the cracks heal slowly, so a quick retry keeps some progress (R-020a). |
| Identity | **Paths** | 5 at launch: Moon, Wind, Flame, Stone, Tide (one sub-Path each, later). **Path Marks** add % power to that Path's moves, with visible VFX upgrades at thresholds. A **Friction wheel** marks allied and opposed Paths; opposed supports in a Weave cut its power (shown in the Loom), so builds favour a main + secondary Path. |
| Skill | **Mastery** | Per-Path tiers Initiate → Adept → Master → Sage → Paragon, earned by use and separate from Rank. They unlock Weave slots, cheaper Weave edits and better Crucible odds (R-020b). |
- **Qi:** Rank 1 pool of 100, regen 5/s (Config). Pool size scales with Rank and Talent. Each Rank has its own **Core hue** for UI and VFX; moves scale with the wielder's hue, so early Kith stay useful.
- **Shards:** both the currency and a Qi refill — spend now to heal Qi, or save for the Crucible (R-020a).
- **First Kith:** Crescent Kith → Crescent Cut (SPIKE.md). Its natural Crucible upgrade is a rank 2 twin-crescent. An early sought-after prize is a **Qi-refining utility Kith** that speeds Stage gain (R-020d).

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
- **Rank gap (R-020c):** each Rank is a big jump (≈ ×1.6 Qi potency, tuned in P-007). Enemies 1 Rank above show a warning colour; 2 above are near-unwinnable.
- **Rank 3 milestone:** "full cultivator" title and a house slot. **Talent** sets a soft cap and Qi regen only; resources and Mastery let anyone climb.
  - Every session must move a bar (Stage, Marks or a new Kith), even a 15-minute one.
- **Scarcity rule:** Kith and catalysts are earned in the world, never sold. Shard income per hour is capped by zone tier so that higher Reaches matter.

## 7. World structure
- **Five Reaches** (working names): **Mistvale** (start, temperate valleys, Moon/Wind Paths), Ember Steppe (Flame), Stonecrown (Stone), Tidefall coast, and the Hollow (endgame). **Veils** between Reaches need a Rank gate (Reach 2 at Rank 2, and so on) and a short Veil trial where stats are briefly damped; high-Rank players are damped in starter Reaches (anti-grief).
- **A society per Reach (R-020c):** Mistvale = bloodline Clans; Ember Steppe = nomad bands; Tidefall = island houses; Stonecrown = merit **Halls** (join by an entrance skill trial; Hall rank unlocks rare Kith and recipes); the Hollow = no rule.
- **Clan hub (Mistvale):** an NPC **Elder Council** pays monthly stipends by contribution; the **Mission Hall** board holds daily bounties; two rival elders offer side quests, and their favour unlocks their Weave hints.
- **Path Ground:** some zones and boss arenas buff one Path and debuff its opposed Paths, so Reach and party mix matter.
- **Mistvale layout:** a safe hub village (shops, Crucible, rest, journal), 3 hunting zones of rising tier, 1 Binding grove, 1 rival camp, and 1 boss arena.
- **NPCs:** a sly mentor (Opening Rite, tutorial quests), a Crucible keeper, a Shard trader, Clan and Rogue recruiters, and rival cultivators (bounty targets).
- **Quests:** a short main chain per Reach, daily bounties, Binding hunts for named Kith, and Weave discoveries (hint scrolls).
- **Tech:** StreamingEnabled from day one; mobile-first budgets (R-016).

## 8. First 10 minutes
| Time | Beat |
|---|---|
| 0:00–0:30 | Spawn in the Mistvale village at dawn; the mentor calls you to the Opening Rite. No menus. |
| 0:30–1:30 | Opening Rite: the Core opens (VFX burst) and the Talent grade is revealed. The Crescent Kith is given to you. |
| 1:30–3:00 | Fire Crescent Cut at training dummies (the spike). Prompts teach the move, dash and Qi. |
| 3:00–5:00 | First zone: weak beasts, Shards drop. A wild Kith appears; first Binding mini-fight (guided, cannot fail). |
| 5:00–7:00 | Back in the village: feed both Kith, equip the second, see the Stage bar move. |
| 7:00–9:00 | A rival cultivator ambushes you — the first parry prompt; win, and they drop a Weave hint. |
| 9:00–10:00 | The Crucible keeper shows a locked recipe and the barrier to Reach 2: clear long-term goals. |
- Rule: something new every ≤ 60 s; no text wall over 2 lines (low bounce).

## 9. Social
- **Co-op:** parties of up to 4; shared kills and Shards; Binding credit goes to whoever lands the bind.
- **PvP:** opt-in only — duels by invite and marked PvP zones. No ganking of PvP-off players. Rank-banded matchmaking for arenas later.
- **Clans:** a player-made Clan joins either the Clans or the Rogues faction at Rank 2. Faction perks are cosmetic or quest access, not raw power. The split is **morally grey**, not good vs evil: Clans get stipends, safe storage and guards; Rogues get bounty hunting, black-market Crucible recipes and freedom to play selfishly (within Roblox rules), but no stipend.
- **Trading:** Shards and materials only; Kith are untradable (scarcity rule, §6).

## 10. Monetisation
- **Principle:** no pay-to-win; Roblox policy-compliant; no random paid loot boxes.
- **Sells:** cosmetics (robes, Core-hue trails, VFX skins), hub housing décor, a battle-pass with cosmetic rewards and small Shard boosts, extra journal/loadout slots, private servers.
- **Never sells:** Kith, catalysts, Ranks, Stages, or damage.
- Premium currency (working name **Jade**) is bought with Robux only and spends only on the list above.

## 11. Vertical slice definition
- **Content:** Mistvale hub + 1 hunting zone + Binding grove + 1 boss; 3 Kith (Crescent, a Stone guard Kith, a Wind dash Kith); 1 Crucible recipe; 1 Weave (core + 1 support); 1 Qi-refining utility Kith; Ranks 1→2 playable; the first 10 minutes from §8.
- **Systems:** Qi, Binding (tug-of-war), Heart Kith, Upkeep (Satiety), Strain, role tags, Crucible, Stages (Core Shell), Path Marks, Weave Loom, save data (ProfileStore), PC + mobile + gamepad controls.
- **Quality bar:** the measurable bar in `.ai/ART.md` (P-003), built on R-013: instant client feedback, hit-stop/VFX/SFX on every hit, telegraphed boss attacks, stable 60 fps on mid-range mobile.

## 12. Out of scope (for now)
- Ascendant Ranks 6–9 (incl. world-unique **Singular Kith**), Reaches 2–5, Arrays and **Party Arrays**, **Hybrid Weaves**, sub-Paths, the **Wild Surge** server event (M2), **Legacy Vault** dungeons with Warden rules (M2–M3), ranked PvP, trading UI polish, housing, voice chat, localisation, and the battle-pass.
- Revisit after the vertical slice playtest (P-005 roadmap).
