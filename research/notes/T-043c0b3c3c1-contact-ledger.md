# T-043c0b3c3c1 — post-damage contact ledger (S73)
2026-10-31 · D-258 · pure module only, intentionally unused by runtime adapters.

`Shared.CastContacts.new(castId, resources, acceptedAt, capacity)` creates a bounded ledger for one world lifetime. `record(state, input)` returns status + immutable contact. Input: resource (1..16 within lifetime), tick (1..65535), targetKey (1..128 bytes), paired server timestamp, pure position/direction, nonnegative amount. Notification identity is cast/resource/tick/target; ordinal is per-cast insertion order. Duplicate returns original; full never evicts. `close` is idempotent, releases retained records and refuses queued callbacks. Invalid input never consumes capacity; a new contact cannot have a timestamp older than the last new contact. Same-time distinct contacts and zero damage are valid.

**Never use record() to decide or apply damage.** The authoritative projectile/volley per-target caps, zone tick state, target eligibility and original-character burst rules remain the only hit gates. Call notification admission only after actual effects/damage. A full contact ledger drops notification, not a hit. A duplicate result must not re-send. This module alone does not prevent duplicate damage or implement contact transport.

## Evidence
Eight pure cases in `tests/cast_contacts.spec.luau`: immutable copies/changed duplicate; distinct casts/shards/ticks/targets; no eviction at cap; closure/late callbacks; status-only zero damage; invalid fields/backward new time; bounded constructor; 192-identity matrix including delimiter-rich target keys with reverse-order duplicates. `check.sh` PASS. No live source or remotes changed by c1.

## Server c2 integration map
- Own one ledger on each accepted world lifetime; close on the same once-only terminal callback that sends CastTerminal. Choose explicit configured per-cast notification cap (bounded active world capacity already exists).
- Shot/volley: use existing `shot.resource`; tick=1, stable server target identity. Call after `shot.register` and `applyOnHit`, not before eligibility.
- Zone: `Zone.step` advances `state.fired` by `due`; enumerate ticks `state.fired-due+1 .. state.fired`, not the loop-local 1..due (which repeats across heartbeats). `applyOnHit` remains once per eligible target per owed tick.
- Burst: resource=1, tick=1; preserve captured living original character checks and once-only delay completion. Stable target identity must not retain Instance references or alias destroyed/respawned targets.
- Pair contact time from acceptance server time + monotonic elapsed, matching terminal clock. Never send a raw os.clock value as server time. Add reliable contact schema; only emit stored notifications. Keep existing HitFx until renderer b4 explicitly switches to avoid unintended loss/double effects.
- Actual-source mocks need all delivery kinds, duplicate/late callbacks, slot/death/leave, tick progression across normal/stalled heartbeats, caps and unchanged damage. Client c3 remains a separate bounded reorder/dedupe policy; a valid contact arriving after a terminal must not be blindly discarded (channels/replay can reorder).

Next: T-043c0b3c3c2, then c3c3, then renderer b4. Five future timing probes stay intentionally red. No cloud test/publication.
