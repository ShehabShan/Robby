# R-031e — Movement mechanics: video-backed redo (S150, 2026-11-04)

**Supersedes the certainty of S148's public-source pass**, at the owner's request. The old version remains in git (`2d85a5c`). Scope: movement research only; no fighting design, implementation, tuning or publication. R-031f–h still own detailed measurements; this audit does not close those tasks.

## Evidence and method
- Primary input: owner's re-upload `movement.mp4`, 79,162,802 bytes, H264 1920×1080 at 60 fps, container duration 126.058667 s. SHA256 `d71c24b6dab93c7ed138a8b44e355c7e8228f77438fd001350bb83af5d4cd541`.
- Download/provenance: [video README](../video/movement/README.md). Selected, visually inspected [proof sheets and frame manifest](../video/movement/R-031e/README.md) are committed so another missing upload does not erase the audit.
- Exact source-frame selection (`n`, zero-based); labels = `n/60`. These are recording timestamps, **not proof of simulation rate or real-time playback**. Coarse sheets locate evidence, not event start/end frames. No world ruler, input trace or charge telemetry. Do not convert screen pixels/body sizes into exact studs, acceleration, camera offsets or gravity.
- Keep separate: **V** = visible in this recording; **S** = a secondary website says it, not game verification; **U** = unresolved; **P** = possible Robby design, not reference behavior.

## What the video establishes
| ID | Recording evidence | Finding and limit |
|---|---|---|
| V1 | 20.000 s, frame 1200, `identity-proof.jpg` | HUD explicitly says **Q Dash, LSHIFT Walk, C Slide, E Strong, LCTRL Unlock**. This is not the S148 X-dash/Shift-run scheme. It shows labels, not the user's actual button presses, toggle/hold behavior or all game versions. At 72 s C reads Crouch: even the visible label is contextual. |
| V2 | 73.500 s, frame 4410, identity proof | RELL Games community overlay. It does not independently identify every source clip/game/version. |
| V3 | 121.500 s, frame 7290, identity proof | Player title reads **“RELL Seas The Movie 3”** over the ship segment. Reliable title evidence for this segment, not proof the entire edit is one build. Do not assert “three different games” from scenery changes alone. |
| V4 | 75.000–79.500 s, `air-context.jpg` | Two characters remain airborne amid sword trails/red flashes. This is combat-context footage, not an isolated free air-dash test. Neither “gravity disabled” nor ordinary traversal hang time follows from it. |
| V5 | 82.000–85.833 s, `air-end.jpg` | Rapid airborne repositioning, rings and a blue burst at 83.667 s. A burst alone does not establish player-ground contact or a voluntary movement slam. Treat prior log's 1:23.67 “ground slam” as a candidate, not a proven traversal move/trigger. |
| V6 | 123.250–123.633 and 125.000–125.367 s, `ship.jpg` | Low posture into descending stairs; later a rise to the upper deck with continued movement. A slide-like transition and upward traversal are visible; exact jump/slide input, multi-jump count and physics remain unproven. No dense smoke cloud is visible in these sampled transitions. |
| V7 | 124.367–124.500 s, ship sheet | Beam obscures the player/camera. Occluded frames cannot establish a hidden move, smooth trajectory or exact recovery. |
| V8 | `cuts.jpg`, `ship-cut.jpg`, identity proof | Forest→cape/stairs scene change is bracketed by 101.500/102.000 s; cape→ship by 120.750/121.500 s. Old log's 120.5 s cut is too early. These brackets are not exact edit-frame measurements. |

