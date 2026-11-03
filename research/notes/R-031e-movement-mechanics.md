# R-031e — Movement mechanics from public sources (S148, 2026-11-03)

Scope: movement only (owner, after S147). No video this session (movement.mp4 not available), so this is the
public-source half; frame timing comes in R-031f–h. Web answers via `scripts/search.sh` (Exa); sources per line.

## Rell Seas (main benchmark)
| Move | What sources say | Source |
|---|---|---|
| Run | LShift toggles run (no hold) | rellseaswiki.com/controls |
| Slide | Hold C while running; Space during slide = slide jump | rellseaswiki.com/fighting-styles/parkour |
| Double jump | Space twice | rellseaswiki.com/controls |
| Geppo (sky walk) | Up to 3 mid-air jumps (5 with Geppo Master); each jump goes the way the **camera** points, not straight up | rellseaswiki.com/fighting-styles/geppo-master, /combat-mechanics |
| Wall run | Jump while running at a wall, then A/D to run left/right | rellseaswiki.com/fighting-styles/parkour |
| Dash | Key X; on ground, in air and on ships; only **side** dashes give i-frames, forward/back = positioning | rellseaswiki.com/controls, /combat-mechanics |
| Air dash | Used to chase/extend and reposition; no stated per-jump limit or landing refresh (weak source) | rellseasgame.wiki/guide/rell-seas-guide |
| Down slam | In air, attack while moving back; breaks block on landing (combat move) | rellseaswiki.com/fighting-styles/combat-mechanics |
| Upgrades | Agile posters change dash range (e.g. Mr Widestep) and slide/wall moves; Flash Dash = longer dash | rellseaswiki.com/posters/agile-posters, /flash-dash |
| Numbers | Slide length/speed, wall-run time, stamina costs: **not published** | rellseaswiki.com/fighting-styles/parkour |

## Other top Roblox games
- **Deepwoken:** slide = Ctrl while running; slide jump keeps momentum and launches up; air dash = Q in air, acts as a
  dodge, and timed at ground touch it cancels/reduces fall damage. Pro loop: slide → jump → air dash down at ~37° →
  roll → slide again (keeps speed). Wall jump facing away, wall climb facing the wall. (deepwoken.fandom.com/wiki/Movement)
- **Jujutsu Shenanigans / Strongest Battlegrounds:** Q dash, forward ~25 studs, side/back = short evasive steps,
  cooldowns per direction; landing roll keeps momentum after big falls. (jujutsu-shenanigans.fandom.com/wiki/Game_Controls,
  games.gg/roblox/guides/the-strongest-battlegrounds-combat-guide)

## How Roblox devs build smooth movement
- Custom accel/decel instead of instant WalkSpeed: push along camera direction, subtract a % of current velocity;
  LinearVelocity for dashes. (devforum.roblox.com/t/how-to-make-fluid-momentum-and-parkour/3188756, /1224644)
- `Players.UseStrafingAnimation = true` gives built-in R15 strafe anims; good games lerp shift-lock rotation instead of snapping. (devforum, robloxs.wiki/wiki/shift-lock)
- Ground slam: detect Freefall (Humanoid.StateChanged / ray to floor), play anim, on Landed spawn the effect. (devforum.roblox.com/t/ground-slam-mechanic-is-very-broken/3327702)

## Compared with Robby today (`Config.Movement`, `Config.Dash`)
- Has: accel 120 / decel 160 / turn decel (already custom, good), sprint 24→27, slide 0.6 s from 30, slide-jump, vault, hard-landing slow, ground Q dash (side 10 studs/0.2 s with i-frames, fwd/back 12 studs positioning).
- Missing vs benchmark: **double jump / air jumps**, **air dash**, **slam-down**, **wall run**, landing roll / fall-cancel.

## Open questions for the video (R-031f–h)
1. Strafe: does the body turn to the camera (shift-lock style) while dashing sideways? How fast does it accelerate?
2. Jump: height in studs (body ≈ 5 studs), time to apex; second jump height vs first; camera-directed or straight up?
3. Air dash: count per air time (owner says 1–2), distance vs ground dash, does it stop the fall (hang)?
4. Slam: startup pause in air?, fall speed, landing shake/dust ring, recovery, can you dash/slide out of it?
5. Chains: slide → jump → air dash → slam → slide — where does speed carry, where does it reset?
