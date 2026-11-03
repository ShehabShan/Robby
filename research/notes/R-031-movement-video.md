# R-031 — Owner movement video (`movement.mp4`, 2:06) — summary (S143–S144)
Full timeline: `research/video/movement/log.md`. All numbers are image estimates (no ruler), marked unverified.

## Findings (source: owner video, frame sheets 2/6/10/30 fps)
- 0:00–0:19 cinematic run; 0:19.7–1:41 combat clip from a **RELL Games** game (overlay "THANK YOU AGAIN, 1M MEMBERS", 1:13.5); 1:42–2:00 sprint in a second cartoon game; 2:00.5–2:06 walking on a ship in a third game.
- Combat keybinds: Q Dash, C Slide, LShift = walk (run is default), LCtrl unlocks camera (**lock-on is default**), M1/M2/E.
- **Dodges:** ~0.25–0.4 s each; side ~8–12 studs, back-step shorter ~6 studs, forward ~10 studs. Smoke/dust ring at start, puff at end, white crescent wind arcs around the body. Dodge chains **straight into M1** (no visible recovery). Flurry "mode" dashes are faster (~0.15 s, afterimage pillars) but are a skill, not the basic dash.
- **Hit feel:** 1–2 frame impact frames (flat light-blue screen, black silhouettes, spiky star) on finishers; gold flash + ground ring on a counter (0:36); "BROKEN" text + pink burst on posture break; rage mode = flaming HUD bar.
- **Run/sprint feel:** dust puff each footstep, white wind lines at the legs, forward lean, low close camera, gentle camera roll on turns; no slow-down on stairs.

## → Implications for Robby (vs `Config.Dash` side 10 studs/0.2 s, i-frames 0.04–0.18 s, cd 1.5; fwd/back 12/0.22 s, cd 3)
1. Distances match. Durations look longer (~0.3 s). Proposal: side 10 studs/**0.28 s**, back-step **8 studs**/0.28 s; keep i-frames ~70 % of the dash. **Owner feel-test first** — our 0.2 s may already feel right in-game.
2. Allow M1 during the dash's last part (dodge → hit). Keep the 0.15 s dash→dash block.
3. Dash VFX: dust ring at start, smoke puff at end, wind arcs on side dodge (fits Wind Kith).
4. Sprint VFX: footstep dust puffs + leg wind lines.
5. Bigger later items: combat lock-on camera (LCtrl toggle), impact frames on finishers, perfect-parry gold flash.

## Unknowns
Exact studs/i-frames (no hit tests visible); names of the 2nd/3rd games; whether the owner wants Shift = walk (reference) or Shift = sprint (ours).
