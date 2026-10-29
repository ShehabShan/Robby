# GDD — Robby

## Pitch
A fast, replayable **obby race**. Every round generates a fresh course from obstacle chunks; everyone races to the finish, and placements earn coins for cosmetics. A familiar genre with a twist: you can't memorise the map.

## Audience & platform
Ages 9–14. PC + mobile first (jumps tuned for touch, no precision-only obstacles in tiers 1–2). Servers of 8–12 players.

## Core loop
Lobby → **Intermission** (15 s) → **Racing** (up to 180 s) → **Results** (8 s) → repeat.
The round ends early when every player has finished.

## Course
- Built from **chunks**: code-defined obstacle sections with a difficulty tier of 1–5.
- 10 stages per course. Difficulty ramps: stages 1–3 are tier ≤2, stages 8–10 are tier ≥3.
- The course is generated from a per-round seed, so it is deterministic and reproducible for bug reports.
- Each stage ends with a checkpoint pad. A finish pad sits at the end.
- Falling or touching a kill part respawns you at your last checkpoint.

## Scoring & rewards
Finishers are ranked by time. Coins: 1st 30, 2nd 20, 3rd 15, other finishers 10, did-not-finish 2. Wins are counted for leaderstats.

## Progression (M2)
Coins and wins persist. A trail shop sells cosmetics only; nothing pay-to-win.

## Out of scope until later
Monetization, custom meshes or modelled art, private servers, and a level editor.