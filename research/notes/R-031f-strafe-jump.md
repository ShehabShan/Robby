# R-031f — Sideways movement and upward traversal (S151, 2026-11-04)

Movement-only research; recovered S149's source-pointer commit, then measured the owner's re-upload. No gameplay/tuning/publishing. [Evidence and reproduction](../video/movement/R-031f/README.md), [S150 audit](R-031e-movement-mechanics.md). The ship segment is titled RELL Seas The Movie 3 in S150's identity proof; do not extend that build identification to every montage scene.

## Method and confidence
- Video SHA256 `d71c24b6dab93c7ed138a8b44e355c7e8228f77438fd001350bb83af5d4cd541`; 79,162,802 bytes; 1920×1080; 7,561 container frames at 60/1. `n/60` is **recording time**, not input time or verified real-time simulation.
- Inspected 11 sheets, including consecutive frames at jump boundaries. `manifest.json` records indices/crops/hashes; unannotated source pixels only resized/cropped, with labels added outside each tile.
- Ship frames 7497/7498 and 7527/7528 are identical in the measured crop; several other pairs differ by <0.14/255 mean channel value while intervening changes are ~15–33/255. See CSV. Selected ship footage provides about 30 distinct images/s, despite the 60 fps container. This does **not** prove the game's FPS, explain duplication, or establish the cadence of the whole edit.
- Visible-event brackets below are deliberately wider than a single frame. Timing uncertainty includes pose/occlusion ambiguity, not merely sampling. No motion-capture, ground-plane reconstruction, camera calibration or input overlay exists.

## Sideways movement: what actually reads smoothly
| Evidence | Observation | What cannot be inferred |
|---|---|---|
| `strafe-b`, n2694–2892 (44.90–48.20 s) | Character steps across the scene while generally facing the other character; ground/pillars move laterally and camera heading changes. | Pure sideways world velocity, constant radius, active lock-on algorithm, held A/D or Shift. |
| `strafe-detail`, n2748–2880 (45.80–48.00 s) | Feet cycle and torso remains oriented toward the scene's subject instead of visibly turning all the way around with every side step. Sparse foot puffs; no need for a dash cloud to read ordinary locomotion. | Dedicated left/right animation assets or blend weights; walking versus running speed. |
| `strafe-change`, n2772–2784 (46.20–46.40 s) | Body/leg silhouette transitions through a more square pose to the other oblique pose across a 0.20 s observation window. | Input-to-response latency, exact reversal duration or a tunable 0.20 s acceleration constant. Camera rotation contributes to the apparent change. |
| `strafe-a`, n1308–1440 (21.80–24.00 s) | Airborne-looking poses, wind burst, tumble/inversion, strong camera pitch changes. | Old log's 22.0–22.8 s “slow sideways walk” is not a clean strafe sample. |

**Borrowable visual target, not a controller discovery:** keep facing, foot placement and camera framing coherent during lateral travel. P-031 should compare camera-facing strafe and free-turn locomotion separately; target-facing behavior is not required to reproduce all sideways motion. A still image or drifting pillar cannot prove ease-in/out, no foot sliding, interpolation or “zero inertia.”

## Upward traversal: ship, not an isolated ballistic jump
| Event | Frame/time bracket | Reading |
|---|---|---|
| Lower-deck low pose → clear lift | n7494–7497, 124.900–124.950 s | n7495–7496 unfolds; n7497 has clear separation. Treat launch onset as a bracket, not a proven one-frame crouch. |
| Rising streaks | n7499–7514, 124.983–125.233 s sampled | Narrow black/white lines, small pale puffs below; no dense smoke cloud in these samples. Last/first effect frames not exhaustively established. |
| Feet reach edge height → pass edge | n7523–7527, 125.383–125.450 s | Feet overlap the top/front board, then character is visibly over the upper deck. This is **edge passage**, not a verified touchdown or apex. |
| Rise to edge passage | Interval arithmetic on brackets above: **0.433–0.550 s** | Recording-time traversal interval; not total jump duration, reaction time or a ballistic time-to-apex. |
| Upper-deck continuation | n7527–7560, 125.450–126.000 s | Continued travel, with airborne-looking feet/shadow separation in detail. No unambiguous settled landing isolated before the clip ends. |

The camera pitches upward during the rise and then changes heading/pitch around the upper deck, keeping the player broadly near the middle. That makes vertical screen displacement a poor height proxy. The beam occlusion around 124.4 s is earlier than takeoff; do not interpret it as a jump cancel or hidden charge refresh. Neither exact FOV, camera distance, follow lag nor a smoothing constant can be extracted here.

**Height in studs: not identifiable from this footage.** The old 5–6-stud estimate used assumed body scale with moving perspective; it is not a measurement and must not become `JumpHeight`. No known reference avatar size, deck dimensions or world-position telemetry fixes the scale. A jump, extra airborne boost, ledge assistance and animation/root offsets cannot be separated confidently. Do not solve `h=g*t²/2` from edge time: the endpoint is not an apex and reference gravity/launch model are unknown. Keep the numerical field **unknown**, not zero or an invented range.

