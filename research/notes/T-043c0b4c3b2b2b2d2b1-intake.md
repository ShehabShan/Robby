# Wind Step evidence intake and owner handoff — S91 (2026-11-01)

## Scope
- d2b1 is offline preparation, complete. d2b2 remains BLOCKED on actual single-player Studio evidence, then repairs and death/replacement plus supported-rate/final-partial analysis. No physics execution, activation, publication or gameplay changes in S91.
- S90's isolated disabled test remains unchanged, including its canonical Evidence policy and106-case first-slice scope. No fabricated success report is retained as engine evidence. Synthetic tests are explicitly labeled.

## Reproducible handoff
- `python3 scripts/build_wind_step_test.py` now also creates `build/WindStepTest.manifest.json` and `build/WindStepTest.zip` (disabled place, manifest, README only). ZIP metadata is fixed. The build still embeds exact source revision and five SHA256 source hashes; manifest adds place SHA256. Existing packaging tests verify exact production/harness sources, disabled guards and normal-build exclusion.
- Owner instructions live in `tests/studio/WIND_STEP_README.txt` and inside the zip. Studio must run Play/F5, R15, one player, explicit RunWindStep=true and Enabled; never publish. Return full WindStepEvidence JSON and bundled manifest before stopping Play. Unsupported desktop/Studio access remains an owner blocker; do not substitute Saved spatial results.
- The delivered S91 manifest and ZIP digest are retained beside this note after main merge; rebuilding at a later revision produces a NEW manifest even if source is unchanged. Use the manifest actually delivered, not the latest generated one.

## Intake
- `python3 -B scripts/ingest_wind_step_evidence.py report.json --manifest WindStepTest.manifest.json` from a matching checkout after bootstrap. Read-only: preserves input, emits review to stdout; caller retains raw JSON unchanged separately. Output-log chunks must first be reconstructed in order into complete JSON; the CLI deliberately accepts JSON only.
- Exit0 `FIRST_SLICE_REPORTED_PASS`; exit1 `BLOCKED_OR_FAILED`; exit2 `INVALID_OR_UNVERIFIABLE`. All statuses carry dynamicsAccepted=false. Never interpret exit0 as permission to activate.
- Strict bounded2MB JSON, duplicate keys/nonfinite values rejected; required schema/types/unique known case names/counts, capped samples and sample-to-aggregate checks. Partial runtime failure reports remain useful when structurally valid; malformed ones remain unchanged for investigation.
- Requires exact report revision/hash match to supplied manifest and five local source hashes. The canonical Luau Evidence.finish is executed through a fixed Lune adapter, not a duplicated Python tolerance policy; counters, matrix flag and outstanding gates are recomputed/checked. Incomplete run, false environment/cleanup, missing/failing cases cannot become a pass through claimed counters.
- SHA256/provenance consistency is NOT signed attestation. A synthetic JSON can pass consistency review; human provenance and actual Roblox execution evidence are still required. Summary samples are not exhaustive lifetime traces, and rate/ownership/physics/feel acceptance is not inferred here. No tolerance widened.

## Validation
- CHECK:PASS: prior626 pure/83specs,28driver groups,7Python spatial-runner tests and9Studio offline groups unchanged; added12 Python intake/bundle regression groups and adapter format gate.
- Tests cover synthetic complete/partial/failed reports, wrong scope/cleanup/completion, counters/gate tampering, hashes/revisions, malformed/nonfinite/duplicate/oversized input, sample contradictions, exact bundle members and CLI exit codes/input preservation.
- Nine temporary behavioral faults detected and restored: revision comparison, source hashes, matrix flag, premature dynamics acceptance, outstanding gates, sample aggregates, duplicate keys, size limit, run completion. The first size-limit mutation survived because invalid JSON also refused; corrected fixture to oversized syntactically valid JSON, then the mutant failed. Final full CHECK PASS after restoration.
- Useful implementation commits: c7e4b2f and0d5c416. No open PRs or stale claims at boot. Next: owner report → d2b2. All dependent lanes remain blocked; no speculative movement/presentation cutover.

## Delivered S91 bundle
- Source revision: `31c870498d5b6aa1203be32096ea77044c100650`. Manifest: `T-043c0b4c3b2b2b2d2b1-S91-manifest.json`.
- ZIP SHA256: `a526e5840e123d8dd362e09a834fc89f69847679c526dd61213b800f3342d80b`. Bundle artifact: `artifact://thread/bff66ec1-7dec-4859-8f6c-49800c528ded/wind-step-studio-bundle`.
- Full check rerun on merged main before artifact creation. This is a test input bundle, not an engine result.
