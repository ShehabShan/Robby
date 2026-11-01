# T-044c1 — concrete S100 approval package (2026-11-01)

> Superseded by S101: see `T-044c2a-owner-attestation.md` for new final-main package and distinct owner-declaration schema. S100 owner explicitly waived the screenshot in `research/inbox/2026-11-01-owner-permission-waiver.md`; do not request one. Old revision/pins below are historical, not dispatch authority.

## Owner decision: NOT READY TO PUBLISH
- This is an isolated Wind Step diagnostic, NOT a Robby gameplay update. Publishing replaces the entire test start place (including any existing contents), not the main game. No backup or empty-content proof exists; do not approve if anything there needs preserving.
- Test universe `6958375460`, start place `121111456135560`, owner `7738981129`; production universe `10773761715` / place `95587500384127` are forbidden. Privacy/ownership/root must be checked again immediately before publication.
- Enabled test scripts still require the original owner's explicit in-game Start. One player only; it may move the avatar through the diagnostic. No real physics, Sober/mobile rendering/copy or feel PASS yet. Report consistency is not execution authenticity.
- Owner reviews the exact pinned package below, then explicitly approves its entire-test-place overwrite and ONE publication attempt, valid for at most 24 hours from that reply. A generic continuation or this document is NOT consent. An uncertain attempt must never be retried automatically.
- Also supply a fresh redacted Creator Dashboard grant view for the SAME credential stored in `roblox-open-cloud`: scoped to this test universe, `universe-places` Write and `universe.place:read`; confirm that binding in words. Hide the entire key/token and unrelated account information. Never send the key. Operator reviews original source and preserves it outside the public repo; no synthetic review.

## Durable deliverables (S100 bot)
- Approval card, exact pins and copyable consent wording: [S100 approval package](artifact://thread/e887fc9d-57ac-49e8-b7ae-c091dce8530c/robby_s100_approval/version/1).
- Exact enabled RBXL + manifest + target + SHA256SUMS + README + existing offline check/verification evidence: [S100 retained package](artifact://thread/e887fc9d-57ac-49e8-b7ae-c091dce8530c/robby_s100_stage/version/1).
- These version-1 artifacts are immutable references; compare the downloaded archive SHA256 with the separate approval card BEFORE extracting. Keep the exact sourceRevision and original bytes; do not rebuild a consented package. Files also retained at `/workspace/robby-S100-stage` in that bot VM, outside `build`.
- The final package is assembled AFTER merge and final STATE save. Its sourceRevision is that final clean synced main. A commit containing its own hash is impossible; repo stores the immutable artifact pointers, the card independently stores pins. Missing artifacts mean incomplete preparation, not permission to infer pins.
- No consent/review JSON, credentials, remote publication reservation or Roblox write is part of this preparation. `publishReady`, `releaseEvidenceAccepted`, `dynamicsAccepted` remain false.

## Operator sequence
1. Read package/card and compare exact bytes/pins. Confirm actual `git rev-parse HEAD`, branch main, clean tree and fresh `git ls-remote origin refs/heads/main` equal the card sourceRevision. Check relevant source/tool hashes with existing stage verifier; retain an independent copy outside build.
2. See AGENTS §9 pinned-release follow-up exception: claiming/releasing/STATE edits create commits, which would invalidate exact-revision consent. The publication follow-up is read-only preparation + existing transaction, not a new coding session. Check no other task claims/session branches before dispatch; otherwise stop. Do not rewind remote main.
3. Inspect authentic owner's reply and redacted dashboard source. Convert faithfully to the EXISTING strict consent/review schemas (`preflight_wind_step_release.py`, `wind_step_permission_review.py`); pin both and source independently. Actual reply/review timestamps, <=24h validity; do not pre-approve or date templates. Save private original sources and JSON outside repo/public artifacts.
4. Run ONLY `transact_wind_step_publication.py --help` to confirm arguments; follow `T-044b3b2b2b2-transaction.md`. Fresh private-owner/root and unchanged clean main gates remain mandatory. Existing durable consent journal provides single-attempt cross-VM exclusion; do not invoke production publish.py or cloud_test.py for this target.
5. Preserve exact transaction spool, canonical journal and receipt pins. HISTORY_CONFIRMED proves only historical version; then supply test join instructions and request complete owner report. Apply `ingest_wind_step_release.py`; remaining dynamics/repair is T-043c0b4c3b2b2b2d2b2. No production activation.
6. Only AFTER dispatch/definitive refusal, save consent source pointer (not private source), sanitized result and task status. If main changed before dispatch, stop; restage new bytes and obtain NEW explicit approval. No silence-based carryover, no guard relaxation.

## Evidence and limits
- Existing complete check.sh suite must pass before merge; exact final staged binary reconstructed by existing verifier after main save. Default candidate remains disabled. No runtime/source/gate code changes.
- Final target GET (if available) is recorded in the approval artifact with observation timestamp; it expires as authority immediately and is NOT Write permission, empty-content proof or owner consent.
- Parent T-044c is split: c1 preparation; c2 blocked actual publication. No further generic tooling tasks added. Keep all dependent activation lanes gated.

- S100 target-specific rehearsal: enabled package + exact-binary reconstruction PASS; correct revision/false readiness confirmed; production-universe, production-place, wrong-owner and session-branch publication refusals PASS. Rehearsal pins are intentionally NOT approval inputs; final version-1 artifact pins replace them. Full existing CHECK PASS before both branch saves.
