# R-031 movement video log (owner's `movement.mp4`, 2:06, 1080p60)

Method (D-438): ffmpeg contact sheets with drawn timestamps: 2 fps overview, 6 fps on action, 30 fps on fast moves.
Frames live in `research/video/movement/<chunk>/` (gitignored). All times = video time. Studs, frames and i-frames
are **estimates from the image (unverified)**: no in-game ruler, and the camera moves. Character ≈ 5 studs tall is the scale.

## R-031a — 0:00–0:30 (S143)

### 0:00–0:19.6 cinematic run (no HUD)
- Third-person camera behind and above (~10–12 studs back, ~20° down). Camera sways gently, rolls a little into turns; character leans into turns.
- Steady run, no walk/run blend visible. Est. pace ~20–24 studs/s (unverified), close to Robby's jog 18 / sprint 24.
- **Footstep VFX:** small white dust/sparkle puffs at the feet every few steps (0:03.5, 0:07.5, 0:10–0:13). Cheap, reads well on dark stone.
- 0:16–0:19.5 slow run into a big sun flare: lighting / bloom shot, not movement.

### 0:19.67 cut to combat gameplay (reference game with HUD)
- **Keybinds on screen:** M1 Attack, M2 Defend, E Strong, **C Slide, Q Dash**, LCTRL Unlock (camera lock-on is ON by default), **LSHIFT Walk** (run is the default speed), R Assassin Frenzy, Shadow Strike.
- HUD: red HP bar + blue bar (posture/energy), hotbar 1–5, small status icons above the hotbar.

### Moves logged
| Time | Move | Timing (est.) | Distance / direction (est.) | VFX / camera |
|---|---|---|---|---|
| 0:19.67 | slash into dash | slash 1 frame-burst | — | purple blade streak |
| 0:20.00–0:20.25 | side dodge (locked-on) | active ~0.25 s, no clear startup | ~8–10 studs sideways | 2–3 white crescent wind arcs circling the body, they fade over ~0.3 s |
| 0:20.23–0:20.77 | M1 combo right after the dodge | dodge → attack chain with no visible recovery | small forward steps per hit | white sword streaks, camera stays locked |
| 0:22.0–0:22.8 | strafe while locked-on | — | slow sideways walk, faces target | — |
| 0:23.17–0:23.67 | side dash with flip | ~0.3–0.5 s total; dust ring at start (23.17), airborne flip (23.33), smoke puff at end | ~10–12 studs sideways | ground dust ring + grey smoke puffs at start/end |
| 0:24.17–0:24.5 | high jump / launch | up ~0.3 s | ~10+ studs up (camera tilts to sky) | camera looks up, no trail |
| 0:25.47–0:25.53 | edit flash (white screen, 2–3 frames) | — | — | video edit, not gameplay |
| 0:25.57–0:26.0 | wind burst / special around the player | burst 1 frame, rings stay ~0.4 s | in place | bright white flash + 4–6 swirling white rings + orange sparks |
| 0:26.67–0:28.3 | lightning combo on enemy | ~5 hits | small steps | enemy flashes red on hit; blue lightning slashes |
| 0:28.5–0:28.8 | guard/posture break | — | — | pink burst + "BROKEN" text over enemy |
| 0:29.5 | dash | — | — | white swirl ring |

### → Implications for Robby (draft, final after R-031d)
- Dash timing: reference dodges look **~0.25–0.35 s**, longer than our 0.2 s side dash, with a ~10-stud reach that matches ours. Re-check on chunks b–d before changing `Config.Dash`.
- Dash chains straight into M1 with no visible recovery; our 0.15 s chain block (D-435) blocks dash→dash only, which looks right.
- VFX to borrow: white wind arcs around the body on side dodge (fits Wind Kith), ground dust ring at dash start, smoke puff at the end, footstep dust puffs on the run.
- Camera lock-on is default in combat (LCTRL unlocks); Robby has no lock-on yet → candidate task after R-031d.
- Default speed = run, Shift = walk (ours: jog default, Shift sprint). Owner to judge which feels better.

### Unknowns
- Exact studs and i-frames (no hit tests visible in this chunk). Which game it is (HUD looks like a battlegrounds/samurai game).

## R-031b — 0:30–1:00 (S144)
Same combat clip (HUD keybinds as chunk a). Second ability set appears from ~0:39 (bottom-right: "Giant Swing" style + "Mirage Strike"; names = reference game, not for Robby).

| Time | Move | Timing (est.) | Distance / direction (est.) | VFX / camera |
|---|---|---|---|---|
| 0:30.0–0:30.5 | dash out of smoke | ~0.3 s | ~8 studs back/side | grey smoke cloud at start, yellow sparks |
| 0:31–0:32.5 | run toward camera / sun | — | normal run | lens flare shot |
| 0:33.0 | dash forward (blur) | ~0.2 s | ~10 studs forward | motion blur + white streak |
| 0:33.67 → 0:34.67 | hit enemy (red flash) → **side dodge** → black/red hit burst | dodge ~0.3 s; then attack in ~0.2 s | ~6–8 studs sideways, ends next to the enemy | white circular wind arcs around body (0:34.17–0:34.33), black ink burst + red on hit |
| 0:34.83–0:35.83 | backward dodge / reposition | ~0.4 s with grey smoke | ~6 studs back | ground smoke ring, arcs stay ~0.5 s |
| 0:36.0–0:36.5 | power-up / counter | burst 2–3 frames, glow ~0.5 s | in place | huge gold flash, gold ground ring, light rays |
| 0:37.0–0:38.3 | run + turn | — | — | blue-white spiral by enemy |
| 0:38.3–0:38.5 | slide-dodge low | ~0.3 s | ~8 studs | low pose, white streak |
| 0:39.0–0:40.5 | lightning dash-strike | ~0.5 s | ~10–15 studs, passes through/along enemy | blue lightning trail on the ground, enemy red flash |
| 0:41.0 | purple strike | 1–2 frames | — | purple ground glow + purple slash |
| 0:41.17–0:42.0 | dash away (back-step) | ~0.4 s | ~10 studs, camera stays locked on target | grey smoke trail |
| 0:42.5–0:43.5 | side dash past a pillar | ~0.35 s | ~10–12 studs | green/grey smoke |
| 0:43.5–0:44.5 | wide sword swings while circling | — | — | white sword arcs |
| 0:45.0–0:48.0 | strafe circle around target with purple orb buff | — | slow sideways walk (Shift?), always facing target | purple orb on chest; small dust puffs |
| 0:49.0 | jump-slash | ~0.3 s air | ~5 studs up | streak |
| 0:50–0:53 | sprint/run, camera swings around | — | ~20+ studs/s | — |
| 0:53.5–0:59.5 | run toward sun (lighting shot) | — | — | flare; 0:59.5 HUD bar flashes orange (status) |

### → Implications (chunk b)
- Confirms chunk a: dodges ~0.3–0.4 s, 6–12 studs; **back-step is shorter (~6 studs) than side dash**; every dodge leaves a smoke puff at the start.
- **Dodge → attack instantly** is the core loop: dodge to the side of the attacker and hit them (0:34). Supports keeping dash recovery short (0.15 s) and allowing M1 during dash recovery.
- Lock-on camera keeps the target centred while dashing away; strafing circles look smooth because the body faces the target.
- Gold "counter" flash at 0:36 = a parry/counter reward. Robby has F = Parry: borrow a big gold flash + ground ring for a perfect parry.
