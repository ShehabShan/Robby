# RESEARCH (Phase 1)

Web research via PromptQL's Exa search, 2026-10-29. Implications for Robby are marked →.

## R-001 Development practice (done)
- Filesystem-first: Rojo is the source of truth, code is edited outside Studio, and Rokit pins tool versions. → Matches D-001.
- Layout `src/{client,server,shared}`, Wally packages, `--!strict`, luau-lsp types, and Selene + `stylua --check` in CI. → Matches the scaffold.
- Testing is split in two. Engine-independent logic is unit-tested with Lune. Engine-dependent tests run in a real Roblox server through the **Open Cloud Luau Execution API**, usually with TestEZ or Jest-Lua as the runner. → Keep D-002/D-003. Add a Jest-Lua or TestEZ runner in T-010.
- Luau Execution API:
  - Upload a place version: `POST /universes/v1/{universeId}/places/{placeId}/versions` (scope `universe-places:write`).
  - Run a task: `POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks` (scope `universe.place.luau-execution-session:write`).
  - Limits: 10 concurrent tasks per place, 5-minute timeout, 4 MB script/return size, 5 tasks per minute per key owner.
  - → Batch all engine tests into a single task, at most one cloud run per session.
  - References: `github.com/Roblox/place-ci-cd-demo`, `github.com/thegamerbay/roblox-luau-execution-action`.
- Server authority: the server is the single source of truth and validates everything. Prefer silent mitigation (rubber-banding) over bans. → Checkpoints, finish times and coins are computed server-side only.
- Player data: one profile per UserId, loaded at join, saved periodically and on leave, with retry/backoff. Session locking (ProfileStore) is the standard. → Use ProfileStore in T-011.

Sources: create.roblox.com/docs/projects/external-tools · create.roblox.com/docs/cloud/reference/features/luau-execution · create.roblox.com/docs/cloud/reference/features/places · create.roblox.com/docs/projects/server-authority · create.roblox.com/docs/scripting/security/security-tactics · devforum.roblox.com/t/3172185

## R-002 Market & content scan (first pass, done)
- **Trends 2025–26:** successful games are social, low-friction and trend-driven. Fast iteration beats graphics. Scope small, iterate on retention, and target subgenres with many players but few competitors. Sessions of 19 minutes or more retain and monetise better. Growing areas: town/city roleplay, horror, and trend aesthetics on proven mechanics.
- **Tower of Hell (benchmark):** random stages, no checkpoints, a round timer and racing against others. That makes it replayable, skill-based and status-driven. → **Robby's draft concept (a procedural round-based obby race) is in the same space as ToH. It needs a clear hook (R-003).**
- **Obby design:** easy first ~5 stages, one new mechanic at a time, breather stages, checkpoint density matched to the audience, mobile-first with consistent jump distances and readable UI.
- **Discovery:** Home recommendations rank on what players do after they find a game. Key signals, in order:
  1. play-through rate
  2. first-play bounce rate
  3. play days per user
  4. playtime per user

  These are measured over D1, D2–7 and D8–28. Also tracked: qualified play sessions, intentional co-play days, spend days, and Robux per user.
  - → The first 60 seconds must hook players, to keep bounce low.
  - → Playing with friends (co-play) is a ranking signal, so plan a social feature.
- **Monetisation rules:** Game Passes are permanent purchases; Developer Products are repeatable. Requirements:
  - Honest descriptions and no fake urgency.
  - PolicyService for age/location restrictions. Paid random items are restricted for users 18 and under by default.
  - Neutral wording for minors ("View Item", not "GET IT NOW").
  - Complete the Maturity & Compliance questionnaire.

  → Cosmetics plus maybe a skip-stage product. No loot boxes.

Sources: newzoo.com/articles/roblox-strategic-growth-platform · creation.dev/blog/roblox-obby-design-guide · creation.dev/blog/best-roblox-obby-games · create.roblox.com/docs/discovery · about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox · create.roblox.com/docs/production/monetization

## Open questions (R-003 … R-005)
- What hook makes Robby clearly different from Tower of Hell and other obbies?
- Which obstacles and mechanics fit each difficulty tier, and are they mobile-safe?
- What long-term goals bring players back on D7 and keep sessions at 19+ minutes?