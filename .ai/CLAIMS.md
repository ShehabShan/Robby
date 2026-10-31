# CLAIMS — who is working on what (parallel sessions, D-087)

Rows are added by `bash scripts/claim.sh <TASK-ID>` (pushed to main) and removed by `bash scripts/merge.sh`.
Never start a task that has a row here. A claim whose branch had no push for 2 h is stale: `bash scripts/release.sh` frees it; the branch waits for adoption (AGENTS.md §9, D-134).

| Session | Task | Branch | Decisions | Claimed (UTC) | Bot | Note |
|---|---|---|---|---|---|---|
| S56 | T-034 | session/S56 | D-211..D-220 | 2026-10-31 13:00 | 45dfa146-834c-435d-b87e-867793eea38f | owner: find + fix Rimeshard ability in UI |