The forest `jump-context` sheet (23.9–26.1 s) already starts in an airborne interaction with effects and other characters. It does not supply a cleaner normal-jump measurement. This study does not research fighting, invulnerability or damage.

## Comparison to Robby's source (baseline, not a live playtest)
| Item | Repository value/behavior | Consequence for P-031 |
|---|---|---|
| Horizontal speeds | `Config.Movement`: walk16, jog18, sprint24→27 over3 s (studs/s). `SprintClient` passes `walk=false`. | Walk16 is a configured value, not proof an ordinary walk input is wired. No calibrated reference speed to subtract from ours. |
| Scalar speed response | accel120, decel160, sharp-turn brake240 studs/s²; sharp turn threshold120°. | Ideal 0→18 =0.150 s, 18→0 release=0.1125 s; 18→0 reversal brake=0.075 s, then rebuilding to18 takes0.150 s. Derived scalar-model examples, not end-to-end latency or guaranteed Humanoid motion. |
| Turning | turnRateJog720 / turnRateSprint420 deg/s; `Movement.turnRate` helper has no caller in `src` at this revision. | Do not claim these values already smooth the live facing. `ShiftLockClient` writes camera yaw directly each render while locked; it is not target lock-on. |
| Facing | LCtrl toggles shift lock, `AutoRotate=false` while locked; unlocked restores true. | Test lateral travel with locked camera yaw independently from a target-follow camera. Reference image does not establish which implementation to copy. |
| Basic jump | No `JumpPower`, `JumpHeight`, `UseJumpPower` override found in `src` or `default.project.json`; no basic jump setting in `Config.Movement`. | Record actual spawned Humanoid jump mode/value and Workspace gravity in a later authorized test; do not pretend defaults are a measured live baseline. |
| Ledge traversal | `Config.Vault` reach3, low obstacle1.8–4.5, climbMax7, gravity196.2; `VaultClient` probes on grounded moving JumpRequest and sets launch velocity. | These are our obstacle/launch parameters, not reference height or proof the ship uses the same mechanism. |
| Landing | fall-speed threshold40; recovery0.1+(fallSpeed−40)×0.006 capped0.45 s, speed cap walk×0.5=8. | Video lacks settled contact/fall velocity; cannot justify removing recovery or claim “no landing slowdown.” |
| Camera | `MovementCamera`: FOV70→78 over0.25 s on sprint state changes. | These are Robby settings, not reference camera measurements. Compare matched camera framing before changing jump physics. |

Sources: [Config](../../src/shared/Config.luau), [Movement](../../src/shared/Movement.luau), [SprintClient](../../src/client/SprintClient.luau), [ShiftLockClient](../../src/client/ShiftLockClient.luau), [VaultClient](../../src/client/VaultClient.luau); no source modified.

## Official API check and secondary research
Direct official [Humanoid YAML](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Humanoid.yaml) documents JumpPower default50, JumpHeight default7.2, and UseJumpPower defaulttrue (from StarterPlayer). **The two jump settings are alternatives**, not two simultaneous heights. [Workspace YAML](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Workspace.yaml) documents default gravity196.2 studs/s². These engine defaults do not establish either game's live settings. AutoRotate describes automatic movement-facing rotation; disabling it allows independent facing, so “Roblox has no strafing” is not a valid conclusion.

Three `search.sh` queries covered jump API/defaults, RELL Seas Movie3 movement, and AutoRotate. Results included fan wikis and generated video summaries; they were not treated as independent confirmation of inputs, jump count or height. Only direct official API text supports API statements; primary measurements come from the owner video. No model-memory mechanics adopted.

## → Implications for Robby / planning handoff
- Preserve restrained streaks and a clearly readable upward transition; keep ordinary sideways stepping distinct from burst movement. This is a presentation target, not a new build approval.
- P-031 should specify separate tests: fixed-camera left/right/back/diagonal starts and reversals; camera orbit while strafing; neutral grounded jump; assisted ledge traversal; landing continuation. Keep inputs, world positions and camera settings logged in those future tests.
- For an original Robby test course, **proposed ruler heights** 4/6/8 studs can compare basic jump versus assisted traversal. These are experiment fixtures only, not reference estimates or approved tuning. Include 30/60 fps, desktop/controller/touch and collision-occlusion checks when planning.
- R-031g/h still own air-burst/refresh/slam and slide/chaining. Do not infer a second jump or a free dash count from this ascent. P-031 follows all research; no building or publication here.

## Unknowns and corrections
Reference studs, gravity, jump type/count, keys, input latency, full arc/apex/touchdown, recovery, exact camera controller and per-axis acceleration remain unknown. Supersedes old log's clean22 s strafe, 24 s isolated high-jump, 5–6-stud ship rise, one-frame crouch and confirmed125.35 s landing/no-slowdown assertions. Honest non-identifiability closes the measurement question; more processing of the same uncalibrated pixels cannot supply a world ruler.
