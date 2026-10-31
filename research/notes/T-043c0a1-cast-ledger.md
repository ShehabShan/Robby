# T-043c0a1 — pure cast request ledger

S68 · 2026-10-31 · D-241. `Shared.CastLedger` is tested preparation, **not connected to live CastRequest**. Timing/sequence behaviour of the published game is unchanged. Parent contract: [T-043c1](T-043c1-timing-contract.md).

## API and invariants

- `new(serverGeneration, policy)` creates isolated state; generation is server-owned, not a credential. Policy is copied/frozen. Caller supplies `capacity`, `maxAdvance` (<32768), and positive finite `responseSeconds`; production values belong in Config at c0b, not hard-coded in this unused module.
- `reserve(state, generation, seq, canonicalFingerprint, monotonicNow)` returns `reserved` plus a server-local reservation handle, `pending`, `duplicate` with the original immutable receipt, or `rejected` with reason. Only `reserved` authorizes the caller to ATTEMPT ordinary gameplay validation/payment; it is not authorization itself.
- `complete(state, reservation, {status='accepted',castId=...} OR {status='rejected',reason=...}, now)` completes exactly once. Fingerprints bind the entire validated request (move, aim, point, generation); c0b must canonicalize without ambiguous concatenation/float rounding collisions. Clients never supply a trusted fingerprint or reservation handle.
- Duplicate accepted/rejected responses cannot run payment, stance, strain or effects again. Pending duplicate never retries work. Different payload under the same sequence is refused. Receipt is only a disposition/reference; the separate bounded cast-state owner stores acceptance time/centre/etc and reconstructs full responses.
- Forward skips up to `maxAdvance` are allowed; unseen older/out-of-order IDs are stale. Cached old duplicates may replay their original receipt. Watermark survives response expiry and capacity eviction; removed requests never become new work. TTL never extends on duplicate traffic. Capacity evicts the oldest expiry with deterministic sequence tie-break.
- u16 rollover65535→0 works. After cumulative forward distance reaches32768, reserve refuses with `rotate_generation`. A server-controlled renewal must happen before that boundary; this prevents an ancient sequence looking fresh after half/full-ring traversal. Renewal protocol must retain bounded old-generation tombstones or explicitly reject all old-generation traffic, never reuse a generation. Do not rotate on arbitrary client request.
- Pending work must validate/pay/complete **without yielding**; callbacks own the capability until completion. Eviction/expiry/generation replacement invalidates old handles. If future adapters yield, reserve only after their async preflight or add a separate transactional owner—do not spend and discover afterward that completion expired.
- `prune` or any reserve/complete removes expired entries. NaN/infinite/backward clocks are rejected. This module trusts its typed internal API: remote argument runtime validation, canonical finite vectors, rate limiting, sequencing sender, character generation, and cast lifetime are c0b responsibilities.

## Evidence

15 pure specs in `tests/CastLedger.spec.luau`: accepted/pending/rejected duplicates, mutated payload/receipt, stale/forward jumps, rollover, expiration and non-extending TTL, evicted handle, 1,000 requests with capacity3, fresh generation, half-ring renewal, malformed numeric/length input, clocks, invalid receipts/configuration. `check.sh` PASS; 293 pure tests total. No effect/engine mocks are needed. These tests prove ledger policy, not wire reliability, collision validation or atomic gameplay payment.

## Next

T-043c0a2 owns bounded prediction/cancellation/tombstone lifecycle. T-043c0b must serialize shared remote/init/Abilities edits, unify both seq allocators and use this ledger only through a tested adapter. Its first fixtures must ensure one cast and one payment under duplicate delivery, generation renewal with packets in flight, rejected stale windows, and no loss of existing M1/Z/X timing. No publication or new asset dependency.
