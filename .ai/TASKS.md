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
- **P-006 [blocked: owner] [S] Approval gate:** summary ready in `.ai/P-006-summary.md` (S7); waiting for the owner's OK.
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
- **T-006 [blocked] [S] Owner playtest:** publish to a private test place only with the owner's explicit OK; owner plays in the normal Roblox app; feedback saved to the inbox. Needs place ID + Open Cloud key.
- After the spike: P-002 … P-006 continue.

## Phase 3 — Building (defined in P-005)
- **T-002 [todo]** Replace the obby sample code (RoundState, HUD) with the P-004 skeleton. Keep `check.sh` green.
- **T-010 [blocked]** Cloud test pipeline: Open Cloud place upload + Luau Execution task + test runner. Needs a place ID and an API key (owner, via a custom integration).
- **M1 tasks T-011 … T-024 [todo]:** see `.ai/ROADMAP.md` (IDs, scope and AC). Order: T-002 → T-010 → T-011 …