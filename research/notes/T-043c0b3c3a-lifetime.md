# T-043c0b3c3a — world-owned delivery lifetime (S72)
2026-10-31 · D-253–D-255 · no cloud test/publication.

- `Shared.CastLifetime` owns active handles independently of player replay-cache/session lifetime. Each handle carries a deep-frozen acceptance and at most 16 resource IDs; each resource completes once, the last releases one local terminal. Slot/character generation changes and cache eviction never destroy world hazards.
- World capacity 2048 rejects before payment (`delivery_capacity`), never evicts paid casts. The server authorization/capture path is non-yielding. The lifetime bound is the accepted schedule plus one second grace; heartbeat processes due zone ticks/projectile travel before expiry so stalls do not silently erase owed work. Completed handles leave the active registry immediately. Terminal transport/tombstones belong to c3b, not this change.
- Actual shots/volley shards/zones retain the same handle; volley resource IDs are shard indexes. Existing damage eligibility and per-target caps stay authoritative. Self effects retain their handle until their accepted duration callback. Accepted zones/projectiles survive slot change, death and departure.
- Delayed Shatter is character-bound: same captured character must still be alive and player present. Never use a respawned character as an old attack's origin. Slot-only switching does not cancel paid work. Duplicate/expired delayed callbacks do not damage. No successful cast timing, hit geometry or tune changed.
- Existing `CastReceipts` cache is still destroyed on departure. Active handle acceptance survives it. c3b must bridge terminal events to reliable transport and bounded replay/tombstones BEFORE claiming any network reconciliation guarantee.

## Evidence
`check.sh` PASS, including five new pure lifetime cases and five new real-source lifecycle scenarios (one covers three caster-loss causes). Tests execute actual delivery and heartbeat source with mocked engine queries/FX/damage; pure projectile/volley/zone cores are real. Coverage: capacity/idempotence/immutable geometry/expiry, volley per-target cap, stalled zone ticks after slot/death/leave, original-character Shatter, duplicate/late callbacks. Not real Roblox networking, visual quality, mobile or gameplay acceptance.

## Prior art
Search: server-authoritative projectile lifetime and ownership. Borrow server-owned raycast simulation decoupled from clients, consistent with existing architecture; no assertion about Rell Seas internals. Sources: https://devforum.roblox.com/t/who-should-i-set-the-network-ownership-of-a-projectile-to/1487698 and https://devforum.roblox.com/t/viability-of-authoratative-projectiles/3986791 . This change fixes ownership, not a new combat design.
