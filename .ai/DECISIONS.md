# DECISIONS (append-only)

- **D-001 Rojo, fully file-managed.** The repo is the source of truth; nothing exists only in Studio.
- **D-002 Strict Luau + pure modules.** Game logic lives in `src/shared` modules without Roblox service calls, so Lune can unit-test it. Server/client scripts are thin wiring.
- **D-003 Testing.** Lune unit tests locally (`scripts/check.sh`). Engine-level tests later via the Open Cloud Luau Execution API (T-010). Visual/feel testing is done by the user in Studio via `rojo serve`.
- **D-004 Procedural courses.** Courses are assembled per round from code-defined chunk specs (seeded). No hand-built maps or meshes, which fits headless development and gives replayability.
- **D-005 Round state replication via ReplicatedStorage attributes** (`Phase`, `TimeLeft`, `Round`). No RemoteEvents until a feature needs client→server input.
- **D-006 Access.** GitHub through the PromptQL integration proxy (no tokens in the VM). Roblox API keys only through a PromptQL custom integration; never committed or pasted in chat.
- **D-007 Style.** Tabs, StyLua (column 120), Selene `roblox` std.
- **D-008 Budget discipline.** One S task per session, commit per working step, short script output.
- **D-009 Game:** round-based obby race named Robby (see GDD.md). Chosen by the AI with user delegation.