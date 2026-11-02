# CLAIMS — who is working on what (parallel sessions, D-087)

Rows are added by `bash scripts/claim.sh <TASK-ID>` (pushed to main) and removed by `bash scripts/merge.sh`.
Never start a task that has a row here. A claim whose branch had no push for 2 h is stale: `bash scripts/release.sh` frees it; the branch waits for adoption (AGENTS.md §9, D-134).

| Session | Task | Branch | Decisions | Claimed (UTC) | Bot | Note |
|---|---|---|---|---|---|---|
| S114 | T-049 | session/S114 | D-369..D-378 | 2026-11-02 14:18 | 6cedf88c-04a3-4783-bbc8-d029933c38ae | Wind Step version6 isolated test publication result |
