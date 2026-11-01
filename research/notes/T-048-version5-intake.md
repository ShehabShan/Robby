# T-048 — owner version5 report vs S108 release (S110, 2026-11-01)

Report: `research/inbox/2026-11-01-s108-version5-test-report-full.md` (owner upload, 62104 B, verbatim). The S109 inbox copy was truncated.

## Consistency checked here (manual, read-only)
- Remote journal `publication-intent/e778b95d…8cda` (commit 013ed992): outcome HISTORY_CONFIRMED, version 5; manifestSha256 `03a56c69…7058` (= T-047b card).
- Report: placeVersion 5, placeId 121111456135560, universe 6958375460, owner 7738981129 = journal target; sourceRevision `ca074efc…` = T-047b source.
- **Full `ingest_wind_step_release.py` binding NOT run:** it needs the retained S108 evidence directory (receipt, manifest, place, review, upload-response, history). That lives only on the S108 bot's VM (bot ebeb0204-3a3c-4fd8-8dea-e315cdbf089f); its artifact `robby_s108_release_evidence` is not readable from this bot (artifact GET 404, GraphQL 0 rows). → T-048b.

## Report results (consistency only, no dynamics acceptance)
- 106/106 passed, matrixPassed, runCompleted, cleanup true, dynamicsAccepted false.
- travel-auto 13.533 actual / 13.851 commanded (14±1 PASS; D-359 fix effective). travel-player/server 13.682 / 14.000.
- Actual-vs-commanded lag ≈0.32 stud on every travel case (was ~0.6 in version4).
- 100 lifetimes: all clean/restored/phaseOK; min actual 13.352, min commanded 13.679.
- **Mid-dash Y drop persists:** travel samples dip to y ≈ −0.589 stud, end ≈ −0.505; reported maxYError = 0, so the harness Y metric does not capture the dip. Needs a d2b2 look.
- Every frame dt = 1/60 exactly: no rate variation covered.
- Still open (report `remaining`): death/original-root replacement; supported rate variation + final-partial analysis; device/owner feel.
