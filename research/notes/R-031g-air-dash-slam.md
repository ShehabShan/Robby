# R-031g — Air-dash and slam-down evidence (S152 recovery, 2026-11-04)

## Scope and method
Movement-only study of the owner's reuploaded `movement.mp4`; no fighting design, game edits or publication. Recovered the stopped S152 branch (only a resume note), then used the current bot's upload, verified identical SHA/79,162,802 bytes. [Provenance](../video/movement/README.md), [twelve reviewed sheets, manifest and reproducer](../video/movement/R-031g/README.md).

Times below are recording seconds, frame n/60 (zero-based), not confirmed simulation or unretimed real time. Full-frame context preserves camera/HUD evidence. Coarse 0.5 s samples locate candidates; 0.1/0.05 s samples and consecutive boundary frames refine visible cues. A pixel is not a stud; camera pitch, zoom, perspective and occlusion prevent calibrated travel/velocity. Forest frames change consecutively in the saved difference sample; the ship's paired-frame pattern from R-031f is not a recording-wide rule. Neither pattern proves simulation FPS.

## 1. Air-dash count, distance and refresh
| Footage / proof | Visible observation | What it does NOT establish |
|---|---|---|
| 64–66.5 s, `burst-context` | Multiple white afterimage columns, body repositioning, second character; PARRY text at66.0. | Counting effects is not counting ordinary Q presses, charges or free air dashes. Exact flurry count/distance is not measured. |
| 67.2–68.2 s, `burst1-detail` | Body changes pose/orientation while another character remains nearby/below; downward streaks appear before white burst. | These may mix jumps, forced motion and context-specific actions. A rotation is not proof of a separate dash. |
| 72–79.5 s, `air-a/b` | Airborne-looking interaction, purple/sword trails/red flashes and another character. Overlay hides central action around73.5–74.5. | Cannot reconstruct uninterrupted takeoff→dash1→dash2→failed dash3→landing. No proven charge counter, maximum or refresh. |
| 83.2–83.6 s, `burst2-onset` | Encircling white arcs and changing body/background position; camera turns from sky toward tiled floor. | One visible effect episode is not a verified free-air dash or measured forward/downward travel. |

**Result:** the requested **1–2 air dashes** remain owner intent for P-031, not a measured reference maximum. Maximum, direction eligibility, distance in studs, stamina cost, cooldown and refresh trigger are **not identifiable here**. Landing refresh (D-444) stays a design proposal. Fan-wiki air-jump counts must not replace air-dash counts. See [R-031e audit](R-031e-movement-mechanics.md).

## 2. Two descent/burst candidates, not interchangeable slam proofs
**Candidate A, 68 s:** body approaches the tiled-floor presentation with long vertical streaks, followed by a bright white burst, concentric rings, dust-like haze and angular debris. This is stronger ground-near visual evidence than the blue burst at83.6, but blur/effects hide exact sole contact. Another character is present/already airborne: voluntary target-free activation, physical collision and who caused the motion remain unknown. Later purple/yellow flashes start a new effect episode; do not measure all of it as landing recovery.

**Candidate B, 83 s:** purple glow and close camera precede a rapid pullback, body ring, downward-looking camera turn, blue-white flash and blue pillars. Body remains visually separated from the tiled background afterward while rings trail away; the later floor approach is a separate observation. **Do not label83.667 as proven touchdown, or the pillars as definitely emitted from the ground.** This qualifies the old log rather than discovering a standalone traversal slam.

### Measured visible cue intervals
Exact frame brackets are in [event-intervals.json](../video/movement/R-031g/event-intervals.json). Bounds assume a transition between reviewed absent/present samples; rounded outward below. They describe screen events, not input or physics latency.

| Cue | Source-frame bracket / evidence | Recording-time result |
|---|---|---|
| A: long vertical streak onset | n4080 no long streak →4086 present (`burst1-detail`) | 68.000–68.100 s |
| A: white flash onset | n4097 blurred/no bright white core →4098 core (`white-onset`) | 68.283–68.300 s; streak→flash **0.183–0.300 s** |
| B: first encircling body arc | n4993 absent →4994 present (`ring-onset`) | 83.216–83.234 s |
| B: blue flash onset | n5016 absent →5017 first blue (`blue-onset`) | 83.600–83.617 s; arc→blue **0.366–0.400 s** |
| B: blue envelope ends | n5025 pillars present →5028 absent (`burst2-impact`) | 83.750–83.800 s; blue visible envelope **0.133–0.200 s** |
| B: late large trailing rings end | n5082 present →5088 absent (`burst2-tail`) | 84.700–84.800 s; blue onset→late-ring disappearance **1.083–1.200 s** |

The short blue flash/pillar envelope and much longer trailing rings are separate visual layers, not a single0.8 s recovery. These timings revise the old “1–2 frames”/“~0.8 s after-slam” shorthand. Arcs can recur or change identity; their full sequence is not proven to be one emitter. Input-startup duration and total fall time cannot be inferred from these cue intervals.

## 3. Camera, speed and contact limits
- A shows strong blur and a changing view around68.283–68.4; B pivots sky→floor around83.4–83.6 and continues a top-down view. This is **visible camera/effect activity**, not isolated oscillatory shake amplitude/frequency. No camera-shake preset measured.
- No calibrated world coordinates, stable ruler, input trace or velocity telemetry: **fall speed, acceleration, dash range, height and momentum carry are unmeasured**. Dividing screen displacement by time would mix camera and body motion.
- VFX onset is not a ground sensor. A is ground-near; B is particularly unsafe as a touchdown marker. A landing refresh, recovery lock, fall-damage reset or input-cancel window is not demonstrated.

## → Implications for Robby / P-031 handoff (proposals, not implementation)
1. Preserve the owner's interest in 1–2 air dashes and a forceful descent, but choose original movement rules explicitly in P-031. Do not inherit charges, damage, stun, invulnerability or target dependence from this combat-context recording.
2. Separate the readable visual phases: body pose/directional streak → brief high-contrast burst → fading rings. The measured envelopes are **reference cue timings**, not ready-to-copy dash/slam physics constants or mandatory blue combat VFX.
3. For a later movement-only test, show unobstructed takeoff, first/second attempt, extra attempt, landing and retry with input/charge/grounded telemetry. Test refresh without landing too. For descent, record height/velocity and ground contact separately from effect spawn, plus post-contact movement input. This would resolve unknowns; this recording cannot.
4. R-031h still owns slide/chaining; P-031 must synthesize e/f/g/h before any further movement implementation. No code or tuning changed here.

## Unknowns and sources
Unknown: free-air dash count/refresh/distance, voluntary slam trigger, target-free availability, startup, world fall speed, exact collision, recovery, isolated shake and actual inputs. No mechanics guessed to fill AC's “numbers”; measured visible timings are supplied instead. Primary source only: owner recording + committed sheets and machine-readable brackets. Prior [R-031e](R-031e-movement-mechanics.md) supplies source-reliability context, not extra independent verification.
