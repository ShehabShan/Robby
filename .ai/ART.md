# ART — direction, asset plan & quality bar (P-003, S6, 2026-10-30)

Inputs: GDD §11 (vertical slice), R-013 (Rell Seas bar), R-015 (headless asset routes), D-024 (Mild), D-014 (original IP).
Routes: **Code** = built in Luau (Rojo); **Blender** = `art/blender/*.py` → `build/art/` → Open Cloud upload; **anim2rbx** = FBX → `.rbxmx`; **Owner** = `assets/source/`; **Store** = vetted Creator Store asset (trusted creators only, R-015).

## 1. Style
- **Stylised ink-wash xianxia:** soft painterly forms with clean silhouettes and low-to-mid poly. No photoreal detail.
  This hides the headless pipeline's limits (R-015) and reads well on mobile.
- **Readable combat first:** each Path has one signature VFX colour. Enemy telegraphs are always warm red/orange and never used by players.
- **Mild (D-024):** sparks, ink splashes and light motes; no blood, wounds or corpses.

## 2. Palette
| Use | Colours |
|---|---|
| World base | mist greys `#C9CED6`, pine greens `#3E5B4A`, warm stone `#8C7B68` |
| Moon Path | pale blue `RGB(150,205,255)` (Crescent Cut) |
| Flame / Stone / Wind | ember `#FF8A3D` / ochre `#C8A060` / jade `#7FE0B8` |
| Telegraphs (enemy) | `#FF4A2E` |
| UI | ink `#141A24` panels, parchment `#EDE3CF` text, Core hue per Rank as the accent |

## 3. References (look, not content)
- **Rell Seas:** cinematic VFX, impact framing, UI clarity (R-013).
- Generic Chinese ink-wash landscape painting and misty terraced mountains (public-domain art styles).
- No RI fan art and no screenshots from other games are used as assets.

## 4. Vertical slice asset list
| Asset | Route | Notes |
|---|---|---|
| Mistvale terrain (valley, river, cliffs) | Code (`Terrain:WriteVoxels`) | Biome materials + colour overrides |
| Hub village (5 houses, gate, shrine, Crucible altar) | Blender | Modular kit ≤ 5k tris per piece |
| Trees, rocks, lanterns, grass | Blender | 3–4 variants each; instanced |
| Player look | Roblox avatar + code-built robe accessory | No custom rig in the slice |
| NPCs (mentor, keeper, trader, rival ×2) | Roblox R15 rigs + Store/Owner clothing | Swap later for owner models |
| 3 Kith creatures (Crescent, Stone, Wind) | Blender (owner models may replace) | ≤ 8k tris, 1 texture ≤ 1024 |
| 2 beast enemies + 1 boss | Blender + owner/animator | Boss is the riskiest asset |
| Combat animations (5-hit chain, dash, parry, 3 casts, hits) | anim2rbx from FBX; code tweens as fallback | Likely animator budget (R-013/R-015) |
| Enemy and boss animations | anim2rbx | Telegraph poses held ≥ 0.4 s |
| Ability VFX (Crescent Cut, Stone, Wind, Weave) | Code | Beam/Trail/Particles/Highlight (T-004 pattern) |
| Hit, parry, Binding, Rite VFX | Code | Built-in textures first, custom flipbooks later |
| UI (HUD, Qi bar, journal, Crucible) | Code | Fonts from the built-in Roblox set |
| Icons (Kith, materials) | Blender renders → image upload | 256 px |
| SFX (hits, casts, UI) | Store (licensed) or Owner | Built-in placeholders until then |
| Music (hub, zone, boss) | Owner or Store | 3 loops ≤ 3 min |

## 5. Measurable quality bar (from R-013)
1. Client plays its own action animation and VFX within **1 frame** of input; the server confirms the hit.
2. **Every hit** has hit-stop (2–4 frames), a spark VFX, an SFX, a white flash and a damage number.
3. 5-hit light chain, dash with i-frames, a timed parry and a guard-break are all present.
4. Every boss attack is telegraphed (red, ≥ 0.4 s wind-up).
5. Camera shake is small and returns to zero (no drift).
6. **60 fps** on a mid-range phone in the hub and in combat with 4 players; ≤ 1.5 GB client memory.
7. No text wall over 2 lines in the first 10 minutes (GDD §8).
8. At least **3 build layers** are visible in the slice: Kith choice, Crucible, Weave.
9. All three platforms are playable: PC, mobile and gamepad.
10. No asset breaks Mild (D-024) or uses RI names or art (D-014).

## 6. Owner actions needed
1. **Fix the Roblox key:** set the `roblox-open-cloud` integration to send the key in an `x-api-key` header. Grant permissions on universe 10773761715: place publish, Luau execution, asset upload. This unblocks T-005b, T-006 and all uploads.
2. **ID-verify the Roblox account** to raise audio uploads from 10 to 100 per month (R-015).
3. Optional: drop owner models, textures or music into `assets/source/` (listed in `INDEX.md`).
4. Decide later in P-004/P-006: a small budget for an animator (combat animations are the main quality risk).
5. No Studio steps are needed beyond playtesting (AGENTS §8).