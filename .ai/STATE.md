# STATE

## Now (after S10)
- S10 end: owner says `roblox-open-cloud` is now set up (Universe 10773761715, Place 95587500384127); first step next session: check these match `scripts/cloud_test.py`, then run it (T-010).
- Done through T-013 (except T-010). Next task: **T-014 HitFeel** — extract hit-stop/shake/flash/numbers from `src/client/CrescentFx.luau` into a shared client `HitFeel` used by Crescent and CombatService hits (ART §5 items 2, 5).
- Blocked: T-010 + cloud part of T-012 — `roblox-open-cloud` not enabled in this project; resume with `python3 scripts/cloud_test.py`.
- Owner: Studio playtest of spike + combat (needs `wally install`). Remotes are Blink (`net/remotes.blink` → `src/*/Net.luau`).


- **Phase:** 3 — Building (P-006 approved, D-049). Foundations done: R-021…R-026 + P-008 systems spec (S9, D-052).
- **Doing:** none. T-002a, b, c1–c3 done S9.
- **NEXT:** T-002c4 FX registry (resume from `src/client/CrescentFx.luau`), then T-002d, then T-010. Use a strong coding model.
- **Then:** T-002 → T-010 (cloud pipeline; key works, base on scripts/cloud_test.py) → M1 tasks (ROADMAP.md)
- **Budget:** 50 OLU hard cap per session. Wrap up at 43; close-out by 45 (AGENTS.md §1).
- **Blockers:** T-006 needs the owner OK to publish. Open Cloud key works (read, Saved upload, Luau execution; S6).
- **Last check.sh:** CHECK: PASS (2026-10-30, S9)
- **Notes:**
  - Direction changed in S3: the obby is dropped, and the game is an RI-inspired action RPG (D-013).
  - The `src/` code is an obby-era toolchain sample (D-019).
