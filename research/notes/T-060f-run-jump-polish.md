# T-060f — Run/jump polish vs owner video (S158)

Source: owner upload `run-and-jump.mov` (4.94 s, 1920x1078 @ 60 fps, sha256 7bd6e780566f…), studied as a 4 fps contact
sheet only (no assets copied). Owner verdict: ours is already good — polish only.

## Observations (from stills)
- 0.0–2.75 s: steady run over a wooden pier; strong forward lean, camera low and close behind, slight right offset.
- ~3.25 s: jump off the pier edge onto sand; short white speed streaks at take-off.
- ~3.75 s: small dust puff kicked up at the feet while running on sand.
- ~4.0 s: low crouched landing pose (knees bent, body dips) before running on.
- ~4.5 s: large sand-coloured dust burst on a hard landing, covering the lower half of the character.
- Camera stays steady through the jump (no big bob); framing keeps the character in the lower-centre third.

## Tuning list (small, for T-059g)
1. Landing dust burst scaled by fall speed; sand/surface colour (MoveFeel already tracks `fallSpeed`).
2. Short landing dip (crouch ~0.15 s) on hard landings — reuse MoveFeel `dip`.
3. Footstep dust puffs while running on sand/dirt only (material check), sparse.
4. 1–2 brief speed streaks on jump take-off while running.
5. Keep camera steady in the air; no extra bob.
