# T-043c0b3c3c2 — server confirmed contacts (S74)
2026-10-31 · D-259–D-260 · no cloud test or publication.

Each accepted world handle owns a CastContacts ledger (128 notifications maximum, bounded by 2048 active world lifetimes). A reliable CastContact carries cast/resource/tick/ordinal/target identity, paired server processing time, position/direction and applied-effect amount. Only stored post-effect records broadcast; neither duplicate/full notification admission nor listener state gates authoritative hits or legacy HitFx. No contact replay on duplicate requests; this is not a late-join snapshot.

Shot/volley resource IDs use existing shot identity and tick=1. Zone enumerates cumulative state.fired-due+1 through state.fired across normal/stalled heartbeats. Burst uses resource/tick=1 and retains original living-character and once-only callback guards. The existing weak per-model server hitKey table distinguishes replacement models without retaining instances in contacts. Terminal callback closes/releases the ledger before broadcasting the terminal. Accepted world projectiles/zones still survive slot/death/departure.

CastReceiptClient temporarily drains CastContact without rendering/storing it: Blink otherwise accumulates an unbounded queue before a listener registers. c3c3 must replace this drain with the bounded contact inbox. This does NOT claim corrected visuals or infer hits from acceptance/terminal.

## Evidence
- check.sh CHECK: PASS; 369 pure tests/65 specs, 31 dispatcher cases, 13 actual-source lifecycle cases, actual receipt-client adapter.
- Lifecycle mocks exercise all four deliveries; payload/frozen records; damage-before-notification; cumulative regular/stalled zone ticks; configured 128-record cap and filled-ledger controls with identical damage/HitFx; duplicate/late callbacks; miss/blocked/zero-damage contacts; fresh target identity on respawn; terminal release. Dispatcher verifies ledger creation survives player-cache teardown and duplicate requests do not reallocate it. Client drain tested with 1000 messages and teardown/restart.
- These are mocked engine/network boundaries, not Roblox network/device or visual approval. Existing five future timing probes remain intentionally red outside green CI.

## Prior art and next
Reliable critical notifications, stable server identity and server hit authority follow Roblox networking guidance: https://create.roblox.com/docs/scripting/events/remote and https://devforum.roblox.com/t/network-efficient-and-safe-practices-with-projectiles/2608367 . No claim about Rell Seas internals. Next c3c3: independently bounded contact-before-acceptance/terminal ordering, duplicates/late valid contacts, eviction/expiry and listener lifetime; renderer adoption remains b4.
