# T-043c0b4b1 — owned command executor (S75)
2026-10-31 · D-264–D-265 · pure module, NOT live-wired.

CastBridge.new(presentationPolicy, perCast, renderer) owns the real presentation reducer and resource registry. predict/accept/cancel/tick take one monotonic authoritative-domain time. Every event first ticks cleanup; the external owner MUST tick while idle. accept receives an already validated/canonical key and timeline; identity/metadata mapping, clock skew admission and contacts belong to b2/b3. Future or backward time is refused here, not adjusted.

Renderer(frame) is synchronous/non-yielding, returns true only if handled. Actions predict/start/adopt/seek carry key, exact resource lease, immutable accepted timeline/centre, phase/progress and poseAllowed. Adoption retains the prediction lease. Renderers seek existing resources and never re-emit one-shots on seek. Use frame.bind(slot, pose|world, disposer) BEFORE enabling callbacks; failed bind immediately disposes the supplied allocation. Every delayed callback tests its own frame.isCurrent(ticket). frame.release accepts only this frame lease's current ticket. Do not keep retired frame/lease references in an unbounded renderer cache.

retirePose(key) permanently closes pose admission for that lease but leaves world warnings/effects alive. cancel means authoritative terminal/rejection only. Local death/leave must not use cancel for accepted world hazards. A post-timeout acceptance gets a fresh lease; a stale callback cannot affect it. Disposers are non-yielding and ownership detaches before callbacks. Renderer false/throw clears every partial allocation, tombstones cosmetic ownership and returns failed; tick false reports at least one failed seek. resourceRefusals/renderFailures/refusals and resources.cleanupFailures are explicit telemetry. A failed essential cue is NOT solved until b2 fallback lands.

Reentrant bridge mutation during render/disposal refuses without changing the reducer. destroy during a command returns false; the external owner retries after the command returns. Idempotent destroy outside a command closes admission and clears all owners. Engine allocation before a disposer is bound is a renderer bug, outside the registry's ability to clean.

## Evidence
CHECK PASS; 412 pure tests/68 suites, including 21 registered bridge cases exercising actual reducer/registry with a fake seekable renderer. Covers owner/observer convergence, adopt/late accept/cancel-before-accept/reject/duplicate/timeout/expiry, centre immutability, pose/world lifetime, clock refusal, capacity and cancellation watermark, partial render failure, disposer failure, reentrancy, stale callbacks, cross-cast ticket isolation, teardown and 1,000-cast bounded stream. No renderer/device/cloud quality or publication claimed.

## Prior art and scope
Borrow explicit prediction identity/adoption and reversible cosmetics, not a game's undocumented internals: https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Plugins/GameplayAbilities/FPredictionKey and https://create.roblox.com/docs/projects/server-authority/techniques . Search reviewed documented action-game cue patterns; Robby does not enable Roblox engine rollback or pretend its own adapter is Unreal GAS. Warning/contact/peak/fade readability follows the vendored animation-VFX skill. Existing owner echo suppression is unchanged until full b4c renderer cutover.

## Next
b4b2: bounded future/clock admission plus separately bounded essential fallback (split before work if needed). b4b3: independent confirmed-contact dispatch after terminals, mapping delivery metadata into renderer commands. b4c: engine/input/listener integration only after both. Five c2/c3 timing probes and owner M1 review remain outstanding.

## Regression sensitivity (S75)
Six temporary behavioral faults were independently detected by real-module tests, then restored in finally blocks: drop adoption, skip expired cleanup, ignore renderer failure, drain acceptance before cancellation, lose future overflow watermark, and unbounded clock correction. Full CHECK PASS after restoration; final expanded suite has 429 pure tests/69 suites. This checks sensitivity to those faults, not exhaustive correctness or live quality.
