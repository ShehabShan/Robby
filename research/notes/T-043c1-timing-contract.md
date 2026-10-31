# T-043c1 — Rimeshard presentation timing contract

S68 · 2026-10-31 · D-238–D-240. **Preparation only; no gameplay, remote, asset or publication change.**

## Evidence and reproduction

Run `lune run tests/rime_timing.luau` (also in `scripts/check.sh`). This executes unmodified source slices from `Abilities.fireCast/volleyCast/zoneCast`, `RimeFx.rain` and the real `init.client` CastFx receiver, with a deterministic clock, real Config/Content/Volley/Zone/FxRegistry and mocked rendering/network boundaries. It does NOT execute the full authorization dispatcher, collision sweep, Roblox renderer or actual network. Existing `client_input.luau` covers actual KithInput dispatch. Source seams are asserted unique; a refactor must update the harness, never silently use a copied implementation.

| Probe, seconds relative to input | Observed before c2/c3 | Required result |
|---|---|---|
| Z, zero latency | Five simulation shots queued at 0; cast + travel broadcast together despite `telegraph=0.20` | No Z shot before acceptance +0.20 |
| M1 finisher | Two shots queued immediately | Keep immediate; do NOT delay every Volley |
| X, zero latency | Caster rain begins 0.60, observer 0.00 | Both follow acceptance +0.60 |
| X, uplink 0.08/downlink 0.04 | Caster 0.60, observer 0.12 | First damage/contact target 0.68, not a fresh delay after receipt |
| X accepted centre | Server raycast snaps (5,6,-10) to (5,0,-10); own CastFx echo is discarded | Caster and observer use accepted centre; predicted ring is provisional |
| X decorative contacts | Eight falling shards; first observer contact +0.22 after receipt | Four grouped contact beats matched to Zone ticks, not eight apparent hits |
| X damage | Real Zone.step: +0.60, +0.933333, +1.266667, +1.60 after acceptance | Preserve all four times and counts; late heartbeat catches up once only |

`lune run tests/rime_timing.luau --contract` deliberately exits nonzero and prints five named EXPECTED-CONTRACT failures on this revision. This is a **red readiness probe**, not a CI pass and not proof the fixes exist. Default CI characterizes known defects while remaining green. c2/c3 must replace each affected characterization with desired assertions and ultimately make the readiness command green; never delete a failed requirement merely to pass.

## Target timeline (implementation contract, not live behaviour)

- Acceptance time **A** is sampled on the server after complete validation and successful atomic payment/stance commit. Send server wall-clock time (`Workspace:GetServerTimeNow`) to clients; retain monotonic time for server scheduling. Never compare server `os.clock()` with client `os.clock()`. Capture both clocks in one acceptance operation.
- **Z:** warning at A; release at A + Config shardFan.telegraph (0.20). Server inserts shots only at/after that deadline. Freeze accepted aim; at release use the same character's current valid root for origin so walking does not leave the projectile at an abandoned position. Send resolved origin at release. Existing five lanes, 30 degrees, range 35, speed 100, two-hit per-target cap, Qi10, cooldown3 and damage8 are unchanged. Travel duration remains range/speed. This is an explicit +0.20 gameplay delay in c2, NOT an art-only change.
- **Z cancellation:** death/respawn, departure or any selected-slot change before release invalidates the pending cast, even if the player switches back. Use a character/slot revision token, not only equality at the deadline. Consume resources/cooldown once at acceptance; no refund on cancellation (avoids cooldown/slot exploits). Rejection before acceptance consumes nothing. No extra root, movement lock or new parry mechanic. After release, existing projectile lifetime/collision rules remain unchanged.
- **Chain/parry:** shot-2 special cancel remains permitted at acceptance; finisher pause1.2 and ordinary recovery0.25 stay unchanged. While Z winds up, reject another Rimeshard attack/special rather than allow an M1 through its wind-up; release/cancel clears this short pending lock. Check chain state and payment on a copy then commit together: existing dispatcher calls Stance.verify before Moves.pay, which can reset a chain on an unpaid cast. Keep current projectile immunity evaluation at actual hit time; the yellow/parryable storyboard does NOT prove ability parry exists. c2 must test the existing Status.blocksHit path and explicitly document any further parry change separately.
- **X:** accepted ground warning over [A,A+0.60); four contact beats at A + Zone.tickAt(i, params), ending A+1.60. For the existing 0.22-second descent, a purely cosmetic fall may begin at A+0.38 so its contact aligns with the first tick; it must not imply early damage or start immediately on acceptance. Use one common timeline for caster and observers. Four groups may contain multiple particles, never multiple damage callbacks. Predicted lift/ring is allowed; predicted damage, hit-sound and confirmed impact are not.
- **X ground authority:** reject non-finite X/Y/Z before a raycast, out-of-range flat coordinates, and invalid/no supporting ground. Raycast from a server-controlled height around the caster, not attacker-chosen altitude; revalidate accepted flat range. Freeze the validated centre/radius for the life of the zone. Existing code validates only X/Z and falls back to the submitted point when raycast misses; these hardening changes belong to c3 and need explicit fixtures. Never use the local cursor after acceptance.
- **X lifetime:** an accepted ground zone persists for its existing four ticks across caster slot/death changes (existing gameplay), rather than silently changing damage in an FX fix. Cancel caster-owned animation immediately on death/slot loss; keep the accepted world warning/hazard until expiry. If server invalidation removes a zone, send terminal cancellation; clients must not invent it. Rejected/unacknowledged predictions are disposable and never deal damage.
- **Late delivery:** derive phase from server time, seek remaining travel/pose, omit elapsed bursts, never restart warning or replay old contact sounds. Heartbeat catch-up still applies each authoritative damage tick once. Client lateness cannot reschedule damage or grant a new warning period. A late client may miss a tell: record this real-network limitation, do not claim reliable transport guarantees advance notice.

