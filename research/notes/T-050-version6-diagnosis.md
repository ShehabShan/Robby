# T-050 version6 diagnosis (S114, 2026-11-02)

## Reproduced command loss — T-050a / D-369
- Exact owner row retained in `tests/fixtures/wind-step-version6-travel.json`; original inbox unchanged. All 15 samples are preserved.
- First step command minus actual = 0.609419864 studs. Total command minus actual = 0.609408308: subsequent X increments follow commanded travel within ~0.000012 studs. The dip does NOT establish additional horizontal solver loss or that D-368 caused the travel regression.
- Inverting the braking integral at samples 10–15 yields elapsed minus accumulated simulation dt = 0.00610467 seconds. Old `max(covered, wallElapsed)` permanently latches any positive clock lead: one ~6.105ms jump skips 0.427327 studs, reproducing commanded 13.572673. Pre timestamps are absent; the test's early lead schedule is compatible, not recovered engine history. Owner `t` is post-observation os.clock; driver uses GetServerTimeNow, so do not equate them.
- Profile now advances only on paired simulation dt. Wall clock still rejects reversal, >50ms callback gaps and accumulated >50ms lead; no catch-up speed, stale replay or tolerance increase. Supported ±6.2ms jitter yields14 commanded; subtracting the observed startup lag predicts13.39058, NOT verified real travel.
- Red-before-green actual-source regression: old driver13.572674 !=14. CHECK PASS,36 driver groups; existing hitch/stall/duplicate/final-partial safeguards pass.

## Vertical diagnosis — T-050b remains
- Floor fixture is one160x2x80 Part, topY0, covering X[-80,80], Z[-40,40]; spawn is at X=-50. No authored edge/seam at X7–13. Does not rule out an unsampled engine interaction.
- D-368 only zeros negative velocity at PreSimulation. Plane LinearVelocity cannot constrain Y during simulation. Mock previously never integrated Y/gravity; its one-step velocity assertion could not detect a within-step downward force. Samples7–14 show a dip, but contain no floor-hit, hold-applied, HipHeight or humanoid-state data; exact physical trigger is unproven.
- Research via search.sh: official LinearVelocity reference https://create.roblox.com/docs/reference/engine/classes/LinearVelocity distinguishes Plane/Vector axes; community solver discussion https://devforum.roblox.com/t/setting-assembly-velocity-wont-cancel-constraint-force/4670463 . Search summaries are guidance, not Roblox verification.
- Next: bounded solver-time vertical support when grounded, with air/upward/ledge/lifecycle tests; do not call a mock replay real physics acceptance.

## Release
No publication. T-050c requires final clean main staging and NEW exact-byte owner approval. Consumed version6 consent must never be reused. Production/default-disabled candidate unchanged.
