# R-031h — Slide and move-chaining evidence (S153 recovery, 2026-11-04)

## Scope and evidence
Owner-requested recovery of the stopped R-031h session; movement only, no fighting design or game changes. The stopped branch contained a resume note, not a completed study. The current owner upload was downloaded and independently fingerprinted; [source and nine reviewed proof sheets](../video/movement/R-031h/README.md), [manifest](../video/movement/R-031h/manifest.json), [cue brackets](../video/movement/R-031h/event-intervals.json).

The clean ship scene is the main slide/chaining evidence. Full-frame context and enlarged original-pixel crops are both retained. Labels are **first-decoded-frame-relative time n/60**, not raw container PTS: ffprobe reports first-frame PTS **0.033333 s**, so add that offset to locate a label on the raw PTS timeline. All 77 selected frame timestamps were checked after subtracting this offset; interval differences are unaffected. Adjacent-frame differences and visual review show repeated pairs: the 60 fps container is not proof of 60 independent images/s, simulation rate or 16.7 ms input precision.

## 1. What the ship sequence actually shows
| Proof / first-frame-relative time | Visible observation | Limit |
|---|---|---|
| `approach-pose`, `low-pose-onset`: 122.0–123.1 s | Upright running gives way to a sustained low, leaned posture while deck scenery continues moving. Broad upright→clearly-low bracket n7376–7386 (122.933–123.100). | A **slide-like pose**, not a decoded slide button, grounded-state signal or established slide startup. Gradual transition makes onset ambiguous. |
| `low-pose-exit`: n7400–7403 (123.333–123.383) | Low pose changes to raised/upright posture; body/shadow separation becomes conspicuous in the following frames. | Visual exit, not proof that a jump canceled a still-active slide. Natural ending, queued jump, ledge departure and other traversal logic cannot be distinguished. |
| `stair-transition`, `streak-exit`: 123.450–123.717 | Upright/raised body moves across the staircase background with thin alternating dark/white vertical streaks and a brief stronger white accent. Streak first present n7407; last present n7422, absent n7423. | These are **post-low-pose traversal streaks**, not proof of a grounded slide down stairs. No exact collision path or world-space speed. |
| `slide-coarse`, `occlusion-context`: 123.8–124.6 | Body continues through the deck scene, then near-camera wood/rail hides it; visible at124.25, hidden124.30–124.55 samples, visible again124.60. | The interruption is camera occlusion, not a demonstrated pause or move cancel. Cannot trace continuous body state through it. |
| `second-low-to-rise`: 124.65–125.15 | A second sustained low pose is visible124.65–124.90, then raised body at124.95 and upward streaks. | Second low-pose start is not cleanly observable. Low→rise is compatible with chaining but supplies no accepted-input window. R-031f owns the later rise/edge measurement; touchdown stays unproven. |

**Correction to S147/S146 log:** the old “slide down stairs123.45–123.68” conflated the streaked, raised-body phase with the earlier low posture. Withdraw that interval as a measured grounded-slide duration and the “stairs at flat speed/no hop” certainty. Do not replace it with an equally unproven claim of a specific jump/dash mechanic. The desired clean wind-line style remains a design direction (D-442), not a verified slide-only emitter rule. No dense smoke cloud is evident in the reviewed low/streak phases; this is not proof that every reference slide has no particles.

## 2. Measured visible intervals — not control windows
Bounds combine the reviewed cue brackets; rounded outward to milliseconds. Frame endpoints remain in the JSON so the rounding is not false precision.

| Observable | Recording interval | Interpretation |
|---|---|---|
| Upright→low onset to low-pose exit | **0.233–0.450 s** | Broad visual low-pose envelope, not slide-state duration, minimum hold or animation clip length. |
| Low-pose exit to first streak | **0.050–0.117 s** | Relative presentation timing; not input latency or a mandatory recovery delay. |
| First streak to streak disappearance | **0.250–0.284 s** | Visible streak envelope, not per-particle lifetime. Reappearing lines are not necessarily the same emitter/particle. |
| Camera hides avatar until visible again | **0.250–0.350 s** | Occlusion duration bracket, not gameplay freeze. |
| Second low→raised transition | **124.900–124.950 s** | Event bracket, not a 50 ms cancel window; matches R-031f. |

