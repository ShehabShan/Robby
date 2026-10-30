# CLAIMS — who is working on what (parallel sessions, D-087)

Rows are added by `bash scripts/claim.sh <TASK-ID>` (pushed to main) and removed by `bash scripts/merge.sh`.
Never start a task that has a row here. A claim whose branch had no push for 2 h is stale: `bash scripts/release.sh` frees it; the branch waits for adoption (AGENTS.md §9, D-134).

| Session | Task | Branch | Decisions | Claimed (UTC) | Bot | Note |
|---|---|---|---|---|---|---|
| S44 | T-029 | session/S44 | D-192..D-201 | 2026-10-30 22:49 | 8dedb78f-d782-43aa-9783-857a2cc02932 | version + publish |
