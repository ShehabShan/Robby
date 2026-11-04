# MOVEMENT_PLAN — P-031 movement-only plan (S154, 2026-11-04, D-459–D-464)

Consolidates [R-031e](../research/notes/R-031e-movement-mechanics.md), [R-031f](../research/notes/R-031f-strafe-jump.md),
[R-031g](../research/notes/R-031g-air-dash-slam.md), [R-031h](../research/notes/R-031h-slide-chaining.md) into original Robby rules.
Movement only: no damage, stun, i-frames or combat targeting for the new air moves (combat decides those later).
All numbers below are **our starting tuning** (in `Config`), not values measured from the video. Visual cue intervals from
R-031g/h are presentation targets only and are never copied into physics.

## 1. Three columns: evidence vs owner intent vs unknown
| Topic | Visible evidence (R-031e–h) | Owner intent | Unknown → we choose |
|---|---|---|---|
| Strafe | Facing held toward subject, coherent feet, sparse puffs; reversal pose change over ~0.2 s window (f) | Smooth sideways movement | Latency, accel, lock algorithm |
| Jump up | Readable upward transition, continued travel after rise (e/f) | Strong upward jump | Height, gravity, count |
| Air dash | Rapid airborne repositioning, streak → white burst cue 0.18–0.30 s (g) | 1–2 air dashes | Count, refresh, distance, startup |
| Slam | Arc → blue burst cue 0.37–0.40 s; contact not proven (g) | Forceful slam to ground | Trigger, fall speed, recovery |
| Slide | Low pose 0.23–0.45 s, thin streaks, no smoke (h) | Slide | Duration, cancel windows |
| Chaining | Moves visibly adjacent (h) | Moves chain together | Buffer/cancel windows, momentum carry |

## 2. Movement states and legal transitions (D-459)
States: `Ground` (walk/jog/sprint), `Slide`, `Dash` (existing ground Q dash), `Air` (jump or fall), `AirDash`, `Slam`, `Land` (recovery), `Vault`.
| From → To | Rule |
|---|---|
| Ground → Air | Jump, or leaving an edge (fall). Coyote time 0.10 s after leaving an edge still allows a jump. |
| Ground → Slide / Dash | Existing rules (`Movement.canSlide`, `Dash.serverAllows`) unchanged. |
| Slide → Air | Jump at any point of the slide (slide-jump), or slide off an edge. Both carry the **horizontal velocity vector** (speed + direction), capped at 30 studs/s; carry clears on landing (existing grounding rule). |
| Dash → Air | Jump allowed after 60 % of the dash (0.12 s side / 0.13 s fwd-back); earlier presses are buffered. |
| Air → AirDash | Needs a charge and ≥ 3 studs ground clearance (raycast) so it never duplicates the ground dash. |
| AirDash → AirDash / Slam | AirDash → AirDash only after it ends; AirDash → Slam allowed after 0.10 s. |
| Air → Slam | **V** while airborne (C is taken by kit specials in `KithInput`) with ≥ 6 studs clearance. Committed: no cancel until ground contact. Air Q = air dash, matching ground Q dash. Gamepad mapping chosen in T-059e. |
| Slam → Land | On ground contact only (not on effect spawn). Fixed 0.15 s recovery; replaces hard-landing recovery for slams. |
| Land → anything | Jump/slide/dash pressed during recovery are buffered and fire when it ends. |
| Any → Vault | Existing `VaultClient` rules; vault/ledge climb refreshes air-dash charges. |

## 3. Air dash and slam rules (D-460, D-461)
- **Air dash:** 2 charges (owner range 1–2; `Config.AirDash.charges`, 1 is a one-line change). Refresh **only** on ground contact (≥ 1 grounded tick) or a vault/climb; never mid-air.
  Direction = camera-relative WASD, neutral = camera forward. Horizontal burst 9 studs over 0.18 s; vertical velocity set to 0 at start (short hang), then normal gravity.
  Cost 10 stamina each; no cooldown beyond charges. Server validates charges + stamina via a remote and opens a SpeedGuard window (same pattern as D-204 dash).
- **Slam:** 0.08 s hover, then straight-down velocity 90 studs/s; horizontal speed kept at ≤ 30 % until contact. On contact: ring + dust VFX, short camera shake (0.2 s, low amplitude), 0.15 s recovery.
  Slam locks air dashes until landing (they refresh on landing). Server opens a SpeedGuard vertical window.
- **Jump:** Robby owns the jump instead of engine defaults: `Config.Jump` with `UseJumpPower=false`, JumpHeight 7.2 (Roblox default, now explicit), coyote 0.10 s.

## 4. Input buffer (D-462)
One buffer slot, latest press wins, 0.12 s life, for Jump / Q (dash, slide, air dash) / V (slam). A buffered action fires on the first tick it becomes legal, else it expires silently.

## 5. Strafe, camera and VFX targets (D-463)
- **Strafe:** wire the unused `Movement.turnRate` (jog 720°/s, sprint 420°/s) for free-turn locomotion; shift lock keeps facing = camera yaw. Strafe animations belong to T-058c.
- **Camera:** sprint FOV 70→78 stays. Air dash: +4 FOV kick for 0.15 s. Slam: shake on contact only. Normal jumps/landings: no shake.
- **VFX (sparse, R-031h):** air dash = thin white/black streaks + small white burst at start (T-058l style); slam = downward streaks while falling, ring + dust **at contact**; slide = T-058l wind lines (owner starts T-058l). No smoke clouds on ordinary locomotion.

## 6. Instrumented test criteria (D-464)
A `MoveTrace` debug recorder logs per tick: input press/release + consumed tick, state, grounded, clearance, velocity vector, stamina, charges, camera FOV.
Test course (Studio/cloud place): flat run, stairs, ledge, ruler walls 4/6/8 studs. Pass criteria (Lune spec for pure rules; trace in cloud test for wiring):
1. Air dash: dashes 1–2 succeed, 3rd rejected; refresh needs a grounded tick; horizontal distance 9 ± 1.5 studs.
2. Slam from 12 studs: contact ≤ 0.25 s after hover; recovery 0.15 s; slam can't start below 6 studs.
3. Buffer: jump pressed 0.10 s before landing fires on the landing tick; 0.20 s before does not.
4. Coyote: jump 0.08 s after leaving an edge works; 0.15 s does not.
5. Carry: slide-jump takeoff horizontal speed ≥ 95 % of slide speed, direction within 5°.
6. Strafe: 18→−18 lateral reversal ≤ 0.30 s (scalar model); no facing flip while shift-locked.
7. Parity: results within 10 % at 30 vs 60 fps; desktop + controller input both map (touch noted, later).

## 7. Implementation split (all S, in order; see TASKS.md T-059)
T-059a pure `Shared.MoveRules` (states, transitions, buffer, coyote, charges) + specs → T-059b `MoveTrace` + test course →
T-059c jump ownership, coyote, buffer, slide-jump vector carry → T-059d1 air dash pure+server → T-059d2 air dash client + VFX/FOV →
T-059e slam (pure, server window, client, contact VFX) → T-059f strafe turn-rate wiring → T-059g cloud test + owner feel test.
