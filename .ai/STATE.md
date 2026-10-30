# STATE

## Now (after S11)
- S11 done: T-010 cloud pipeline (CLOUD ALL: PASS on Saved v5, D-060), T-014 HitFeel (D-061), T-015 Stone Ward + Wind Step (D-062). Done through T-015.
- Next task: **T-016** core slots, loadout, role tags and Qi/Strain/Satiety HUD (ROADMAP). Keys E/Q/R are provisional until T-016 slots.
- Cloud re-run of the S11 build is pending: uploading a new Saved version timed out twice in S11 (`scripts/cloud_test.py`, urlopen timeout 120). Retry first next session; `python3 scripts/cloud_test.py 5` reuses v5.
- Owner: Studio playtest of Crescent, combat, Stone Ward (Q/Y) and Wind Step (R/L2) (needs `wally install`). Remotes are Blink (`net/remotes.blink` → `src/*/Net.luau`).

- **Phase:** 3 — Building (P-006 approved, D-049). Foundations done: R-021…R-026 + P-008 systems spec (S9, D-052).
- **Doing:** T-016b server loadout. Resume from: starter Kith + default loadout in ProfileSchema/DataService, then gate casts in Abilities with `Loadout.allowedMoves`.
- **NEXT:** T-016b, then T-016c → T-016d (TASKS.md). T-016a done (D-063).
- **Then:** T-017 … T-024 (ROADMAP.md order).
- **Budget:** 50 OLU hard cap per session. Wrap up at 43; close-out by 45 (AGENTS.md §1).
- **Blockers:** T-006 needs the owner OK to publish. Open Cloud key works (read, Saved upload, Luau execution; S6).
- **Last check.sh:** CHECK: PASS (2026-10-30, S11; 69 Lune tests)
- **Notes:**
  - Direction changed in S3: the obby is dropped, and the game is an RI-inspired action RPG (D-013).
  - The `src/` code is an obby-era toolchain sample (D-019).
