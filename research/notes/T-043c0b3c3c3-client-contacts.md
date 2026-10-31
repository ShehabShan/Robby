# T-043c0b3c3c3 — bounded contact inbox (S74)
2026-10-31 · D-261 · no renderer adoption, cloud test or publication.

CastContactInbox stores reliable server-confirmed effect receipts independently of acceptance, disposition and terminal caches. CastReceiptClient.contacts() exposes the state for future b4 presentation; it does not render or apply gameplay. A contact before acceptance or after terminal remains valid within its own freshness window. All six A/C/T arrival orders are covered.

Policy: 512 total contacts per client, 12-second local retention and server-age window, 1-second future-clock tolerance. Each immutable record carries cast/ordinal identity plus a length-prefixed cast/resource/tick/target dedupe identity. Conflicting ordinals/identities cannot create two effects; a duplicate keeps original payload and expiry. Ordinals can arrive out of order. There is no high-ordinal watermark that would lose a valid delayed lower ordinal.

Eviction/expiry retains one conservative server-time watermark: records at or below it cannot be resurrected. Under pressure this intentionally may suppress unseen older/same-time cosmetic contacts. It never clears retained contacts or changes hit gameplay. Both payload and identity maps are bounded; no Player/Instance references. Cleanup closes the state; queued old listeners cannot write after teardown. Restart preserves a retirement watermark through teardown server time, deliberately dropping pre-reset effects. A new module/client still rejects server-stale contacts. Server time validates freshness; monotonic time only manages local TTL/pruning.

## Evidence
- CHECK: PASS; 378 pure tests/66 specs; 31 dispatcher and 13 lifecycle cases.
- Nine new pure suites cover reordered ordinals, immutable copies, dual-identity conflicts, bounded eviction/same-time pressure, expiry/restart, local/server clock separation, invalid clocks/fields, delimiter-rich identities, sustained 1000-contact pressure and zero damage.
- Actual adapter tests: six acceptance/contact/terminal permutations; valid contact after terminal; 1000 duplicate events; vectors/clocks; heartbeat expiry; configured-capacity pressure; eviction replay refusal; idempotent teardown/restart and queued old callbacks. No mocked network result is live-device/renderer proof.

Next: T-043c0b4 (split before work). Replace legacy owner echo suppression only with a complete keyed renderer reconciliation plan. Contacts are confirmed effects, not inferred impacts; terminal and acceptance state alone never authorize hit visuals. Preserve source-world lifetime after caster death/departure. Five future timing contract probes remain intentionally red outside green CI.
