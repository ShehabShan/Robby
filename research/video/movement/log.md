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

## R-031c — 1:00–1:30 (S144)
From ~0:59.5 the bar under HP is **on fire (orange flames)** for the whole chunk = a rage / awakened mode is active. 1:13.5–1:15 overlay "RELL Games … THANK YOU AGAIN, 1M MEMBERS" → the clip is a **RELL Games** game (makers of Rell Seas), fits the owner's "like Rell Seas" ask (D-434).

| Time | Move | Timing (est.) | Distance / direction (est.) | VFX / camera |
|---|---|---|---|---|
| 1:00.0–1:02 | run, mode active | — | normal run | flaming bar on HUD |
| 1:02.5 / 1:05.5 / 1:05.67 | **impact frames**: screen turns flat light-blue, character + enemy drawn black with a spiky black star | 1–2 frames (~0.03–0.05 s) each | — | classic anime "impact frame"; used on the heaviest hits only |
| 1:03.5–1:04.2 | run past pillar, dust at feet | — | — | footstep dust |
| 1:04.33–1:05.0 | **multi-dash flurry** | ~0.15 s per dash, 4–5 dashes in ~1 s | ~6–8 studs each, zig-zag around the enemy | white vertical "afterimage pillars" (ghost streaks) left at each stop, blue slash |
| 1:05.83–1:06.83 | more flurry dashes | same | same | white ghost pillars, sun flare |
| 1:07–1:07.5 | strafe | — | — | — |
| 1:08.0–1:08.5 | uppercut launch | — | enemy launched ~10 studs up | white vertical streak |
| 1:08.33–1:08.67 | landing slam | ~0.2 s | in place | big white flash, white ground rings (wind), dust |
| 1:09.0 | ground burst | 2 frames | in place | orange spark + white rings |
| 1:10–1:11 | red-cape lightning combo | ~4 hits | small steps | blue sparks, enemy red |
| 1:12.5 | **aerial spin**: camera zooms out, swirl rings in the sky | ~0.5 s | both in the air | big circular wind swirl around both |
| 1:15–1:19.5 | **air combo**: both float in the sky, player hits repeatedly | ~4 s hang time | — | sky background, sword streaks; gravity off during the combo |
| 1:20–1:21.5 | land, run, circle | — | — | dust ring on landing |
| 1:22.0–1:22.33 | black shadow-dash / teleport behind | ~0.2 s | ~10 studs | black ink smear |
| 1:22.5–1:23.0 | close-up camera on purple-orb heavy | — | — | camera cuts close behind the shoulder |
| 1:23.33–1:23.67 | spin dash in the air | ~0.3 s | — | white ring around body |
| 1:23.67 | ground slam | 1–2 frames | — | **blue light pillars** from the ground + white rings |
| 1:24.0–1:24.8 | after-slam | — | — | swirling white wind lines fade over ~0.8 s |
| 1:25.3–1:25.8 | jump/vault onto ledge | ~0.3 s | ~5 studs up | sun flare |
| 1:26–1:30 | run around pillars, one side dash at 1:29 | ~0.3 s | ~8 studs | white swirl ring, smoke |

### → Implications (chunk c)
- **Impact frames** (1–2 frame flat-colour flash with black silhouettes) only on finishers: a cheap screen effect that hits very hard. Good candidate for Robby's heavy/finisher hits.
- **Afterimage pillars** on rapid multi-dash = a "mode" skill, not the basic Q dash. Basic dash keeps the plain smoke puff.
- **Air combos** with long hang time exist in the reference game; out of scope for basic movement (combat task).
- Landing / slam = white ground ring + dust: reuse the same ring for landing from big jumps (Robby has landing recovery from T-058a).

## R-031d — 1:30–2:06 (S144)
Three clips: the end of the RELL combat clip, then two other games.

