# STATE

- **Phase:** 2b — capability spike (D-025): T-003 → T-006, then P-002 … P-006
- **Doing:** P-004 (S6). Resume from: rewrite ARCHITECTURE.md.
- **NEXT:** P-004 — technical architecture (ARCHITECTURE.md rewrite). T-005b/T-006 blocked on the owner.
- **Then:** P-004 → P-005 → P-006 (owner approval); T-005b → T-006 when unblocked
- **Budget:** 50 OLU hard cap per session. Wrap up at 43; close-out by 45 (AGENTS.md §1).
- **Blockers:** T-005b/T-006: `roblox-open-cloud` key 401 — owner must set the integration to send header `x-api-key` (see research/notes/T-005-verification.md). T-006 also needs the owner OK to publish.
- **Last check.sh:** CHECK: PASS incl. place inspect (2026-10-30, S6)
- **Notes:**
  - Direction changed in S3: the obby is dropped, and the game is an RI-inspired action RPG (D-013).
  - The `src/` code is an obby-era toolchain sample (D-019).