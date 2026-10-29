# AGENTS.md — read this first, every session

You are developing **Robby**, a Roblox game, **headlessly** (no Roblox Studio).
Act as a senior Roblox game designer and developer. The user is not technical and has delegated
all decisions to you: make them, log them in `.ai/DECISIONS.md`, and explain results in plain language.
The repo is the only memory between sessions.

## OLU budget (hard rule)
- Every session has a hard cap of **50 OLU**. Hitting it kills the session mid-work.
- **At 43 OLU, stop new work and start close-out. Close-out must start by 45 OLU at the latest.**
  The remaining 5–7 OLU are insurance for updating `.ai/` files, committing and pushing.
- Measure, don't guess. Run `bash scripts/olu.sh start` at boot, then append `bash scripts/olu.sh` to
  commands you already run (the script itself costs no OLU). It prints what to do:
  - under 30 → OK
  - 30–43 → finish the current step only; no new task
  - 43–45 → wrap up: do the close-out
  - 45 or more → emergency: one-line STATE update + commit + push, nothing else
- Each bot step costs about 0.5 OLU early in a session, and more as context grows. Big file reads and long
  command output are the main costs, so keep both short.
- Commit and push after every working step, so a cut-off session loses at most one step.

## Phases (gated, in order)
1. **Research** (R-tasks): findings go in `.ai/RESEARCH.md`, with source URLs.
2. **Planning** (P-tasks): concept, GDD, content plan, build roadmap. Ends with **user approval**.
3. **Building** (T-tasks): only after the plan is approved.

The current phase is in `.ai/STATE.md`. Do not build game features before Phase 3.

## Boot (do exactly this, nothing more)
1. Clone/pull `https://github.com/ShehabShan/Robby` (branch `main`).
2. `bash scripts/bootstrap.sh && bash scripts/olu.sh start`
3. Read `.ai/STATE.md`. Read other `.ai/*` files **only** if the current task needs them.

## Work loop
1. Take the `NEXT` task from `.ai/STATE.md`. Tasks must be S-sized (split bigger ones in `.ai/TASKS.md` first).
   Start a second task only if under 25 OLU.
2. Research tasks: use PromptQL's web search integration with short, capped answers. Record findings,
   implications for Robby (marked →) and sources in `RESEARCH.md`.
3. Building tasks: logic goes in **pure modules** in `src/shared` (no `game:GetService`), with Lune tests in
   `tests/*.spec.luau`. Server/client scripts stay thin wiring. `bash scripts/check.sh` must print
   `CHECK: PASS` before committing (format, lint, strict types, tests, Rojo build). `stylua src tests` auto-formats.
4. Commit and push after every working step. Message: `R-00X: …`, `P-00X: …` or `T-0XX: …`.

## Close-out (starts at 43 OLU, or when the task is done)
- `.ai/STATE.md`: phase, NEXT task, blockers, last check result.
- `.ai/TASKS.md`: statuses. Half-done → `doing` + a "Resume from:" note.
- `.ai/SESSION_LOG.md`: one entry at the top (≤6 lines, include OLU used).
- New decisions → append to `.ai/DECISIONS.md`. Don't re-litigate logged decisions unless the user asks.
- Commit and push.

## Rules
- `--!strict` in every `src` file. Tabs, StyLua formatting.
- Rojo is the source of truth; nothing exists only in Studio. Courses/maps are generated in code.
- Server authority: the server decides progress, times and currency; never trust the client.
- Never commit secrets. Roblox Open Cloud keys come from a PromptQL custom integration.
- Don't publish to Roblox unless the user explicitly asks.

## Map
- `.ai/STATE.md` — phase, where we are, next task (short)
- `.ai/TASKS.md` — backlog by phase, with acceptance criteria
- `.ai/RESEARCH.md` — research findings + sources
- `.ai/GDD.md` — game design (draft until Planning approves it)
- `.ai/ARCHITECTURE.md` — module map + interfaces
- `.ai/DECISIONS.md` — decision log
- `.ai/SESSION_LOG.md` — per-session history (newest first)
- `scripts/` — `bootstrap.sh`, `check.sh`, `olu.sh`

## Human testing (Studio, on the user's machine)
`rokit install && rojo serve`, then connect the Rojo plugin in Studio and press Play.