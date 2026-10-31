# CLAIMS — who is working on what (parallel sessions, D-087)

Rows are added by `bash scripts/claim.sh <TASK-ID>` (pushed to main) and removed by `bash scripts/merge.sh`.
Never start a task that has a row here. A claim whose branch had no push for 2 h is stale: `bash scripts/release.sh` frees it; the branch waits for adoption (AGENTS.md §9, D-134).

| Session | Task | Branch | Decisions | Claimed (UTC) | Bot | Note |
|---|---|---|---|---|---|---|
| S69 | T-043c0b1 | session/S69 | D-243..D-252 | 2026-10-31 17:34 | 5d1af429-6e1d-4192-92c2-606fa38d65e6 | Shared CastRequest sender; serial protocol lane |
| S69 | T-043c0b2 | session/S69 | D-243..D-252 | 2026-10-31 17:35 | 5d1af429-6e1d-4192-92c2-606fa38d65e6 | Atomic stance/payment only; no remotes or timeline changes |
| S69 | T-043c0b3a | session/S69 | D-243..D-252 | 2026-10-31 17:38 | 5d1af429-6e1d-4192-92c2-606fa38d65e6 | Canonical replay adapter core before live protocol |
| S69 | T-043c0b3b1 | session/S69 | D-243..D-252 | 2026-10-31 17:40 | 5d1af429-6e1d-4192-92c2-606fa38d65e6 | Prediction readiness and atomic local chain; no schema changes |
