# TASKS

- **Status:** todo | doing | done | blocked.
- **Size:** S is about 30 OLU of work or less and fits one 50-OLU session. M must be split into S sub-tasks (`X-0NNa`, `X-0NNb`, …) before starting (AGENTS.md §0).
- **AC:** acceptance criteria. A task is done only when every AC is met and saved.

## Phase 0 — Setup (done)
- **T-001 [done] Scaffold:** toolchain, Rojo project, check/bootstrap scripts, `.ai/` memory, sample code.
- **S-003 [done] Session system hardening:** AGENTS boot for fresh bots, research inbox, `search.sh`/`save.sh`/`olu.sh`, VISION, owner guide `SESSIONS.md`.

## Phase 1 — Research  ← current
Every task follows AGENTS.md §4.2: findings with sources, → implications, unknowns, ≤25 lines in RESEARCH.md, plus notes if needed.

- **R-001 [done] Dev best practice** (still valid).
- **R-002 [done] Platform scan:** discovery signals, monetisation rules. Obby parts archived.
- **R-010 [todo] [S] Process owner inbox** (repeat whenever there are new files):
  - For each file in `research/inbox/` not yet listed in VISION.md "Owner ideas", add an entry with the date, file name and the owner's key points in their own words.
  - Flag conflicts with D-014 (IP) or Roblox policy to the owner. Don't silently drop anything.
  - AC: every inbox file is listed in VISION.md.
- **R-011 [done] [S] Source study: Reverend Insanity.** (S4)
  - Cover the world structure, the Gu system (types, refinement, feeding, combining, ranks 1–9), cultivation (aperture, essence), factions/clans, the early-story setting, tone and themes, and what readers love most.
  - Split everything into (a) **game-able mechanics**, (b) IP-specific elements we must not copy, and (c) generic or folklore elements (gu lore, xianxia tropes).
  - AC: `research/notes/R-011-reverend-insanity.md` plus a summary in RESEARCH.md.
- **R-012 [done] [S] IP & licensing:** (S4, D-023)
  - Find the rights holder(s). Check whether game rights or licensing are available.
  - Collect Roblox DMCA/IP enforcement cases for fan games.
  - Define what "inspired by" safely allows (mechanics, themes) and what it doesn't (names, characters, plot, art).
  - AC: confirm or revise D-014, with reasons.
- **R-013 [done] [S] Rell Seas teardown:** (S4; quality bar draft in notes)
  - Cover the core loop, combat (moves, hitboxes, feel), progression, world structure and size, quality markers (VFX, animation, UI, map art, audio), monetisation and social features.
  - Include the developer, team size, development time and update cadence, what players praise and complain about, and visits/CCU if public.
  - AC: a draft of a measurable "quality bar" list for P-003.
- **R-014 [done] [S] Comparable Roblox games:** (S4)
  - Cover cultivation/xianxia/wuxia and anime RPG games on Roblox: names, core loops, player counts, what works and what fails.
  - Note any existing RI-inspired Roblox games.
  - AC: a table of 5–8 games, plus gaps Robby can own.
