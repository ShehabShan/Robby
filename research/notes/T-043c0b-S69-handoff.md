# T-043c0b — S69 integration handoff

2026-10-31 · D-243–D-246. Parent **still doing**. Finished b1, b2, b3a, b3b1; no network schema or publication change.

## What is active in source

- One CastRequest allocator in init.client feeds AbilityInput (Wind Step) and KithInput (slot abilities); counters no longer collide. Same connection counter survives character/slot changes. Action remains separate.
- Abilities uses CastTransaction.pay to verify stance + charge resources on copies and commit together; failed payment cannot consume chain/finisher/cancel state. Successful dispatch time, damage and cost are unchanged.
- KithInput similarly trials chain/special state and commits only after local guards succeed. Both input modules require canRequest; init passes true UNTIL b3b2 binds actual generation readiness. This intentionally does not imply server acknowledgement.
- CastAdmission and Config.CastProtocol are unused preparation for b3b2. Receipt storage, CastLedger admission and CastPresentation are not connected to live CastRequest. Live duplicate replay prevention is NOT claimed.

## Next: b3b2 (size before coding)

Read [admission contract](T-043c0b3a-admission.md), [c1 timing contract](T-043c1-timing-contract.md) and its c0a handoffs. Serialize init/remotes/Abilities changes. Do not hide generation handshake inside d2 art work.

Required seams: init.client single cast/canRequestCast closures; input predicates in AbilityInput/KithInput; Abilities.join/remove + CastRequest callback. Server authorization still has silent `return`s. Convert them to explicit outcomes before wrapping in CastAdmission; a nil outcome becomes internal_error. The adapter callback must be non-yielding/non-throwing. Do NOT include deferred/tween work in it. Capture acceptance data once, then dispatch effects outside the transactional boundary with a stable cast ID.

Decide/test startup race before implementation: listeners ready before server snapshot; current character binding independent of attribute replication ordering; old character/generation cannot authorize a new character. Server renews at the configured threshold. Old-generation packets may already be in flight: reject/re-sync without retrying a possibly paid cast; no client-chosen generation, no reused scope, no arbitrary reset to seq0 in the middle of an epoch. Accepted world zones persist on rotation/respawn, per c1. Server-owned stance must reset consistently with the character; current Abilities follows only ActiveKith changes, so do not assume respawn resets it.

b3c then owns reliable full accepted/rejected/terminal payloads with common wall-clock epoch, centre/aim/revision and bounded cache; b4 adopts/cleans owned presentation. Existing CastFx owner echo suppression remains unchanged until that adapter. c2/c3 implement the intentionally unfulfilled Z/X schedule and ground authority fixes; d2 stays blocked until c0b complete.

## Evidence and limits

`bash scripts/check.sh`: PASS; 329 pure tests (59 suites), 11 actual-input mocks, 6 actual-authorization-dispatch mocks, real-source timing characterization, 3 authoring tests, type/lint/build/inspect gates. Extra replay tests check every aim/point component, decoded f32 stability and separate caster scopes. No renderer/device/real-network or cloud test.

`lune run tests/rime_timing.luau --contract` still fails the same **five named readiness requirements** (Z release, X observer/caster timeline and accepted centre); default CI green is not proof those fixes shipped. No asset upload or Roblox publication. Owner M1 quality review remains required after integration.
