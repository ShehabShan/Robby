# RESEARCH

- **Format per task** (AGENTS.md §4.2): Findings (each with a source) → **→ Implications** → Unknowns → Sources. ≤25 lines per task.
- Long material goes in `research/notes/`.
- Model-memory claims are labelled "(unverified)".

## R-001 Development practice (done 2026-10-29)
- **Workflow:** filesystem-first.
  - Rojo is the source of truth, code is edited outside Studio, and Rokit pins tool versions.
  - Layout: `src/{client,server,shared}`, Wally packages, `--!strict`, luau-lsp types, Selene plus `stylua --check`.
- **Testing is split in two:**
  - Engine-independent logic → Lune unit tests.
  - Engine-dependent tests run in a real Roblox server via the **Open Cloud Luau Execution API**, usually with TestEZ or Jest-Lua.
- **Luau Execution API:**
  - Upload a place version: `POST /universes/v1/{universeId}/places/{placeId}/versions` (scope `universe-places:write`).
  - Run a task: `POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks` (scope `universe.place.luau-execution-session:write`).
  - Limits: 10 concurrent tasks per place, 5-minute timeout, 4 MB script/return size, 5 tasks per minute per key owner.
- **Security and data:**
  - Server authority: the server is the single source of truth. Prefer silent mitigation (rubber-banding) over bans.
  - One profile per UserId with retries. ProfileStore session locking is the standard.
- **→ Implications:**
  - The scaffold matches current practice.
  - Batch engine tests into one cloud task per session.
  - Use ProfileStore for player data.
  - Combat must be validated on the server.
- **Sources:**
  - create.roblox.com/docs/projects/external-tools
  - create.roblox.com/docs/cloud/reference/features/luau-execution
  - create.roblox.com/docs/cloud/reference/features/places
  - create.roblox.com/docs/projects/server-authority
  - create.roblox.com/docs/scripting/security/security-tactics
  - github.com/Roblox/place-ci-cd-demo
  - github.com/thegamerbay/roblox-luau-execution-action

## R-002 Platform scan (done 2026-10-29; obby-specific parts archived)
- **Trends (2025–26):**
  - Social, low-friction, trend-driven games win, and fast iteration beats graphics alone.
  - Scope small and iterate on retention.
  - Sessions of 19 minutes or more retain and monetise better.
  - RPG, strategy and shooter games that push Roblox's visual standard are being prioritised.
- **Discovery:** Home recommendations rank on what players do after they find a game. Signals, in order:
  1. play-through rate
  2. first-play bounce rate
  3. play days per user
  4. playtime per user

  These are measured over D1, D2–7 and D8–28. Also tracked: qualified play sessions, intentional co-play days, spend days, and Robux per user.
- **Monetisation rules:**
  - Game Passes are permanent purchases; Developer Products are repeatable.
  - Honest descriptions and no fake urgency.
  - PolicyService for age/location restrictions. Paid random items are restricted for users 18 and under by default.
  - Neutral wording for minors.
  - Complete the Maturity & Compliance questionnaire.
- **→ Implications:**
  - The first minutes must hook players, to keep bounce low.
  - Co-play is a ranking signal, so plan party/social play.
  - No loot boxes.
  - Long sessions suit an RPG.
- **Sources:**
  - newzoo.com/articles/roblox-strategic-growth-platform
  - create.roblox.com/docs/discovery
  - about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
  - create.roblox.com/docs/production/monetization

## R-010 … R-018
Not started. See TASKS.md.