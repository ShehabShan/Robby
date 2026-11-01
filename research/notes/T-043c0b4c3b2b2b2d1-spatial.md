# Wind Step Saved-engine spatial probe — S89 (2026-11-01)

## Scope
- `WindStepClearance` contains the production starting-overlap queries extracted from `WindStepDriver`. Driver and cloud probe call this same adapter; existing28 driver groups still execute both actual source modules.
- `tests/cloud/wind_step_spatial.luau` creates bounded fixtures at (16384,2048,16384), snapshots/restores the entire96×80×96stud edited terrain region, independently destroys parts/groups and verifies voxel restoration. Cases include grid offsets, slopes/tilt, air, water, initial terrain penetration, overhangs, collidable/noncollidable parts, group filtering and100 repeated spatial calls.
- `python3 scripts/wind_step_probe.py` requires clean main, runs check/build, uploads **Saved only**, executes the probe and stores structured API evidence under build/. `--version N` explicitly reuses that Saved version. Never publishes. `cloud_test.py` import now has a main guard; its existing CLI is unchanged.
- Completion/HTTP200 is not PASS: runner requires a structured report with zero failures. Failed runs still persist the version, task path, output and diagnostics.
- No fake Player or physics simulation. This probe cannot accept force dynamics, displacement/wall stopping, real ownership restoration or device feel. d2 remains a separate activation gate.

## Real-engine findings and corrections
- Saved28: ReadVoxels arrays carry `Size: Vector3`; generalized iteration raised before terrain admission. Numeric iteration now skips metadata, with a matching failing-before/fixed-after mock regression (D-316).
- Saved29: terrain collision meshing is delayed after FillBlock. Fixture-only bounded waits make the setup queryable. Without the waits, an absent ray surface was correctly reported as fixture failure, not pass.
- Saved29 meshed: 0.2stud terrain penetration was admitted by an all-zero body-only voxel box while downward full-volume casts hit. Production target AND seed emptiness now require a full4stud halo around the OBB enclosing AABB; descent still covers the original body. Mock regression proves removing the halo fails (D-317). Conservative cave/overhang refusal remains intentional.

## Saved30 evidence (2026-11-01)
- Uploaded Saved30 from main9ef311d (build/probe SHA and exact task path in `T-043c0b4c3b2b2b2d1-v30.json`). **44/44 report rows pass, zero failures**; counts include diagnostics and cleanup, not44 gameplay tests. Twelve shallow-penetration cases across four grid offsets refuse, flat/slope/air/water admit, group exclusions work, low blocked overhang refuses.
- Terrain restored/readback verified; test parts and both temporary collision groups removed.100 repeated spatial queries are NOT100 driver lifetimes.
- Full existing cloud suite separately **CLOUD ALL: PASS,626/626 specs (83 suites), packages and smoke** on Saved30; full output in `T-043c0b4c3b2b2b2d1-cloud-v30.txt`.
- RunService:IsRunning=false, IsServer=true, Players=0. No physics/ownership acceptance possible from this evidence. No publication (published remains27/game0.0.22), no live Wind Step activation.
- Local CHECK PASS:28 actual-source driver groups, existing626 pure tests, and7 Python runner test methods covering every missing/failed report row, malformed/partial/error outputs and independent cleanup. Runner requires the exact complete matrix; diagnostic rows cannot substitute for missing assertions.

## Next — d2 is still required
- Establish an actual running-server test environment with a real Player and character. Luau Execution cannot prove the scheduler, solver or ownership restoration because it is not running and has no players. Do not fabricate those from tables or anchored fixtures.
- Verify14stud/.24s force-driven travel, final partial interval, real wall/skin/overshoot and falling Y; cancel/death/replacement, network mode restore,100 clean lifetimes, supported frame-rate variation. Repair real failures before b2c activation; device feel remains separate.
- If no running-server route is available headlessly, prepare a disabled Studio-only harness and give minimal owner instructions rather than promoting based on geometry alone. Never publish merely to obtain test coverage.


- Independent repeat on Saved30 from maine617d5d with strict complete-matrix validator:44/44 PASS,32 admission/refusal assertions; full evidence `T-043c0b4c3b2b2b2d1-v30-repeat.json`. No runtime source changes after Saved30 upload.
