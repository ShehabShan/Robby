# T-045 — isolated test startup repair (S103, 2026-11-01)

## Owner observation and diagnosis
- Exact report: `research/inbox/2026-11-01-test-single-block.md`. Uploaded screenshot shows one grey spawn platform and no diagnostic panel. It does not identify the serving place version or expose server errors.
- The isolated project intentionally contains only a12x12 SpawnLocation at(-50,0,0); fixtures appear only after explicit owner Start. Falling off that platform is consistent with its geometry, not proof that Wind Step movement ran. No game/world or new assets are required for this repair.
- Both ordinary Script bootstraps called `RunService:GetRobloxVersion()` before creating the owner channel. Roblox API metadata marks this method `RobloxScriptSecurity`. The ordinary published Script cannot call it; previous offline mocks incorrectly allowed it. This is a reproduced source-level startup failure consistent with missing UI, not a recovered live-server error or exact serving-byte assertion.
- Independently, membership may arrive before PlayerGui. The transport correctly requires a GUI but the bootstrap attempted it immediately; failure was terminal. Delayed-GUI regression reproduced that failure.

## Changes
- Published header and Studio source use documented public `version()` for engine provenance. It is deprecated but available to ordinary Scripts; no privileged fallback, blank provenance, permission relaxation or new module. The one-line Selene allowance is limited to its missing global definition; luau-lsp recognizes it.
- Published header waits for original owner's PlayerGui within the EXISTING120s admission deadline. Rechecks exact original owner/membership, target, server/running/Studio, opt-in and HasRun; invalidation stops immediately. Final guard before transport; no rebind/rejoin or automatic worker start. Transport's own guards remain intact.
- Production gameplay/driver unchanged; default candidate server/client stay disabled, RunWindStep=false. Existing staging explicitly enables a NEW package. Old release artifacts and consumed UNCERTAIN journal are not modified or replayed.

## Evidence and limits
- Before/after actual-generated-worker test: privileged API throws before owner transport before fix; afterward explicit Start +106-case synthetic traversal and report engine provenance pass. Enabled Studio bootstrap also reaches admission at ordinary Script identity.
- New generated-worker group: delayed GUI reaches idle exactly once; never-arriving GUI bounds timeout; owner leave, extra player, same-ID replacement, changed destination and opt-out refuse without HasRun, jobs or driver acquisition. Existing100-lifetime cleanup coverage retained. Six generated-worker groups and ten Studio groups; full `bash scripts/check.sh` CHECK:PASS.
- Four restored temporary faults detected: privileged API in published/Studio, skipped GUI wait, ignored admission invalidation. The last initially escaped immediate-exit coverage; assertion strengthened and fault re-run/detected. See `T-045-startup-faults.json`.
- All runtime checks are OFFLINE/mocked, not actual Roblox physics, UI rendering, Sober/mobile, current-serving or end-to-end acceptance. No Roblox requests, uploads or publication in S103; prior S101/S102 historical publication evidence remains separate.

## Next — T-045a
- On clean synced main, use existing staging tooling for the corrected separate-test build and deliver a newly pinned approval package. Read `.ai/OPEN_CLOUD.md` and existing T-044c2a handoff/tool contracts; do not add another permission framework or ask for a screenshot/key.
- Changed code means NEW bytes: prior consumed consent cannot authorize them. Fresh named-package approval and existing transaction gates are required before one test-only publication; never replay/reset prior intent. Production excluded. Do not label a rebuild as the original S101 archive.
- T-044c2b2 original-evidence recovery remains separately blocked; repair source work neither solves nor bypasses its intake requirement. Actual owner Start/report, remaining dynamics and feel gates stay open.

## Sources inspected 2026-11-01
- https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json — RunService.GetRobloxVersion: Security=RobloxScriptSecurity, returns string.
- https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/globals/RobloxGlobals.yaml — public version(): current Roblox version string, deprecated tag.
- Source and executed regression fixtures in this commit are the reproduction record; no claim that API metadata substitutes for a live client test.
