# Wind Step Saved-engine spatial probe — S89 (2026-11-01)

## Scope
- `WindStepClearance` contains the unchanged production starting-overlap queries extracted from `WindStepDriver`. Driver and cloud probe call this same adapter; existing28 driver groups still execute both actual source modules.
- `tests/cloud/wind_step_spatial.luau` creates bounded fixtures at (16384,2048,16384), snapshots/restores the entire96×80×96stud edited terrain region, independently destroys parts/groups and verifies voxel restoration. Cases include grid offsets, slopes/tilt, air, water, initial terrain penetration, overhangs, collidable/noncollidable parts, group filtering and100 repeated spatial calls.
- `python3 scripts/wind_step_probe.py` requires clean main, runs check/build, uploads **Saved only**, executes the probe and stores structured API evidence under build/. `--version N` explicitly reuses that Saved version. Never publishes. `cloud_test.py` import now has a main guard; its existing CLI is unchanged.
- Completion/HTTP200 is not PASS: runner requires a structured report with zero failures. Failed runs still persist the version, task path, output and diagnostics.
- No fake Player or physics simulation. This probe cannot accept force dynamics, displacement/wall stopping, real ownership restoration or device feel. d2 remains a separate activation gate.

## Evidence pending
- Local CHECK PASS after extraction/probe. Saved-version evidence follows after merge; no engine result claimed yet.