## 3. Cancel windows and momentum: what remains unknown
- The video shows **run→low posture→raised traversal**, then another **low posture→rise**. It does not show input timestamps, rejected attempts, held/released state or an authoritative action-state trace. Thus earliest/latest accepted cancel, input-buffer length and whether this was a cancel at all are **unmeasured**. No dash→slide, slide→dash or slide→slam rule is established here.
- Continuing travel is a useful *visual continuity target*, not evidence of constant speed or momentum conservation. Camera tracking/orbit, perspective, changing elevation and unknown scale mix with body motion. No studs, acceleration, horizontal velocity ratio, slope bonus, friction or airborne steering rate is calibrated.
- An event sequence observed once is not a general transition matrix. The hidden section cannot establish cooldown, spam prevention, stamina cost or reset; the ending cannot establish landing recovery.

## 4. Robby baseline — code comparison, not reference measurements
Source snapshot: the game code inherited on `d06e743` (no code altered in this study). [Config.Movement](../../src/shared/Config.luau), [Movement.canSlide / slideStep / step](../../src/shared/Movement.luau), [SprintClient](../../src/client/SprintClient.luau).
- Slide eligibility in the pure rule: grounded, moving, speed≥22, stamina≥15, no active slide, cooldown or landing recovery. Starts at max(current scalar speed,30), costs15, cooldown1 s, duration0.6 s; quadratic easing toward jog18.
- While sliding, becoming airborne ends the slide and retains the current **scalar speed** until grounded; this branch does not require an explicit jump-input flag. Walking off an edge can therefore satisfy that pure-rule condition. Grounding clears carry; hard landing recovery can clamp speed.
- SprintClient routes Q to slide only in its forward/sprinting case (otherwise directional dash); uses Humanoid floor material for grounded, calls Movement.step and assigns Humanoid.WalkSpeed. This is a speed target, **not a measured invariant of AssemblyLinearVelocity or conserved direction/vector momentum**. Dash separately writes velocity. No live-engine behavior was verified here.
- Do not retune0.6 s to the visual0.233–0.450 s envelope: they measure different things. Config/source comparison identifies questions for P-031, not a tuning result.

## → Implications for Robby / P-031 handoff (proposals only)
1. Preserve readable low→raised silhouettes and clean, sparse streaks without making all locomotion a smoke burst. Specify animation, cue timing and gameplay states separately; do not use emitter start/end as state boundaries.
2. P-031 must explicitly choose which movement transitions are legal, which consume resources, and whether slide→air preserves scalar speed, direction, both or neither. Keep intentional jump vs accidental ledge departure as a design/test distinction. Do not inherit hidden rules from this footage.
3. Later testing should record input press/release and consumed tick, action state, grounded/contact, horizontal velocity vector, stamina/cooldowns and camera separately. Sweep attempted transition timing early/middle/late, include rejected inputs and no-input endings; compare flat floor, stairs, ledge departure, reversal and landing. This would measure cancel/buffer windows and carry rather than guess them.
4. Use the combined e/f/g/h evidence in the **separate P-031 planning session** before movement implementation. Owner1–2 air dashes/slam remain intent, with mechanics chosen explicitly. No gameplay tuning, assets, Open Cloud write or publication occurred in R-031h.

## Unknowns and sources
Primary evidence: owner re-upload plus the committed proof/PTS/difference receipts above. Existing code is the source only for Robby's baseline; [R-031f](R-031f-strafe-jump.md) and [R-031g](R-031g-air-dash-slam.md) delimit adjacent studies. A general input-buffering web search was exploratory only and is not used to assert any Rell Seas mechanic. Exact inputs, cancel/buffer windows, physical momentum, trajectory/contact, speed, duration of the second low state, costs/cooldowns and landing recovery remain unknown. No model-memory facts fill these gaps.
