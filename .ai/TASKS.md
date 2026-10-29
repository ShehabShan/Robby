# TASKS

Status: todo | doing | done | blocked. Size: S (one session) | M (split before starting).

## M1 — Playable core loop
- **T-001 [done] [S] Scaffold** — toolchain, Rojo project, check/bootstrap scripts, AI memory system, RoundState machine + tests, minimal HUD.
- **T-002 [todo] [S] CourseGen (pure)** — `src/shared/CourseGen.luau`: chunk spec type (`id`, `tier` 1–5, `length`, `parts`), `CourseGen.generate(seed, chunkLibrary, stageCount)` returns an ordered list of chunk ids with a difficulty ramp (early stages tier ≤2, last stages tier ≥3), no chunk repeated back-to-back, deterministic per seed. AC: Lune tests for determinism, ramp, no repeats, stageCount respected.
- **T-003 [todo] [S] Chunk library v1 (pure data)** — `src/shared/Chunks.luau`: ≥8 chunks as part specs (size, offset, color, kind: platform/kill/moving later). AC: test that every chunk validates (positive sizes, has a start and an end anchor).
- **T-004 [todo] [S] Course builder (server)** — `src/server/CourseBuilder.luau`: turns a generated chunk list into a Model in Workspace, chaining end anchor → next start anchor; inserts a checkpoint pad per stage and a finish pad. Pure layout math (`Layout.luau` in shared) is unit-tested; builder is thin.
- **T-005 [todo] [S] Checkpoints + finish** — touching a checkpoint stores stage per player; respawn at last checkpoint; touching finish marks player finished with time. Pure `RaceProgress.luau` with tests.
- **T-006 [todo] [S] Race flow wiring** — on Racing: build course from round seed, teleport to start; on Results: teleport to lobby, destroy course.
- **T-007 [todo] [S] Results + rewards (pure)** — rank finishers by time; coins: 1st 30, 2nd 20, 3rd 15, other finishers 10, DNF 2. Tests.
- **T-008 [todo] [S] Lobby (procedural)** — spawn platform, results board, lobby spawn.
- **T-009 [todo] [S] HUD v2** — timer, stage x/N, results list.

## M2 — Persistence & progression
- **T-010 [blocked] [S] Cloud test pipeline** — `scripts/cloud_test.sh`: upload place via Open Cloud, run test suite via Luau Execution API, print PASS/FAIL. Blocked: needs place ID + API key (custom integration).
- **T-011 [todo] [M] Player data** — DataStore-backed coins/wins with session safety (split before starting).
- **T-012 [todo] [M] Trail shop** — buy trails with coins (split before starting).
- **T-013 [todo] [S] Leaderstats** — Coins / Wins on the player list.