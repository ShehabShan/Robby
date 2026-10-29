# TASKS

Status: todo | doing | done | blocked. Size: S (fits one session) | M (split before starting).

## Phase 0 — Setup (done)
- **T-001 [done] [S] Scaffold**: toolchain, Rojo project, check/bootstrap/olu scripts, AI memory system, RoundState machine + tests, minimal HUD. Genre-agnostic; kept whatever the final concept is.

## Phase 1 — Research  ← current
- **R-001 [done] [S] Development best practice**: see RESEARCH.md.
- **R-002 [done] [S] Market & content scan (first pass)**: trends, Tower of Hell, discovery signals, monetisation rules.
- **R-003 [todo] [S] Competitor teardown + hook options**: 4–6 top obby/racing/party games (Tower of Hell, a classic stage obby, a "difficulty chart" obby, a party/elimination game). For each, record the core loop, the first 60 s, social features, progression, monetisation and common player complaints. Output: 3 distinct hook options for Robby, each with pros, cons and build cost. AC: RESEARCH.md section R-003 with sources.
- **R-004 [todo] [S] Obstacle & mechanic catalog**: ~20 obstacles/mechanics grouped by tier 1–5. Mark each as mobile-safe or not and as buildable from parts in code or not, and note which teach a new skill. AC: table in RESEARCH.md.
- **R-005 [todo] [S] Retention, progression & monetisation patterns** for ages 9–14: what drives D1/D7 return and 19+ minute sessions, and fair cosmetic models. AC: RESEARCH.md section with → implications.

## Phase 2 — Planning (ends with user approval)
- **P-001 [todo] [S] Concept pick**: present the 3 hook options to the user in plain language with a recommendation; record the choice as a decision.
- **P-002 [todo] [S] GDD v1**: rewrite GDD.md for the chosen concept: core loop, first 60 s, content list, progression, monetisation, social features, out of scope.
- **P-003 [todo] [S] Build roadmap**: milestones (vertical slice → content → progression → polish → launch). Re-scope the Phase 3 tasks below into S tasks with acceptance criteria.
- **P-004 [todo] [S] Approval gate**: the user approves the plan. Building starts only after this.

## Phase 3 — Building (DRAFT: re-planned in P-003)
- T-002 CourseGen (pure, seeded chunk sequence + difficulty ramp)
- T-003 Chunk library v1 (pure data)
- T-004 Course builder (server) + Layout math (pure)
- T-005 Checkpoints + finish (RaceProgress, pure)
- T-006 Race flow wiring
- T-007 Results + rewards (pure)
- T-008 Lobby (procedural)
- T-009 HUD v2
- T-010 [blocked] Cloud test pipeline: Open Cloud upload + Luau Execution task + Jest-Lua/TestEZ. Needs place ID + API key (custom integration).
- T-011 Player data with ProfileStore (session locking)
- T-012 Cosmetic shop
- T-013 Leaderstats