# ARCHITECTURE

## Data model (default.project.json)
| Repo path | Roblox location | Kind |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | ModuleScripts (pure logic + config) |
| `src/server/` | `ServerScriptService.Server` | `init.server.luau` = Script; siblings = ModuleScripts |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | `init.client.luau` = LocalScript |
| `tests/` | not synced | Lune unit tests (`*.spec.luau`), runner `tests/run.luau` |

## Modules
- `shared/Config` — tunables. `Config.Round = { minPlayers, intermission, race, results }`.
- `shared/RoundState` — pure state machine. `new(): State`; `step(state, dt, playerCount, allFinished, timings): (State, Phase?)`. Phases: Waiting → Intermission → Racing → Results → (Intermission | Waiting). `round` increments on entering Racing.
- `server/init.server` — Heartbeat loop driving RoundState; tracks `finished[player]`; publishes `Phase`/`TimeLeft`/`Round` attributes on ReplicatedStorage.
- `client/init.client` — `RoundHud` ScreenGui reading those attributes.

## Status (read first)
- The code under `src/` and `tests/` is an **obby-era toolchain sample** (D-019). It is not the game architecture.
- P-004 rewrites this document for the RPG, and T-002 replaces the sample.
- The toolchain, quality gate and testing approach below stay.

## Scripts
- `scripts/bootstrap.sh`: idempotent setup (Rokit tools, type defs, Wally, git proxy in the PromptQL VM).
- `scripts/check.sh`: the quality gate. It prints PASS/FAIL per stage and then `CHECK: PASS|FAIL`.
- `scripts/olu.sh`: the OLU meter. A fresh bot counts from 0; `start` sets a baseline for a reused bot.
- `scripts/search.sh "q" [chars]`: web search through PromptQL's Exa integration, with a capped answer and sources.
- `scripts/save.sh "ID: msg"`: commit, rebase and push, then show the OLU meter.

## Conventions
- Pure modules take dependencies as arguments; no `game:GetService` in `src/shared`.
- Server modules require shared via `require(ReplicatedStorage.Shared.X)` (resolved by the Rojo sourcemap for type checking).
- Tests require source by relative path: `require("../src/shared/X")`.