## Identity, prediction and terminal state

A shared foundation must land before per-move wiring; existing unreliable CastFx/HitFx alone cannot implement this contract.

1. One CastRequest sequence allocator for both KithInput and AbilityInput (both currently start seq0 independently). Pair u16 seq with a server-issued connection/character generation and a bounded modular replay window. Reject stale/out-of-order IDs according to that window; rollover65535→0 works, fresh generation cannot replay an old character's request. Action.seq is a separate channel. Set exact window/time/cache limits in Config with tests before shipping.
2. One authoritative cast ID per accepted request, scoped by server session/caster generation. Reliable acceptance to relevant clients includes request identity, moveId, castId, A, deadlines, accepted point/aim, character identity and slot revision. Acceptance contains enough data to reconcile without racing attribute replication. Server accepts input intent only; client timestamps, damage or IDs do not establish authority.
3. Duplicates return the original cached response (within a bounded rate/caching policy), never pay or advance Stance twice. An expired/stale request is rejected, never reinterpreted as a new cast. Malformed/rate-abusive traffic may be silently dropped; legitimate failures return owner-only rejection with request identity/reason, no observer cast.
4. Prediction is keyed by request identity. Acceptance adopts the existing pose/ring rather than playing a second copy, corrects centre before impact, and supplies the authoritative schedule. Rejection cancels pending timers, tracks and pooled effects. Add a bounded configurable timeout for missing acknowledgement; timeout removes local prediction but does not cancel an accepted server hazard. A late acceptance starts only the remaining authoritative phase, not a new attack.
5. Reliable terminal cancellation/expiry and bounded tombstones prevent a duplicate/late acceptance from resurrecting cancelled FX. All terminal handling is idempotent. Mid-cast stream-in uses the same server clock/phase; missing character does not invalidate a world-centred accepted zone. Disconnect/respawn cleans client-owned resources and connection caches.
6. Confirmed hit events identify cast, target and impact index/tick, actual amount and position. Deduplicate per cast/target/impact; no miss hit-sound, guessed Chill stack or per-target duplicate camera kick. Essential acceptance/cancellation must be reliable; optional cosmetic detail may remain unreliable. Explicitly decide whether confirmed contacts need reliable delivery in c0b; dropped cosmetics never affect damage. Truthful Chill state remains h1, not derived from contact puffs.

## Follow-up ownership and acceptance tests

**Split before implementation (D-240):** c0a pure identity/lifecycle policy and c0b thin wire integration precede c2/c3 and reconciled d2. They are independent S-sized sessions, not a hidden protocol rewrite inside an art task.

| Task | Files / responsibility | Required checks |
|---|---|---|
| T-043c0a | Pure request identity, replay/rollover, transactional acceptance/lifecycle rules and client timeline state; no remote or gameplay edits | Duplicate/stale/collision, wrap/generation, budget-bound caches, rejection/timeout/late accept, cancel-before-accept, destroy/expiry; pure Lune specs |
| T-043c0b | net/remotes.blink + generated Net; shared allocator through init.client/KithInput/AbilityInput; Abilities validation/payment/echo + client reconciliation adapter | Two client senders, owner/observer same cast ID/centre/time, accepted/rejected/duplicate/late delivery; unchanged live Z/X/M1 timings until c2/c3; check PASS |
| T-043c2 | Z pending scheduler + cancellation in Abilities; current-root release origin; release message/plan | No pre-release shots; five once at deadline; death/slot-away-back/respawn/leave; duplicate Qi/cooldown/strain; shot2 cancel, finisher pause, pending attack lock; hit-time immunity |
| T-043c3 | X accepted-point validation + common four-beat plan/RimeFx adapter | Two-client latency/jitter/drop/late delivery, prediction reconciliation, non-finite Y, no ground/out-of-range; four hits unchanged; no prediction after rejection; zone persists after caster cancellation |
| T-043d2 | Original M1 pose/mesh slice using d1 sources and c0 identity | Standing/moving blend, owned-track cancellation, bounds, accepted hit vs miss, unchanged M1 release/recovery/range/damage; real-client checks remain pending |
| T-043h1 | Separate authoritative Chill replication contract using c0 | Refresh/expiry/consume/target death/streaming; do not infer stacks from FX |

Do not claim new code solves any row here merely because characterization is green. Do not bundle Z/X special-move art before the M1 owner review gate. No gameplay publication is authorized by this contract.

## Design sources and limitations

- Owner-approved direction and visually inspected high-quality Blox Fruits references: [T-043a audit](T-043a-reference-audit.md), [direction §§3–6](T-043a-rimeshard-direction.md), [approval](../inbox/2026-10-31-rimeshard-direction-approved.md). Borrow anticipation→contact→tail and readable boundaries, not assets or mechanics.
- S68 `scripts/search.sh` cross-check surfaced [Roblox server authority](https://create.roblox.com/docs/en-us/projects/server-authority.md) and [techniques](https://create.roblox.com/docs/en-us/projects/server-authority/techniques.md). This repo retains its existing manual server-authoritative damage architecture; **no** Server Authority/BindToSimulation migration is proposed. Networking/VFX skills supply clock, validation, reversible prediction and resource ownership guidance.
- Headless source-level evidence only: no real two-player networking, renderer, pose/blend quality, frame-time, asset permissions, audio or mobile proof. Functional input check T-042b and owner quality gates remain open.
