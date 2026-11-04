# Owner jump test — saved v51, 2026-11-04 (S157)
Owner verdict: "I think it's okay for now." Raw F8 trace: `2026-11-04-owner-jump-trace-v51.txt` (492 rows, 8.18 s).
Bot read (quick, not full analysis):
- 5 jump presses, 1 Q press. Modes seen: only Ground (347) and Air (145). **No Dash/Slide/Land rows even though Q was pressed and hspeed peaked 52.16** → MoveMode attribute likely not following SprintClient dash/slide (check MoveClient mode sync first in T-059d1).
- Peak vy 50.7 (expected ≈53.1 for JumpHeight 7.2, g 196.2 → ok within sampling).
- Summary label `maxH` = max horizontal speed, not height; rename in MoveTrace when touched.
