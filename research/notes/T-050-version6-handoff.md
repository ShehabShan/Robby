# T-050 handoff — version6 travel-auto failure (2026-11-02)

Start here in the fresh diagnosis session. Owner report, verbatim: `research/inbox/2026-11-02-version6-test-report.md`.

## What happened
- Version6 (source main `ea5e7e8`, published per `research/notes/T-049-release-result.md`) failed **0/106**. It stopped at the first case, `travel-auto`.
- Actual distance was 12.963 against a commanded 13.573. That is below the 13 minimum (14±1).
- Version5 (`ca074efc`) passed 106/106, with travel-auto at 13.533 actual against 13.851 commanded (`research/notes/T-048-version5-intake.md`).
- The main runtime change between version5 and version6 is d2b2c (D-368): grounded dashes zero downward root velocity while ground is within leg reach. d2b2b2b (D-367) changed only the Studio test probe, which the published build strips.

## What the samples show (travel-auto, 15 samples at about 60 Hz)
- In samples 1–6 (t ≤ 0.100, x ≤ 6.39), y stays within ±0.001 and vy stays near 0. The ground hold appears to work here.
- At sample 7 (t 0.117, x 7.56), vy jumps from 0.02 to **-7.70** in one frame while commandSpeed is still 70. After that, y falls steadily to **-0.510** (maxYDip) at t 0.234.
- The dip begins at full speed, before braking (braking starts at about t 0.167). So the d2b2c hold either stopped applying at about 7.5 studs or never limited this kind of drop.
  - Hypotheses to test, none verified: the leg-reach/ground probe loses the floor (ray origin, length or filter versus the test pad edge or seams); the hold applies only on some frames; Humanoid state changes to Freefall/Running.
- The commanded distance is also lower than in version5 (13.573 vs 13.851). Check whether d2b2c or the clock change shortens the commanded path, separately from the physics deficit.
- `velocityKept` is false and `maxYError` is 0. maxYError is velocity-only, so it does not catch this dip; use maxYDip.

## Suggested first steps (offline, no publication)
1. `git diff ca074efc ea5e7e8 -- src tests/published` to isolate d2b2c, and read `src/server/WindStepDriver.luau` and `src/server/WindStepClearance.luau`.
2. Replay these 15 samples in a mock regression: the hold must keep |y| ≤ 0.2 for the whole grounded dash, and distance must be ≥ 13.
3. Check the test place geometry under x ≈ 7–13 for travel-auto (a pad edge or seam could explain a sudden loss of ground).
4. Repair without widening tolerances, run CHECK, then do a new stage → exact-byte card → owner Yes. Never reuse consent 784fcc05 (consumed).

## Rules carried over
- Export `PATH="$HOME/.rokit/bin:$PATH"` before the transaction or staging.
- Precheck without `--execute-reviewed-owner-publication`. `main()` hides the error text, so call `transact()` directly to see it.
- The review attestation from the S106 declaration expires 2026-11-02T17:15:39Z. A later publish needs a fresh owner permission declaration.
- Parallel art sessions (assets/ only) do not block a release (owner, 2026-11-02).

## d2b2c commits / files (auto)
- 6f78705 T-043c0b4c3b2b2b2d2b2c: grounded Wind Step holds Y while ground within leg reach (D-368)
     src/server/WindStepDriver.luau | 19 +++++++++++++++++++
     1 file changed, 19 insertions(+)
