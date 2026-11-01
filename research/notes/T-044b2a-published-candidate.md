# T-044b2a — disabled published-server candidate (S92, 2026-11-01)

## Delivered
`python3 -B scripts/build_wind_step_published.py` creates `build/published-test/WindStepPublishedCandidate.rbxl`, a manifest, generated server source/project and repo-relative sourcemap. No API calls/upload path. Default IDs=0, Disabled=true, RunWindStep=false. Optional --target accepts only T-044a strict non-production config; even bound builds remain disabled. DO NOT publish this candidate as the owner's playable test.

The generator takes the original Studio harness body with exact reviewed seam replacements: separate live header/guard, repeated original-player/owner/target checks, and PublishedPolicy.finish. It refuses absent/duplicate replacement markers. Source body, real driver/clearance/motion, canonical row policy, fixtures and independent cleanup remain exact except the reviewed entry/case guard/final classifier. Studio source/bundle/intake and default game are unchanged. Generated file passes real sourcemap type/lint/format checks, not just string matching.

Manifest records exact revision,10 input hashes (including builder/config validator/project), generated server hash and place hash. Identical inputs produce identical repeated place/manifest digests. publishReady=false and dynamicsAccepted=false are explicit. Source revision can change on subsequent rebuilds: bind any future evidence to the exact delivered manifest.

## Offline validation
- 3 Python groups: expected body/cleanup preservation, source boundary/finalizer/guard drift refusal, either production ID rejected before build.
- 3 Lune groups: execute generated entry with15 unsafe runtime configurations (all refuse before driver/fixtures), exact disabled package/hash checks, default/Studio isolation. No-player wait bounded at120s; no actual engine/scheduler test claimed.
- Synthetic explicit separate-ID build verified both target binding and disabled/manual opt-in; no remote access. Three temporary builder faults (enabled script, implicit opt-in, false publish-ready) each detected and restored. Full CHECK PASS after fixes. Header is a partial source template: lint its generated whole, not incomplete locals in isolation.

## NEXT: T-044b2b, then b3/c
The candidate intentionally has NO client start/status/report surface; server-local WindStepEvidence still cannot be retrieved by the owner in Sober. Add owner-only explicit start with bounded server input and timeout/retry/leave/extra-player checks, readable results and full bounded JSON export/retrieval. Consider owner-only replicated report plus UI (no external secret/persistence). Do not send tests through main game startup or weaken the106-case policy. Test runtime glue against actual generated source before enabling anything. Extra-player/leave mid-case and failure cleanup require live-adapter lifecycle coverage, not just header refusal tests.
T-044b3 must support the truthful published evidence kind, exact live manifest and safe release tooling; existing Studio intake must continue refusing it. T-044c requires a real EMPTY owner-owned PRIVATE universe/root + key resource permissions, merge to main, fresh preflight, explicit test-only publishing and readback. Never call production publish.py. Actual physics/feel/death/replacement/rate validation remains open; no activation authorized by synthetic passes.
