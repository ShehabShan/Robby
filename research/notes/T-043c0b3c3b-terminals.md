# T-043c0b3c3b — reliable terminals (S73)
2026-10-31 · D-256–D-257 · no cloud test/publication.

- Server: one non-yielding CastLifetime.onTerminal callback after final resource completion/cancellation/expiry sends CastTerminal (reliable, castId/reason/paired server time). Already-ended callbacks cannot re-emit. Heartbeat still runs owed zone ticks before expiry. Accepted zones/projectiles survive slot/death/leave; delayed Shatter still binds the original character.
- Replay: bounded world cache (2048, 12 seconds) copies immutable acceptance then terminal independently of player presence. Existing owner cache is marked ended too. An admitted duplicate gets original acceptance then terminal, owner-only. No payment/delivery replay; generation/ledger admission remains authoritative. This is not a late-join snapshot or a new replay-request API. After departure the world record remains bounded for the existing response window, while observers get the terminal broadcast.
- Client: CastReceiptClient stores reliable terminal in CastInbox. First terminal wins, terminal-before-acceptance suppresses a delayed start, no TTL refresh on duplicates. Retention 256 records/12 seconds; eviction/expiry leaves one server-time watermark preventing resurrection of known ended casts. Conservative overload can suppress unrelated unseen old visuals, but never clears an already-recorded live world hazard. Server end + grace rejects already-expired acceptances even after adapter restart. Monotonic cache time and synchronized server presentation time are separate.
- Renderer adoption remains b4: no prediction/pose/travel/contact renderer switched, no old FX enabled twice. Do not equate a green receipt test to corrected live visuals. Confirmed hit/contact transport remains c3c. Existing five future timing probes remain intentionally red for c2/c3.

## Evidence
`check.sh` PASS: pure lifecycle once-only/reentrancy and inbox permutation/reordering/pressure/expiry/invalid clock tests; actual server request adapter proves acceptance-before-terminal replay, original geometry, no repeat payment, departure, bounds and expiry; real delivery mocks (projectile, volley, zone, delayed burst) each emit one terminal with unchanged damage; actual client listener registration, server/monotonic clocks, terminal-before-acceptance, late duplicates, destruction/restart. These are mocked engine/network boundaries, not real Roblox network/mobile or visual acceptance.

## Prior art
Borrow reliable start/end notifications with stable identity; unreliable channels are only suitable for replaceable intermediate state. References: https://create.roblox.com/docs/en-us/scripting/events/remote.md and https://devforum.roblox.com/t/approach-to-zero-latency-feedback-for-physics-heavy-projectiles-client-prediction-server-verification/4844029 . No claim about Rell Seas internals.

## Next
T-043c0b3c3c: confirmed contacts (split before implementation if needed), then b4 renderer. Do not infer a hit from an acceptance or terminal. Preserve world-owned lifetimes and server damage eligibility.
