# T-047a — corrected commit-latency test package (S108, 2026-11-01)

## Scope and evidence
- The only runtime change relative to published version4 is S107's D-359 driver fix: dash profile time starts at the first driven PreSimulation step. No permission machinery, tolerance, gate or production changes.
- Existing enabled staging and exact-binary verification passed for the isolated target (`research/releases/S100-wind-step-target.json`). Rehearsal record: `T-047a-rehearsal.json`; NOT final consent pins.
- Version4 raw owner failure retained verbatim in `research/inbox/2026-11-01-s106-version4-test-report.md` (12.090 actual / 12.699 commanded vs 14±1). The fix is NOT demonstrated physics acceptance; ~0.6 stud first-frame lag and mid-dash y drop remain unverified (d2b2).
- Default candidate disabled. No upload/publication or consent reservation in S108. Prior consumed consents/journals immutable; never retry.

## Immutable final deliverables
- [S108 approval card and independent final pins](artifact://thread/ebeb0204-3a3c-4fd8-8dea-e315cdbf089f/robby_s108_approval/version/0).
- [S108 exact corrected test ZIP](artifact://thread/ebeb0204-3a3c-4fd8-8dea-e315cdbf089f/robby_s108_stage/version/0).
- Generated AFTER merge and LAST main save; the card has the exact final sourceRevision, archive/manifest/place SHA256 and verification. Missing artifacts mean INCOMPLETE delivery. Retained in this bot VM at `/workspace/robby-S108-stage` plus adjacent ZIP.
- Compare ZIP SHA256 against the card BEFORE extraction; on matching checkout run `python3 scripts/stage_wind_step_published.py --verify --manifest MANIFEST --manifest-sha256 CARD_PIN --place PLACE`. Never rebuild consented bytes.

## Next T-047b — only after authentic NEW approval
- Same procedure as T-046b steps 1–6 in `T-046a-corrected-package.md`: owner approves ONE overwrite of isolated universe6958375460/root121111456135560 with the exact S108 card/package, valid ≤24h; production excluded. Pinned-release exception (no repo edits before dispatch); only `scripts/transact_wind_step_publication.py`; consumed S106 consent never reused; no retries. Then fresh owner Start/report, existing intake, d2b2.
