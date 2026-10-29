# DECISIONS (append-only)

- **D-001 Rojo, fully file-managed.** The repo is the source of truth; nothing exists only in Studio.
- **D-002 Strict Luau + pure modules.** Game logic lives in `src/shared` modules without Roblox service calls, so Lune can unit-test it. Server/client scripts are thin wiring.
- **D-003 Testing.** Lune unit tests locally (`scripts/check.sh`). Engine-level tests later via the Open Cloud Luau Execution API (T-010). Visual/feel testing is done by the user in Studio via `rojo serve`.
- **D-004 Procedural courses.** Courses are assembled per round from code-defined chunk specs (seeded). No hand-built maps or meshes, which fits headless development and gives replayability.
- **D-005 Round state replication via ReplicatedStorage attributes** (`Phase`, `TimeLeft`, `Round`). No RemoteEvents until a feature needs client→server input.
- **D-006 Access.** GitHub through the PromptQL integration proxy (no tokens in the VM). Roblox API keys only through a PromptQL custom integration; never committed or pasted in chat.
- **D-007 Style.** Tabs, StyLua (column 120), Selene `roblox` std.
- **D-008 Budget discipline.** One S task per session, commit per working step, short script output.
- **D-009 Game:** round-based obby race named Robby (see GDD.md). Chosen by the AI with user delegation. *Draft until P-001/P-002.*
- **D-010 Gated phases** (user request, 2026-10-29): Research → Planning → user approval → Building. T-001 scaffold is kept as Phase 0 because it is genre-agnostic.
- **D-011 OLU budget** (user rule, 2026-10-29): 50 OLU hard cap per session. Wrap up at 43, close-out started by 45, so 5–7 OLU stay in reserve for state updates, commit and push. Measured with `scripts/olu.sh` (bot OLU total minus the baseline recorded at boot).
- **D-012 Research tooling:** web research goes through PromptQL's built-in Exa search, with short capped answers. Findings and sources are recorded in RESEARCH.md so they are never re-searched.