| Time | Move | Timing (est.) | Distance / direction (est.) | VFX / camera |
|---|---|---|---|---|
| 1:30–1:41.5 | combat clip ends: run, strafe, 2 hits (red flash 1:32, 1:37), side dash with smoke 1:39 | dash ~0.3 s | ~8 studs | flaming bar still on; smoke puff |
| 1:42.0 | **cut to a 2nd game** (bright cartoon style, grass, character in red cape) | — | — | no HUD bars |
| 1:42–1:45 | run on grass, enemy NPC passes | — | — | camera close behind |
| 1:45.5–2:00.5 | **long sprint up stone stairs** (10 fps checked 1:47–1:50) | steady pace, no slow-down on steps | ~20+ studs/s (unverified) | **white dust puff at every footstep** (~every 0.2–0.3 s, alternate feet) + thin white wind lines trailing the legs; body leans forward; camera low and close (~6–8 studs), slight roll on turns |
| 2:00.5 | **cut to a 3rd game**: ship deck, camera far out (~20+ studs), small hotbar HUD | — | — | — |
| 2:01–2:06 | walk/run across the deck, around the mast, down a ladder/stairs (2:04) | — | normal speed | no VFX; camera zoomed out, follows smoothly |

### → Implications (chunk d)
- **Sprint feel = footstep dust + wind lines + forward lean + low close camera.** Our sprint has FOV + lean (T-058b) but no footstep dust or wind lines: cheapest big win.
- Stairs do not slow the run; Robby should keep speed on stairs (check `Shared.Movement` has no slope slow-down on steps).
- Exploration camera (ship clip) sits far out; combat camera sits close. Two camera distances is a design choice for the owner.

## R-031 extra — 0:01–0:19 walk/run detail (S145, owner ask)
Sheets 4 fps (0:01–0:19) + 20 fps crop (0:10–0:11).
- **Run cycle:** ~3 steps/s (one footfall every ~0.3 s), strong arm swing, sword held low in the right hand, hip lantern glows; slight forward lean, body tilts into turns (0:02.5–0:03).
- **Camera:** behind and a little above (~8–10 studs), follows with a small lag: on turns the character drifts off-centre (0:02.75 near the right edge) then re-centres in ~0.5 s. Gentle sway, no hard bob.
- **Footstep dust:** small pale-grey puff at the back foot on each footfall (0:10.30, 0:10.40, 0:10.65), ~1 stud wide, lifts a little and fades in ~0.2–0.3 s. Not on every frame — only footfalls.
- **Speed lines:** thin white streaks across the air now and then (0:05.0, 0:09.5, 0:12.25, 0:16.75), ~1 per 3–4 s; not attached to the player.
- **Boulders / rubble passing:** mossy boulders, broken floor slabs and rubble line both sides of the path (0:01–0:03 big mossy boulder left, 0:04–0:06 dark rocks, 0:10.6–0:11 runs straight over a mossy rock with no slow-down). Close objects sweeping past the camera are what sells the speed (parallax), plus torches/pillars every ~15–20 studs.
- → Robby: footstep dust only on footfalls (~0.3 s cadence at sprint), rare ambient speed streaks while sprinting, camera follow-lag on turns; **map dressing** (boulders/rubble near paths, repeating pillars) is a level-design follow-up, not movement code.

## R-031 extra — 2:01–2:06 ship deck detail (S146, owner ask)
Sheets 6 fps (2:00.8–2:06.2) + 20 fps crop (2:03.4–2:04.9) + full frame 2:01.5.
- **Source:** full frame shows a YouTube player titled **"RELL Seas The Movie"** (player time 1:50:23 / 3:12:03), so this clip is **Rell Seas itself**, the game the owner wants to be like (D-434). HUD: compass strip at the top (SW · W), "Neutral" tag top right, "Progression" tab on the left, hotbar 1–5 bottom centre, thin HP (red) + stamina (blue) bar with an anchor ornament.
- **Camera:** far and high, ~15–20 studs behind and ~8–10 studs up, looking down ~30°, so the character is small on screen. Follows smoothly with no bob. When the player turns (2:04.9–2:05.8) the camera swings round gently over ~0.8 s. At 2:04.3–2:04.45 a beam comes **between camera and player and fills the screen for ~0.3 s**, so Rell Seas does not zoom the camera in to avoid walls here (or does so late). Robby's camera should pop in faster than this.
- **Run:** steady jog, slight forward lean, arms low; no footstep dust or speed lines (calm exploration). Turns are tight around the mast block (2:02.4–2:02.9), no slide.
- **Stairs:** 2:03.4–2:03.65 down a ~8-step ship stair in ~0.25 s with no slow-down or hop. Speed on stairs = flat speed (matches chunk d).
- → Robby: exploration needs a calm far camera (bigger distance than combat); stairs at full speed; camera should not let walls block the view for long (pop-in on occlusion). Fits T-058j (camera) / T-058k.
