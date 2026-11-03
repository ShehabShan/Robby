# R-029 Movement research (S140, 2026-11-03)

Goal: inputs for T-058 (own Robby movement system, replaces the R15 kit). Public sources only; no code/assets copied (D-023).
Facts carry a source tag [n] (list at the bottom). Anything from model memory is marked (unverified).

## 1. Feature table per game

| Feature | Deepwoken | Rell Seas | Project Slayers 2 |
|---|---|---|---|
| Sprint input | double-tap W (or Alt), toggle [1][3] | (not found) | hold Left Shift while moving forward [7][8] |
| Sprint feel | builds momentum over ~3 s to ~1.15x normal run speed [1] | (not found) | no stamina drain while sprinting [7] |
| Stamina | taking damage + low stamina slow you [1][2] | evade bar fills as you take damage [4] | stamina "diamond" limits wall climb [7] |
| Dodge / dash | Q roll with i-frames; M2 roll-cancel skips end-lag, repeated cancel adds 0.5 s cd [11][2] | X dash; left/right dash = i-frames, forward/back = positioning only [4][5][6] | Q dash in move direction [7] |
| Slide | hold Ctrl while running; jump in slide = slide-jump ~37° up keeping momentum; mini-slide on landing [1] | (not found) | (not found) |
| Vault | Space near obstacle = quick vault + speed boost [1] | (not found) | (not found) |
| Wall jump / climb | 2 wall jumps then climb; climb when facing wall; ledge hang by jumping under edge [1] | (not found) | Ctrl at wall = climb, stamina-limited; mobile double-tap wall [7][9] |
| Mobile | (not checked) | (not checked) | on-screen sprint + dash buttons [9] |

Takeaways: all three keep default-like base speed and add feel through **momentum ramps, a directional dodge with i-frames, and
traversal moves (slide/vault/climb)**. Rell Seas ties i-frames to sideways dashes only, which rewards reading the attack.

## 2. Roblox technique findings

- **Accel/decel:** fork `PlayerModule` ControlModule and lerp a speed ratio, or steer `AssemblyLinearVelocity` toward a
  target vector, horizontal only [12][13]. Alternative: `ControllerManager` + `GroundController` (`BaseMoveSpeed ×
  MoveSpeedFactor`, `BaseTurnSpeed × TurnSpeedFactor`, `AccelerationTime`) [14][15]; known issue: non-zero
  `AccelerationTime` makes turns sluggish and ignores Friction [16].
- **Lean:** LocalScript updates `RootJoint.Transform` from root-relative velocity on Heartbeat (smoothed) [17][18].
- **Foot sync:** `AnimationTrack:AdjustSpeed(speed / authoredSpeed)` (default Animate uses speed/16), driven by
  actual velocity on Heartbeat, call after Play [19][20].
- **Camera:** sprint FOV via tween, bob/shake via `Humanoid.CameraOffset` (sine or noise); give a toggle for motion
  comfort; sprint only when `MoveDirection · LookVector` > 0 [22][23].
- **Ledge/vault detect:** two forward rays (root + head height): root hits, head misses = ledge/vaultable [24][25].
- **Same feel on every avatar:** Avatar Settings "Consistent Gameplay" preset forces one height + single box collider;
  `HumanoidDescription.UseAvatarSettings = true` respects it [26][27].
- **Server speed guard:** compare `(pos - lastPos).Magnitude / dt` with a margin above max speed; sample every ~10th
  Heartbeat or accumulate strikes; respond by snapping back; ping compensation is unreliable [28][29][30].
- **Game-feel numbers:** time-to-max-speed 50–200 ms for responsive 3rd-person action; separate accel and brake;
  higher "turn-decel" when input opposes velocity; audit with timeToMax = v/a, stopDist = v²/(2·decel) [31][32].

## 3. Recommended targets for T-058 (`Config.Movement`)

Current config: `Movement = { walk = 16, sprint = 24, accel = 40 }`.

