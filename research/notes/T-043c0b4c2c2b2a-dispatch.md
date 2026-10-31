# T-043c0b4c2c2b2a — borrowed delivery dispatcher (S81)

## Delivered
- `src/shared/CastDeliveryDispatch.luau`: pure borrowed-inbox orchestration; no startup/listener/gameplay changes.
- Owns Store plus ONE outer WarningGate. Renderer callbacks receive frame + canonical Store entry; use entry.accepted.metadata and entry.identity. No second receipt cache.
- Poll first, prune upstream, process ALL terminal/rejected records before future drain/seek/admission; expired disposition is not rejection. Two monotonic serial cursors bound observation memory.
- `CastClockGate.cancelMany` cancels pending and primary keys before any seek/drain; outer gate cancels reserve keys before reserve tick. Do not replace with sequential single-key cancellation.
- Stage immutable metadata BEFORE accept/predict; prune only against actual gate ownership after commands. Late same-key remaps never replace pinned metadata.
- Inbox retired-terminal watermark conservatively cancels old owned entries even when their terminal was evicted before polling.

## API / ownership
- `Dispatch.new(inbox, catalog, policy, render, warning, cursor?)`; `tick(localNow, serverNow)`; `predict(key, identity, localNow, serverNow)`; `retirePose(key, localNow, serverNow)` (state first on methods).
- Supply validated identity, not inferred replacement-character identity. Renderer callbacks are synchronous/non-yielding; reentrant dispatch mutation is refused.
- Tick uses outer clock sample admission only. A true tick means clock processed, NOT visible renderer success. Inspect gate/fallback/reserve/bridge counters for degraded/refused rendering.
- `destroy(state)` returns Cursor or nil when busy; safe repeated shutdown. Preserve cursor across restarts. Stop this owner BEFORE CastReceiptClient. Unexpected closed inbox also cleans resources.
- Cursor retains same-inbox serials and conservative server watermark, including queued future and unpolled accepted/terminal timestamps. Fresh-inbox restart skips older cosmetics; no gameplay permission is derived.
- Reserve tombstones retain capacity by design: cancelled cues do not immediately free admission slots. Overflow must remain explicit; never invent successful warnings.

## Evidence
- `tests/cast_delivery_dispatch.spec.luau`: 30 cases, including future/no-flash terminal batches, expired/rejected distinctions, reordered acceptance, pinned eviction/remap, bounds/100 turnovers, pose-only retirement, fallback failures, clocks, early pending release, reentrancy and restart.
- `tests/cast_delivery_engine.luau`: 3 additional real-source Dispatch/Fx/Tree compositions (17 total engine cases). Prediction/adoption, death-preserved world, failure→reserve, multi-terminal no allocation, borrowed shutdown/restart.
- CHECK PASS: 565 pure tests/77 specs plus all existing gates. Ten temporary behavioral mutations detected then restored. Early pending-capacity test added after initial mutation escaped.
- These are headless mocked engine tests, not cloud/network/device/visual acceptance.

## Next b2b (size/split first)
- Thin engine heartbeat + original-character lifecycle binding, compose real Fx pools with this dispatcher; preserve cursor on restart, dispose subscriptions and pools in safe order.
- Identity audit: server keeps characterKey/slotRevision in CastSession; CastGeneration is local-player handshake only. Observers cannot truthfully resolve originals from current replacement Character. Resolve replication contract before implementing observer pose lookup.
- Retire only original-character pose on death/removal/slot change; accepted world hazard remains. Missing pose never cancels a world cue.
- b2b actual listener/engine integration remains unimplemented. Delivery startup stays OFF until c2c2c truthful moving Burst + c3 atomic legacy/keyed cutover. Burst still explicitly unavailable, no fake fixed origin warning.
- Prototype prediction pose art is still a no-op. No Roblox publication authorized.
