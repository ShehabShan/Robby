# AGENTS.md — read this first, every session

You are developing **Robby**, a round-based Roblox obby race, **headlessly** (no Roblox Studio).
The repo is the only memory between sessions. Each session has a hard budget (~50 OLU), so
work small, commit often, and never re-explore what is already written down.

## Boot (do exactly this, nothing more)
1. Clone/pull `https://github.com/ShehabShan/Robby` (branch `main`).
2. `bash scripts/bootstrap.sh` (idempotent; installs pinned tools + type defs).
3. Read `.ai/STATE.md`. Read other `.ai/*` files **only** if the current task needs them.

## Work loop
1. Take the `NEXT` task from `.ai/STATE.md`. Only **S**-sized tasks per session; split anything bigger in `.ai/TASKS.md` first.
2. Implement. Logic goes in **pure modules** in `src/shared` (no `game:GetService`), with Lune tests in `tests/*.spec.luau`. Server/client scripts stay thin wiring.
3. `bash scripts/check.sh` must print `CHECK: PASS` before committing. It runs: format (StyLua), lint (Selene), types (luau-lsp, strict), tests (Lune), build (Rojo). Use `stylua src tests` to auto-format.
4. Commit + push after every working step (small commits). Message: `T-0XX: <what>`.

## Close-out (before the budget runs out)
- `.ai/STATE.md`: update milestone, NEXT task, blockers, last check result.
- `.ai/TASKS.md`: update statuses. Half-done → `doing` + a "Resume from:" note.
- `.ai/SESSION_LOG.md`: add one entry at the top (≤6 lines).
- New decisions → append to `.ai/DECISIONS.md`. Do not re-litigate logged decisions unless the user asks.
- Commit + push.

## Rules
- `--!strict` in every `src` file. Tabs, StyLua formatting.
- Rojo is the source of truth; nothing exists only in Studio. Maps/courses are generated in code (see `.ai/GDD.md`).
- Never commit secrets. Roblox Open Cloud keys come from a PromptQL custom integration.
- Keep tool output short: summarize, don't dump logs.
- Don't publish to Roblox unless the user explicitly asks (`scripts/publish.sh`, later).

## Map
- `.ai/STATE.md` — where we are + next task (short)
- `.ai/TASKS.md` — backlog with acceptance criteria
- `.ai/GDD.md` — game design (what we build)
- `.ai/ARCHITECTURE.md` — module map + interfaces
- `.ai/DECISIONS.md` — decision log
- `.ai/SESSION_LOG.md` — per-session history (newest first)

## Human testing (Studio, on the user's machine)
`rokit install && rojo serve`, then connect the Rojo plugin in Studio and press Play.
Or open `build/Robby.rbxl` from `rojo build default.project.json -o build/Robby.rbxl`.