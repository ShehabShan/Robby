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
- **Mid-dash Y drop persists:** travel samples dip to y ≈ −0.589 stud, end ≈ −0.505; reported maxYError = 0 because it measures vertical-velocity vs gravity consistency (tests/studio/wind_step.server.luau:197), not position. No harness metric bounds the position dip; d2b2 should add one before acceptance.
- Every frame dt = 1/60 exactly: no rate variation covered.
- Still open (report `remaining`): death/original-root replacement; supported rate variation + final-partial analysis; device/owner feel.

## T-048b — binding without the S108 bot (S111, 2026-11-02)
The owner can no longer use the S108 bot, so its retained evidence directory is unavailable. Alternative used instead (read-only, no upload):
- **Exact-byte reconstruction:** clean detached checkout of `ca074efc…` (journal `mainCommit`) + existing `stage_wind_step_published.py --stage --target research/releases/S100-wind-step-target.json --enable-local-test` reproduced manifestSha256 `03a56c69…7058` and placeSha256 `d48f4712…28a8`, identical to the remote journal intent pins. Staging is deterministic, so the published bytes are known exactly.
- **Live history:** `observe_wind_step_publication.py --expected-version 5` (GET-only): historicalPublicationObserved true, historyComplete true.
- Report placeVersion 5 / target / sourceRevision match (T-048a).
- **Not reconstructable:** receipt, upload response (`e3ab5b97…`), history snapshot (`647ea9b6…`) and review bytes — so `ingest_wind_step_release.py` itself cannot run. Binding is accepted as consistent by this substitute (D-363); still consistency only: not report authenticity, current-serving or dynamics acceptance.
- Future releases: also store the evidence ZIP in the repo-reachable place (see D-363) so another bot can run the intake.