## Audit of every S148 mechanics group
| Prior claim | Disposition after video/source check |
|---|---|
| LSHIFT toggles run; X dash | **S, not valid as recording-wide fact.** [Controls](https://rellseaswiki.com/controls/) does say this, but V1 disagrees. Possible build/remapping/context difference; do not silently reconcile it. Use V1 when describing this recording. |
| C while running + Space slide-jump | **Mixed V/S.** C Slide label is visible; hold requirement and Space chain are secondary-source claims ([parkour](https://rellseaswiki.com/fighting-styles/parkour/)). V6 does not prove the exact key sequence. |
| Space twice = double jump | **S/U.** Controls page says it; a single rise or elevated camera does not verify two distinct take-offs. |
| Geppo 3 jumps, 5 with upgrade, camera-directed | **S/U.** [Mechanics](https://rellseaswiki.com/fighting-styles/combat-mechanics/) says 3 camera-directed jumps; [Geppo Master](https://rellseaswiki.com/fighting-styles/geppo-master/) describes an Agile poster raising 3→5. This recording does not verify these rules; **air jumps are not air-dash charges**. |
| Wall run: jump near wall, A/D | **S/U.** Parkour page describes it; selected owner footage does not establish wall-run controls/duration. Not a mandatory Robby feature because a website lists it. |
| Dash on ground/in air/on ships; side-only i-frames | **S/U.** Directional burst visuals do not prove invulnerability, cooldown grouping, eligibility or damage avoidance. Ship jog footage does not establish ship dash behavior. |
| Air dash extends/repositions; no published limit | **U.** Weak [guide](https://rellseasgame.wiki/guide/rell-seas-guide) is not sufficient. “No verified limit found” ≠ unlimited air dashes. Video cannot establish the maximum or recharge conditions. |
| Backward airborne attack = Down Slam/block breaker | **S, combat context; not a movement specification.** Mechanics page really says this. V5 does not prove its trigger or a target-free traversal equivalent. Keep combat mechanics out of this movement-only assignment. |
| Agile posters/Flash Dash alter movement | **S/U.** [Agile posters](https://rellseaswiki.com/posters/agile-posters/), [Flash Dash](https://rellseaswiki.com/fighting-styles/flash-dash/) were S148 leads; not corroborated by this recording. No upgrade behavior is adopted. |
| Slide speed/length/stamina numbers “not published” | Replace with **not verified here**. Failure to find a value is not proof no published value exists. |
| Deepwoken slide→jump→downward air dash→roll; fall cancel | **Secondary comparison only.** Direct [Movement wiki](https://deepwoken.fandom.com/wiki/Movement) fetch returned HTTP 403. Search summary describes conditional fall mitigation (below 15% max health, otherwise partial reduction), not unconditional immunity. “Roughly 37°” is a player technique, not an engine constant. Owner's clip does not validate Deepwoken. |
| Jujutsu Shenanigans/Strongest Battlegrounds ~25-stud forward dash, landing roll | **Withdraw as shared benchmark.** S148 mixed two games and generalized their rules. Not checked in the owner's video; requires independent per-game evidence before use. |
| Fluid movement = custom acceleration, LinearVelocity, lerped facing | **P, not a discovery of reference implementation.** A smooth image cannot reveal the underlying controller/constraint. DevForum implementation ideas remain options, not proof of how Rell Seas works. |
| `Players.UseStrafingAnimation = true` | **Corrected.** Official Roblox API is **`Players.UseStrafingAnimations`** (plural). It defaults false and **cannot be assigned through developer-facing Luau**; docs describe a Studio property. [Official class source](https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/Players.yaml). No runtime assignment or untracked Studio workaround is approved for Robby's headless/Rojo workflow. |
| Freefall/Landed events implement a slam | **P only.** State transitions alone do not distinguish a voluntary slam from a normal fall, prove safe collision handling, or establish server authority. No implementation selected. |

## Source reliability
Direct fetches on 2026-11-04 confirmed that the four rellseaswiki.com pages above actually contain the cited claims. Its footer explicitly says **“Fan-made wiki, not affiliated with RELL Games.”** The mechanics page also mixes E Strong tutorial text with Q Spec terminology. Treat it as a research lead rather than authority over the owner recording. Search-generated answers merely repeating these pages are not independent corroboration. Short source-check receipts are in the evidence directory; whole third-party pages are not committed.

## → Implications for Robby (research handoff, not new approval)
- Correct S148's blanket “missing vs benchmark” to **candidate capabilities for P-031**: air jumps, air dash, traversal slam, wall run and landing roll are not all demonstrated requirements. Preserve the owner's specific movement interests without inventing implementation rules.
- D-444's 1–2 dashes refreshed on landing remains a **design proposal**, not a proven Deepwoken/Rell Seas rule. In particular, do not replace the owner's 1–2 air dashes with the wiki's 3/5 air jumps.
- Robby source baseline inspected: `src/shared/Config.luau` Movement jog18, sprint24→27, accel120/decel160, slide start30 for0.6s; Dash side10studs/0.2s, forward/back12/0.22s. These are **our configured values**, not measured reference values. No tuning changed and no completeness claim about all movement code is made.
- Borrow a readable low-posture transition, upward motion followed by continued travel, and uncluttered exploration presentation as visual targets (V6). Do not copy enemy effects, declare fixed timings, or infer charge resets from them.
- R-031f: strafe/jump measurements with uncertainty (S149 owns this). R-031g: mark take-off, candidate air bursts, **visible** ground contact and target presence; if a repeatable charge limit/refresh or target-free slam is not shown, explicitly leave it unknown. R-031h: distinguish visible adjacency from a proven input-cancel window or momentum carry. Then P-031 chooses original rules and test criteria.

## Unknowns
Actual held inputs; source-build identity for the forest/cape clips; exact world-space speed/height; eligible directions; airborne charge count/refresh; stamina/cooldowns; invulnerability; fall damage; isolated traversal-slam trigger and landing recovery; supported transitions/cancel windows. More frames can refine visible timings but cannot recover absent input/physics telemetry.
