# SPIKE — Crescent Cut (P-007, S5, 2026-10-30)

Purpose: prove that a polished Roblox ability can be built, tested and shipped **headlessly** (no Studio) — D-025.
Ability: **Crescent Kith → Crescent Cut** (rank 1, Moon path), from R-019. Working names.

## 1. Ability spec
| Item | Value (tune in playtest) |
|---|---|
| Input | PC `E` / left-click while Crescent is held; mobile on-screen button; gamepad `ButtonX` (ContextActionService) |
| Aim | Camera look direction flattened to horizontal (PC/mobile alike) |
| Qi pool (rank 1) | 100 max, regen 5/s |
| Cost | 10 Qi per blade |
| Cooldown | 1.2 s |
| Damage | 20 base × rank multiplier (rank 1 = 1.0, +25% per rank) |
| Projectile | speed 90 studs/s, range 60 studs, pierces up to 2 targets, each target hit once |
| Hitbox | server blockcast 6 × 1.5 × 2 studs per step along the path, ignoring the caster |
| Spawn | 3 studs in front of the caster's root, chest height |

## 2. Feel & VFX (code-only, no uploads)
- Crescent: an arc of 7 small neon segments (pale blue `RGB(150,205,255)`), a Trail between two arc-end attachments, a PointLight, and a ParticleEmitter using a built-in engine texture.
- Cast: arm swipe by tweening the right shoulder joint (no animation asset needed); a brief brow/palm glow.
- Hit: spark burst, the target flashes white (Highlight), 3-frame hit-stop on the attacker, small non-drifting camera shake, a floating damage number.
- Fade: crescent widens and fades over 0.15 s at range end or on the last hit.
- SFX: built-in engine sounds (`rbxasset://sounds/...`) as placeholders.

## 3. Authority (AGENTS §6)
- Client: plays the swipe and a local crescent instantly, then sends `CastRequest(direction)`.
- Server: checks Qi, cooldown, alive state, that the direction is a unit vector; then **simulates the projectile itself** and decides hits. Damage only on the server.
- Server tells all clients `CastFx(caster, origin, direction)` and `HitFx(target, amount)`; the caster's client skips the duplicate crescent.

## 4. Training dummy
- An R15-style dummy built from parts in code, Humanoid with 200 HP, in front of the spawn; resets 5 s after reaching 0; shows HP above its head.

## 5. File layout
| File | Role |
|---|---|
| `src/shared/Qi.luau` | Pure Qi pool: `new`, `regen`, `canSpend`, `spend` |
| `src/shared/Kith/CrescentCut.luau` | Pure: config, `tryCast(state, now)`, `damageFor(rank)`, `stepProjectile`, hit bookkeeping |
| `src/shared/Config.luau` | Adds `Abilities.CrescentCut` tunables |
| `src/server/Abilities.luau` | Remotes, validation, projectile simulation (blockcast), damage |
| `src/server/Dummy.luau` | Spawns and resets the training dummy |
| `src/client/AbilityInput.luau` | Key, mobile button, gamepad → `CastRequest` |
| `src/client/CrescentFx.luau` | Crescent, swipe, hit sparks, hit-stop, shake, damage numbers |
| `tests/Qi.spec.luau`, `tests/CrescentCut.spec.luau` | Lune tests |

Networking uses plain RemoteEvents in the spike (no tool dependency); the real stack (Blink, R-016) is chosen in P-004 (D-026).
The obby sample (RoundState, HUD) is removed in T-004 so the test place is clean.

## 6. How we verify without Studio
1. **T-003:** `check.sh` (format, lint, strict types, Lune tests, `rojo build`) = PASS.
2. **T-005 local:** a Lune script opens `build/Robby.rbxl` and asserts the scripts, remotes and modules are where Rojo should put them.
3. **T-005 cloud** (needs owner setup): upload the place, run a Luau Execution task in the real engine that spawns the dummy, calls the server cast and checks the dummy's HP drops by 20.
4. **T-006:** with the owner's explicit OK, publish to a **private** test place; the owner plays it in the normal Roblox app and reports how it feels.

## 7. Owner setup needed before T-005/T-006
- Create a private Roblox experience (any name) and share its universe ID and place ID.
- Create an Open Cloud API key for it (place publishing + Luau execution), stored in a PromptQL custom integration — never pasted in chat.