# T-047 — version4 `travel-auto` commanded-distance deficit (S107, 2026-11-01)

**Input:** owner version4 report, verbatim in `research/inbox/2026-11-01-s106-version4-test-report.md`.
Measured distance 12.090, commanded 12.699, gate 14±1 for both, so it fails.

**Diagnosis (offline, actual source):**
- The sampling repair from S105 worked: phaseOK true, 14 Pre/Post pairs, commanded speeds recorded.
- Back-solving the speeds against the accumulated applied dt shows the profile clock ran about 0.0185 s (about one frame) ahead of the steps actually driven.
- Cause: `WindStepDriver.commit` set `started = acceptedAt`. The gap between acceptance and the first PreSimulation was counted as dash time, even though nothing was simulated in it. That time's travel (70 stud/s × ~0.0185 s ≈ 1.3 studs) was dropped.
- Regression "commit-to-first-step latency does not consume dash travel" in `tests/wind_step_driver.luau` reproduced exactly 12.705 commanded before the fix.

**Fix:** the profile clock starts at the first driven PreSimulation step (`stepped` flag in `before()`).
- The no-catch-up and stall rules are unchanged.
- Commit freshness gates, tolerances and the 13-stud minimum are unchanged.
- Driver suite: 33 groups PASS. Full CHECK PASS.

**Unknowns (need a real engine, d2b2):**
- First-frame physics lag. Actual 12.09 against commanded 12.70 is a gap of about 0.6 stud. The expected result is about 13.4 against the 13 minimum, but this has not been verified.
- Mid-dash drop. y fell about 0.59 (vy −7.7 to −14.2 near x 7.5–10, then landed) while `maxYError` reported 0. This is possibly platform geometry or step-down.
- Ownership, rates, death/replacement and device feel are still gated.

**Next:** T-047a, a corrected final-main package through the EXISTING staging tooling (see `T-046a-corrected-package.md`). Then a NEW exact-byte owner approval, the one-shot test publication, and a fresh owner report. No publication was made this session.