- **R-015 [done] [S] Headless asset pipeline feasibility:** (S4; route table in notes)
  - For each asset type (meshes, textures/images, animations, VFX, audio, terrain/maps, UI art), find:
    - whether Roblox Open Cloud APIs can upload it (the Assets API: types, scopes, limits)
    - whether Blender headless in the VM can make it
    - whether Creator Store assets can be used (licensing)
    - what AI generation can do (e.g. PromptQL's `__higgsfield` for images)
    - what needs an owner step in Studio or a hired artist
  - **Known (S3):** Blender 4.2 LTS runs headless in the VM (`scripts/blender-setup.sh`). `art/blender/smoke_test.py` builds a mesh and exports FBX/GLB/OBJ. Still to research:
    - Roblox import limits (triangles, size, skinned meshes, PBR/SurfaceAppearance)
    - Open Cloud Assets API upload of models and images
    - Blender → Roblox animation export
    - quality reachable by scripted modelling vs owner-provided models (`assets/source/`)
  - AC: a route table (asset type → route, quality, cost, owner involvement).
- **R-016 [done] [S] Tech for a high-quality action RPG on Roblox:** (S4; stack table in notes)
  - Cover:
    - combat netcode (client-predicted hits vs server validation)
    - animation and VFX systems
    - StreamingEnabled and large maps
    - mobile performance budgets
    - libraries (ProfileStore, networking, Trove/Signal, the state of Knit-like frameworks)
    - cloud testing (Jest-Lua, the Luau Execution API from R-001)
  - AC: a recommended stack with reasons, as input to P-004.
- **R-017 [done] [S] Content maturity & audience:** (S4, D-024)
  - Cover Roblox Maturity & Compliance labels, rules on violence, blood and dark themes, and age-gated features.
  - Recommend a label and how to adapt RI's tone.
  - AC: a recommendation logged for P-002.
- **R-018 [done] [S] Research synthesis:** (S4; Options in RESEARCH.md)
  - Write 3 distinct concept options. Each needs a one-line pitch, core loop, hook, a vertical-slice idea, risks, and build cost.
  - Add a recommendation.
  - AC: an "Options" section in RESEARCH.md that P-001 can present as-is.

- **R-019 [done] [S] RI systems map + first-ability pick** (S5; Crescent Kith → Crescent Cut) (owner request 2026-10-30, D-025):
  - Table: each major RI system (creatures, ranks/stages, aptitude, essence, feeding, refinement, fusion, killer moves, paths, formations, clans/outcasts, regions) → Robby equivalent with our own name, the way Rell Seas mirrors One Piece.
  - Pick the test ability: a popular RI creature with a flashy move (candidate: the moonlight crescent-blade one), renamed; describe its move, VFX and feel.
  - AC: `research/notes/R-019-systems-map.md` + RESEARCH.md summary.

## Phase 2 — Planning (ends with owner approval)
- **P-007 [done] [S] Spike plan** (S5): `.ai/SPIKE.md`. Owner OK on the publish route is asked at T-006.
- **P-001 [done] [S] Concept pick:** owner chose A, structured like RI (D-025).
  - Present the R-018 options to the owner in plain language, with a recommendation. Then end the session and wait.
  - AC: the owner's choice is logged as a decision.
- **P-002a [done S6] [S] GDD v1 part 1 (§1–6):** AC: §1–6 filled, no TODOs.
- **P-002b [done S6] [S] GDD v1 part 2 (§7–12):** world structure, first 10 min, social, monetisation, vertical slice, out of scope. AC: no TODOs left in GDD.md.
- **P-002 [done S6, via P-002a/b] GDD v1:**
  - Fill in every section of the GDD.md template for the chosen concept.
  - AC: no TODOs left. Split it across sessions if needed.
- **P-003 [done S6] [S] Art direction, asset plan & quality bar:** `.ai/ART.md` —
  - Cover the style, palette, references, the asset list for the vertical slice with a route for each (from R-015), and the measurable quality bar (from R-013).
  - Also list the owner actions needed (accounts, assets, Studio steps).
  - AC: `.ai/ART.md`.
- **P-004 [done S6] [S] Technical architecture:**
  - Cover the stack (from R-016), module map, networking, data (ProfileStore), and how the sample code gets replaced.
  - Include the testing plan: Lune unit tests, cloud tests, and owner playtests.
  - AC: ARCHITECTURE.md rewritten.
- **P-005 [done S6] [S] Roadmap:** `.ai/ROADMAP.md`
  - Milestones: M1 vertical slice → M2 core content → M3 progression and economy → M4 polish → M5 soft launch.
  - Rewrite Phase 3 below as S-sized T-tasks with AC.
  - AC: `.ai/ROADMAP.md`, and `.ai/PLAYTEST.md` (a checklist the owner runs in Studio at each milestone).
- **P-002c [done S7] [S] GDD v2:** apply the R-020 change list (`research/notes/R-020d-fan-values-gdd-changes.md` §2) to `.ai/GDD.md`; mirror names only (D-014). AC: GDD sections updated, parked items listed in §12, D-034 logged.
- **P-003b [done S7] [S] Phone HUD mock v1:** `art/mocks/hud-v1.html` — Strain/Satiety live on Kith buttons so only 2 bars (health, Qi). Answers the R-020 HUD-load unknown; owner feel-and-look check in P-006.
- **P-003c [done S7] [S] Weave Loom mock v1:** `art/mocks/weave-loom-v1.html` — one screen: Kith list, core + 3 support slots with resonance thread, live preview incl. Friction. Answers the R-020b Loom-on-phone unknown.
- **P-006 [done S8] [S] Approval gate:** owner approved 2026-10-30 (`research/inbox/2026-10-30-owner-p006-approval.md`, D-049).
  - Give the owner a short plain-language summary of the plan.
  - AC: the owner approves, and this is logged as a decision. Building starts only after this.

## Phase 2b — Capability spike (owner request, allowed before P-006 by D-025)
- **T-003 [done] [S] Ability core:** (S5) `src/shared/Qi.luau` + `src/shared/Kith/CrescentCut.luau`, Lune tests (25 pass). AC: `check.sh` PASS.
- **T-004 [done S6] [S] Ability wiring + VFX:** server remote, client input (key + mobile button), code-built VFX (Beam/Trail/Particles), placeholder SFX, a training dummy; `rojo build` makes a place file. AC: build succeeds, check PASS.
- **T-005 [done S6] [S] Headless verification:** report `research/notes/T-005-verification.md`; local inspect PASS, cloud split to T-005b — inspect the built place with Lune; cloud test via Luau Execution if a place ID + Open Cloud key exist. AC: a written pass/fail report.
- **T-005b [done S6] [S] Cloud test:** `python3 scripts/cloud_test.py [version]` uploads build as a Saved (unpublished) version + runs `tests/cloud/smoke.luau` via Luau Execution. CLOUD: PASS on version 3 (dummy HP 200→180). Report: `research/notes/T-005-verification.md`.
- **R-020 [done S7, via R-020a–d] [M] Deep Reverend Insanity research (owner, 2026-10-30):** quality over quantity. Go beyond R-011/R-019: the Gu system in depth (ranks, refinement, feeding, aperture), Paths and killer moves, factions and world structure, pacing of progression, and what fans value most. Each finding sourced; map each to an original mirror concept (D-014). AC: `research/notes/R-020-*.md` + RESEARCH.md entry + a list of GDD changes for P-006. Split (S7) into:
  - **R-020a [done S7] [S] Gu system in depth:** ranks, refinement/recipes, feeding/upkeep, aperture & essence, Gu loss/death. AC: `research/notes/R-020a-gu-system.md` (sourced, each finding → original mirror) + RESEARCH.md entry.
  - **R-020b [done S7] [S] Paths & killer moves:** Path list, attainment, killer-move composition, combat roles. Same AC shape (`R-020b-paths-killer-moves.md`).
  - **R-020c [done S7] [S] World structure, factions & progression pacing:** regions, clan/sect politics, rank pacing over the story, power gaps. Same AC shape (`R-020c-world-factions-pacing.md`).
  - **R-020d [done S7] [S] What fans value + GDD change list:** fan-favourite moments/mechanics (reviews, forums), then a consolidated GDD change list for P-006. AC: notes + RESEARCH.md entry + list.
- **R-021…R-026 Foundations research (owner, 2026-10-30: "solid and flexible from the start"):** R-020 covered the source (*what*); these cover *how* to build systems that won't need rewrites. Each [S], one per session, same RESEARCH.md format + `research/notes/R-02x-*.md`.
  - **R-027 [done S8] [L] Owner directive list — critical pass (run FIRST, in ONE session; owner, D-040):** process every point (44 non-empty lines) of `research/inbox/2026-10-30-owner-directive-list.md`. The list was written by another AI: a directive, not the source of truth. For each point: verify against the source (R-011/R-020a–d notes first; search only when needed), then decide **Adopt / Adapt / Salvage / Park / Reject** with a one-line reason. **Playability comes first** (owner, D-041): what works in a novel may not work in a game. Points are not all-or-nothing: split a point into its parts and judge each part. Adopt = use as is; Adapt = keep the idea, change the form to play well; Salvage = the point is mostly unplayable, keep only the small viable mechanic inside it (name that mechanic); Park = good but later; Reject = no playable part. Tie-breakers after playability: mobile clarity, server cost, IP rule D-014 (mirror names only). AC: (1) `research/notes/R-027-directive-triage.md` with a table point (or sub-part) → verdict → extracted mechanic → Robby mirror → affected GDD section/system; (2) GDD updated for all Adopt/Adapt/Salvage items across **system architecture** (ARCHITECTURE.md notes for P-008), **world-building** (§2, §7, §9) and **gameplay loop** (§3–§6); parked items in §12; (3) new open questions added to R-021p's catalogue input; (4) D-0xx logged, RESEARCH.md entry, save. Budget: triage table by ~25 OLU, GDD edits by ~40, close-out by 45. Resume from: the triage table, top to bottom.
  - **R-021p [done S8] [S] Ability needs catalogue (prerequisite, run BEFORE R-021; owner suggestion, D-039):** define what the framework must express before choosing one. AC: `research/notes/R-021p-ability-catalogue.md` with (1) ~40 representative abilities: every GDD v2 mechanic (Kith moves, passives, consumables, Heart Kith, Weave core + supports, Path Marks, Friction, Path Ground, Strain/Satiety/Dormant/Exhausted/Wounded, Guard, Binding channel, Crucible, Second Chance rewind, Arrays, auras) plus ~15 iconic source effect types (mirrored roles only, D-014); (2) each broken into primitives: trigger, targeting, delivery (melee/projectile/beam/area/self), effect, duration/stacking, costs (Qi/Strain), states/tags, VFX/SFX hooks, network needs; (3) a primitive frequency table and the hard edge cases (rewind, channels, auras, summons, terrain-changing Arrays, cross-Kith synergies); (4) review of the existing spike code (Crescent Cut) — what to keep or refactor; (5) a pass/fail checklist R-021 uses to score each framework. Also include the 11 open questions in `research/notes/R-027-directive-triage.md` §3 (Qi Reserve, Overdraw, Scatter, Qi Wells, Seek layer, summons, Imprints, Recoil, Path Sense, Rank lock/Friction cap, Bond). Resume from: GDD §3–§5 + F-001 §2 + R-027 §3.
  - **R-021 [done S8] [S] Ability/effect frameworks:** Unreal GAS (attributes, effects, tags), Path of Exile support gems (closest to Weave core + supports), Warframe mods, Roblox ability modules. AC: a recommended data-driven model where Kith, Weaves and Paths are data and new Kith need no new code; scored against the R-021p checklist (every catalogue ability expressible as data).
  - **R-022 [done S7] [S] Stats, modifiers & damage math:** additive vs multiplicative stacking, caps, Rank-gap curves, avoiding power creep. AC: draft formulas + a small Python check of curves.
  - **R-023 [done S8] [M] Economy & progression simulation:** faucets/sinks, inflation and trade exploits in Roblox RPGs. AC: a Python sim plan + first results for Shards and Stage pacing.
    - **R-023a [done S8] [S] Economy research + sim plan:** faucets/sinks, inflation and trade exploits in Roblox RPGs (3–6 searches). AC: `research/notes/R-023-economy.md` §1–§3 (findings, Robby faucet/sink map from GDD §4/§6, sim plan with inputs/outputs); RESEARCH.md entry. Resume from: the note §1.
    - **R-023b [done S8] [S] Economy sim + first results:** `research/sim/economy_sim.py` per the R-023a plan. AC: Shard balance and Stage pacing curves vs GDD §6 targets (Rank 1→2 ~2 h, Rank 5 ~40 h); findings + tuning proposals in the note §4.
  - **R-024 [done S8] [S] Save data & live-ops flexibility:** ProfileStore schema migration, feature flags, content versioning, remote config. AC: rules for adding systems without breaking saves.
  - **R-025 [done S8] [S] Combat netcode & anti-exploit:** how top Roblox action games (Rell Seas, Deepwoken, Blox Fruits) handle hits, lag and exploits. AC: confirm/adjust D-030.
  - **R-026 [done S9] [S] Retention & first session:** Roblox RPG D1/D7 benchmarks, onboarding, what keeps players. AC: adjust GDD §8. Done: `research/notes/R-026-retention.md`, GDD §8 first 20 minutes (D-051).
  - **F-001 [done S7] [S] Fidelity audit:** `research/notes/F-001-fidelity-audit.md` — design vs source, gaps fixed in GDD (Clan Academy, Sanctum, Trials of Heaven, rare Second Chance Kith, iconic Kith role list; D-038). *Verify* items go to R-021+ sessions only if needed.
  - **P-008 [done S9] [S] Systems spec:** turn R-021…R-026 into ARCHITECTURE v2 + data schemas (Kith/Weave/Path/Effect). Done: ARCHITECTURE v2 §3, `.ai/SCHEMAS.md` (D-052).
- **T-006 [blocked] [S] Owner playtest:** publish to a private test place only with the owner's explicit OK; owner plays in the normal Roblox app; feedback saved to the inbox. Needs place ID + Open Cloud key.
- After the spike: P-002 … P-006 continue.

## Phase 3 — Building (defined in P-005)
- **T-002 [done S10] Build the ARCHITECTURE v2 skeleton** (split S9 into S-sized parts; owner asked to use the remaining budget):
  - **T-002a [done S9] [S] Math core:** `Tags`, `Stats` (one aggregation), `DamageMath` (R-022) in `src/shared` + `tests/Foundations.spec.luau` (R-022 numbers reproduced). AC: check.sh PASS.
  - **T-002b [done S9] [S] Effects + Moves + Registry:** `Effects` (apply/stack/tick/expire, tags, modifiers), `Moves` (validate costs, cooldown per (caster, moveId)), `Registry` (validates Content records), Lune tests. AC: check.sh PASS. Done: `tests/Abilities.spec.luau`.
  - **T-002c1 [done S9] [S] Crescent as data:** `src/shared/Content/Crescent.luau` (Move + Effect + Kith records built from `Config`), validated by `Registry` in `tests/Content.spec.luau`. AC: check.sh PASS.
  - **T-002c2 [done S9] [S] Projectile delivery:** `src/shared/Deliveries/Projectile.luau` (aim validation, flatten, travel, pierce; reads only Move params) + `tests/Projectile.spec.luau`. AC: check.sh PASS.
  - **T-002c3 [done S9] [S] Server cast path:** `src/server/Abilities` now runs Registry → Moves → Deliveries/Projectile → Effects (onHit) → DamageMath; `Kith/CrescentCut.luau` and its spec deleted; client, inspect and cloud smoke point at the new modules. Not yet playtested in Studio. AC: check.sh PASS.
  - **T-002c4 [done S10] [S] FX registry:** `src/shared/FxRegistry.luau` (fx id → handler, unknown ids counted, handler errors contained) + `src/shared/CastRequest.luau` (moveId + u16 seq validation); CastRequest sends (moveId, aim, seq); CastFx/HitFx carry fxId first; `CrescentFx.register`. 8 tests in `tests/Fx.spec.luau`. Owner Studio playtest of the spike still due.
  - **T-002d1 [done S10] [S] Profile data (pure):** `src/shared/ProfileSchema.luau` (template v1, ordered migrations v0→v1, reconcile, validate, `load`; newer saves refused untouched; resolver injected) + `src/shared/Retired.luau` (chains, loops end); 9 tests in `tests/Profile.spec.luau`. No player data dropped (D-042).
  - **T-002d2 [done S10] [S] Packages:** `wally.toml` (Signal 2.0.3, Trove 1.8.0 shared; ProfileStore lm-loleris 1.0.3 server) mounted at ReplicatedStorage.Packages / ServerScriptService.ServerPackages; Blink 0.18.9 in `rokit.toml`; `net/remotes.blink` = SCHEMAS §9, compiled by check.sh (`PASS net`). bootstrap runs wally with a clean HOME (D-056). Runtime switch to Blink remotes is a later task.
- **T-010 [done S11] [S]** Cloud test pipeline: `cloud_test.py` uploads a Saved version and runs `scripts/cloud_runner.py` output (all Lune specs + packages + smoke) via Luau Execution. AC: `CLOUD ALL: PASS`. **Done S11:** CLOUD ALL: PASS on Saved version 5 (specs 60/60); remotes checked as Net API in Luau Execution (D-060).
- **T-011 [done S10] [S] Blink networking:** spike RemoteEvents replaced by Blink-generated `src/server/Net.luau` / `src/client/Net.luau` (from `net/remotes.blink`, regenerated by check.sh; excluded from stylua/selene/luau-lsp). HitFx carries target + amount. Cloud smoke checks the Blink remotes. Studio playtest still due (owner).
- **T-012 [done S10, cloud part blocked with T-010] [S] DataService:** `src/server/DataService.luau` (ProfileStore session per player, `ProfileSchema.load` in place, refused saves left untouched + kick, `DataService.get`); cloud smoke adds a ProfileStore Mock v1 check.
- **T-013 [done S10] Combat core** (a+b):
  - **T-013a [done S10] [S] Combat core (pure):** `src/shared/Combat.luau` (5-hit chain, dash i-frames, parry window, guard meter + guard-break) + `src/shared/Rewind.luau` (1 s buffer, lookback clamped to 250 ms, injected lerp); `Config.Combat`; 8 tests in `tests/Combat.spec.luau`.
  - **T-013b [done S10] [S] CombatService + input:** `src/server/CombatService.luau` (Blink `Action`, per-player Combat state, 20 Hz/1 s Rewind, checks alive/i-frames/range+4/arc/LoS, parry staggers attacker, chain step 5 breaks guard, token bucket `Config.Combat.rate`) + `src/client/CombatInput.luau` (LMB/RT chain, Shift/B dash, F/LB press parry + hold guard). Crescent Cut moved off MB1 (E/ButtonX). Studio playtest due (owner).
- **T-014 [done S11] [S] HitFeel:** shared client hit-stop/shake/flash/numbers for all moves. Done S11: pure `src/shared/HitFeel` (+ spec), client `src/client/HitFeel` (`fx.combat.hit`), tuning `Config.HitFeel`; Crescent and CombatService hits use it (D-061). Cloud re-run pending (upload timed out S11).
- **T-015 [done S11] [M] Stone guard + Wind dash Kith moves:** Content `Stone.luau` (move.stone_ward → State.Warded) and `Wind.luau` (move.wind_step → State.Iframes + client burst), merged by `Content/All.luau`; tuning `Config.Abilities.StoneWard/WindStep`. Server: Self delivery in `Abilities.luau`, timed tags in pure `src/shared/Status` (shared via `src/server/StatusStore`); Warded/Iframes skip hits in Abilities and CombatService. Client: `AbilityInput` per-move bindings (E/X Cut, Q/Y Ward, R/L2 Step), `KithFx` (ochre ward shell, jade gust). Specs: Kith, Status (D-062). Owner Studio playtest pending.
- **M1 tasks T-011 … T-024 [todo]:** see `.ai/ROADMAP.md` (IDs, scope and AC). Order: T-002 → T-010 → T-011 …
