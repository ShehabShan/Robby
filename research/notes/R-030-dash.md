# R-030 — Basic dash vs Wind Step (S141, 2026-11-03)

Owner ask (inbox 2026-11-03-dash-vs-windstep): we need the movement dash Rell Seas / Project Slayers 2 /
battlegrounds games have; Wind Step can become a special long dodge or a short teleport; not like Blox Fruits.

## What Wind Step is today (code)
- A **dash, not a teleport**: client sets root velocity so it covers 14 studs in 0.25 s (~56 studs/s), any
  direction (move direction, else facing). Server owns cooldown; speed guard mirrors the burst (D-204).
- Key R / L2, costs 8 qi, cooldown 3 s, i-frames 0.3 s (`Config.Abilities.WindStep`). It is a Kith move,
  so a player without Wind equipped has no dash at all (D-189 removed the free Q dash).

## How the reference games do it
| Game | Input | Directions | I-frames | Cooldown / cost | Extra |
|---|---|---|---|---|---|
| Rell Seas | X | 4-way | side only; fwd/back = positioning | side pair and fwd/back pair have separate cds | Evade (separate, fills by taking damage) breaks combos |
| Project Slayers 2 | Q + WASD | 4-way | perfect dodge just before a hit stuns attacker | stamina-gated | — |
| Deepwoken | Q | roll, default back, any via move; air dash | yes | stamina; roll-cancel (M2) | — |
| Strongest Battlegrounds | Q + WASD | 4-way | back roll briefly | fwd/back 5 s shared, side 2 s | side-dash cancel into attack |
| Blox Fruits (avoid) | Q | mostly forward | — | energy, very short cd | criticised: too fast/long, spam escapes every attack |

Sources: rellseaswiki.com/fighting-styles/combat-mechanics; slayers2.playertome.com/guides/controls;
allthings.how/slayers-2-roblox-how-to-dash-and-dodge-hits; deepwoken.fandom.com/wiki/Movement;
bloxism.com/the-strongest-battlegrounds/mechanics/basic-combat; change.org "nerf the dash in blox fruits";
bloxfruitswiki.org/wiki/dashing.

## Pattern → Robby
- Every player has a **short directional dash** (Q + WASD). **Side** dash = the dodge (short i-frames, short cd);
  **forward/back** = positioning (no i-frames, longer cd). Stamina cost. Not usable while stunned.
- Anti-Blox-Fruits rules: short distance (~10 studs), no chaining (cd + stamina), i-frames only sideways,
  dash ends in a short recovery so it can't escape everything.
- **Wind Step becomes the special**: longer (~20 studs), full i-frames in any direction, passes through
  players, and **works while stunned** (combo breaker, like Rell Seas Evade). Costs qi, long cd. This keeps it
  worth equipping. Short-teleport variant was considered: harder to read for the hit player and to validate
  on the server; keep as a later option.
- Key clash: Q is the slide (D-431). Proposal: Q while sprinting forward = slide; Q otherwise = dash.

## Proposed numbers (playtest)
| | Distance | Time | I-frames | Cooldown | Cost |
|---|---|---|---|---|---|
| Side dash | 10 | 0.2 s | 0.04–0.18 s | 1.5 s | 15 stamina |
| Fwd/back dash | 12 | 0.22 s | none | 3 s (shared) | 15 stamina |
| Wind Step (new) | 20 | 0.3 s | full | 6 s | qi; usable in stun |
Speed guard: dash speeds (~50 studs/s) need a dash window like the Wind Step burst (D-204).