| Key | Target | Why |
|---|---|---|
| walk | 16 | Roblox default, matches authored anim speed [19] |
| jog (default move) | 18 | small step up, keeps base feel |
| sprint | 24 → ramp to 27 over 3 s | Deepwoken-style momentum (1.15x) [1] |
| accel | 120 studs/s² (0→18 in 0.15 s) | inside 50–200 ms band [31] |
| decel (brake) | 160 studs/s² (stop dist ≈1.0 stud at 18) | crisp stop; small stop slide only from sprint |
| turnDecel (input ≥ 120° from velocity) | 240 studs/s² | no ice-skating on reversals [32] |
| turnRate | 720°/s jog, 420°/s sprint | heavier turns at speed (unverified feel target) |
| stamina | 100 max; sprint −12/s; regen +20/s after 0.8 s | gate sprint/dodge (unverified numbers, tune in playtest) |
| dodge | 0.35 s, i-frames 0.08–0.28 s, cd 0.9 s, −20 stamina; sideways only i-frames | Rell Seas rule [4][6], Deepwoken cancel [11] |
| slide | from sprint ≥ 22, 0.6 s, start 30 → decay to jog; jump-out keeps speed | Deepwoken slide/slide-jump [1] |
| vault | obstacle 2–4.5 studs high, ≤3 studs ahead, double ray | [24][25] |
| lean | max 8° roll, smoothing 10/s, from root-relative accel | [17] |
| anim | walk/jog/run blended by speed; `AdjustSpeed(v / authored)` | [19] |
| camera | sprint FOV 70 → 78, tween 0.25 s; bob off by default | comfort [22] |
| guard | allow max(sprint ramp, slide, dodge) × 1.25 + 4 studs/s; 3 strikes in 2 s then snap back | [28][29] |
| avatar | Consistent Gameplay preset (R15, fixed body scale) | owner OK 2026-11-03 [26] |

Controller choice (decision D-426): keep the Humanoid but drive speed ourselves (pure `Shared.Movement` step function:
input + state + dt → target velocity, stamina, flags), applied on the client via Humanoid `WalkSpeed`/`Move` or
velocity steering; avoid `GroundController.AccelerationTime` because of the turn-sluggishness bug [16]. Server keeps the
authoritative guard + stamina for dodge i-frames.

Suggested T-058 split: T-058a remove R15 kit + `Config.Movement` + pure momentum/stamina module + specs;
T-058b client wiring (speed, turn, lean, FOV) + server guard retune; T-058c own animations + foot sync;
T-058d dodge; T-058e slide; T-058f vault/ledge; T-058g jump/land recovery.

## Unknowns
- Rell Seas and PS2 ground-speed numbers and accel feel (no public data; needs own play notes).
- Deepwoken stamina costs (not documented [11]).
- Final animation assets for jog/run (owner art lane or generated).

## Sources
[1] https://deepwoken.fandom.com/wiki/Movement [2] https://en.namu.wiki/w/Deepwoken [3] https://deepwoken.fandom.com/wiki/Controls
[4] https://rellseaswiki.com/fighting-styles/combat-mechanics/ [5] https://rellseaswiki.com/fighting-styles/ [6] https://rellseaswiki.com/fighting-styles/flash-dash/
[7] https://progameguides.com/roblox/all-controls-in-project-slayers/ [8] https://tryhardguides.com/project-slayers-controls-list/ [9] https://progameguides.com/roblox/project-slayers-mobile-controls-guide/
[11] https://deepwoken.fandom.com/wiki/Combat_Mechanics
[12] https://devforum.roblox.com/t/creating-heavy-character-movement-beginner-tutorial-acceleration-and-deceleration/3157702 [13] https://devforum.roblox.com/t/custom-character-controller-slippery/4685495
[14] https://create.roblox.com/docs/reference/engine/classes/ControllerManager [15] https://create.roblox.com/docs/reference/engine/classes/GroundController [16] https://devforum.roblox.com/t/groundcontrollers-accelerationtime-does-not-respect-friction-and-frictionweight/3673859
[17] https://devforum.roblox.com/t/updated-open-source-r15r6-character-momentumleaning/943544 [18] https://devforum.roblox.com/t/smoothweighted-character-turningmovement/3139514
[19] https://devforum.roblox.com/t/animation-speed-changes-according-to-humanoid-walkspeed/847421 [20] https://devforum.roblox.com/t/help-with-blending-running-and-walking-animations/2484698
[22] https://devforum.roblox.com/t/creating-a-simple-realistic-camera-with-view-bobbing-dynamic-blur-sprinting/646943 [23] https://devforum.roblox.com/t/feedback-on-camera-bobbing-and-sprinting-system/2744607
[24] https://devforum.roblox.com/t/how-can-i-detect-where-a-parts-ledge-is/2914055 [25] https://devforum.roblox.com/t/open-sourced-vaulting-system-really-simply-made/2915804
[26] https://create.roblox.com/docs/studio/avatar-settings [27] https://devforum.roblox.com/t/applydescription-x-avatar-scale-settings/4809711
[28] https://devforum.roblox.com/t/a-guide-to-making-proper-anti-exploits/1606949 [29] https://devforum.roblox.com/t/making-a-good-speed-hack-detector/2026856 [30] https://devforum.roblox.com/t/how-to-check-ping-and-use-it-for-walkspeed-anti-exploit/101752
[31] https://www.gamedeveloper.com/design/game-feel-tips-ii-speed-gravity-friction [32] https://gamedevaitools.com/concepts/acceleration-and-friction/
