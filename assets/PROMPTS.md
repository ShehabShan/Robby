# Asset prompts and status (A-001, owner asset lane)

The owner generates assets on third-party sites. The bot writes the prompts, checks each file and indexes it. Task: `.ai/TASKS.md` A-001.

## Status
| # | Asset | File | Status |
|---|---|---|---|
| 1 | Crescent Kith creature v1 (3D) | `creature-crescent-kith.glb` | done ffc8830; superseded by 1b (came out with butterfly wings and a tail) |
| 1b | Crescent Kith creature v2 (3D) | `creature-crescent-kith-v2.glb` | done 04d2c31, indexed dd63535 (4.9k tris) |
| 2 | Twin Crescent Kith v2 (3D) | `creature-twin-crescent-kith.glb` | done ae6fa83, indexed 04edb83 (4.9k tris) |
| 3 | Crescent Cut slash texture | `vfx-crescent-slash.png` | done 563f6cd, checked S114 (1024², opaque black bg, centered) |
| 4 | Crescent hit texture | `vfx-crescent-hit.png` | **next** |
| 5 | Ability icons x3 | `icon-crescent-cut.png`, `icon-twin-crescent.png`, `icon-piercing-edge.png` | todo |
| 6 | Cultivator base character (3D, rigged) | `character-cultivator-base.fbx` | on hold: ART.md §4 uses the Roblox avatar + code-built robe in the slice. Only if the owner asks. |

## Rules for every asset
- Original designs only: no Reverend Insanity names, characters or art (D-014). Mild: no blood (D-024).
- Moon Path colour is pale blue RGB(150,205,255). The Twin Crescent lower wings are pale gold.
- The owner drops files in `assets/source/`. The bot checks them and adds one `source/INDEX.md` row (what it is, site, mode/model, license, date).
- When 1b lands, mark the v1 row in INDEX.md "superseded by creature-crescent-kith-v2.glb" (never delete owner files).

## 3D workflow (Ludo.ai, https://app.ludo.ai/3d-generator)
1. Generate an image from the prompt and pick the cleanest front view.
2. Image to 3D, model **Prop** (4 credits). Use Hero (15) only if thin parts like wing tips break.
3. Advanced: Max triangles about 5k (never over 10k), Adaptive decimation default, Type PBR, Resolution 1024. Skip Rig and Make Sprites. Download GLB.
4. Bot check: `python3 scripts/glb_check.py assets/source/<file>.glb`. Known and accepted: no emissive map (glow is added in Roblox), opaque wings, about 1 m wide (scaled to hand size on import).

## 1b. Crescent Kith creature v2 (3D)
Same technique as the Twin Crescent v2 so the two read as one family (rank 1 and rank 2).
> A hand-sized mystical moth spirit with two wings, where each wing is a thin, sharp crescent moon: a sickle-shaped curve with two pointed tips and a hollow inner curve. Both wings are pale silver-blue and spread wide and symmetrical, seen from the front. It has a slender dark-indigo body, tiny glowing eyes and faint star-dust speckles on the wings. Stylized hand-painted low-poly game asset. The wings are opaque, with bright painted highlights along the edges. Neutral pose, plain background.

**Negative:** butterfly wings, rounded wings, four wings, tail, hindwing streamers, dangling legs, extra limbs, text.

## 2. Twin Crescent Kith variant v2 (3D), done
> A hand-sized mystical moth spirit with four wings, where every wing is a thin, sharp crescent moon: a sickle-shaped curve with two pointed tips and a hollow inner curve. The upper pair is silver-blue and the lower pair is pale gold. The two pairs overlap like an eclipse. All four wings are spread wide and symmetrical, seen from the front. It has a slender dark-indigo body, tiny glowing eyes, and a thin glowing ring halo attached just behind the back. Stylized hand-painted low-poly game asset. The wings are opaque, with bright painted highlights along the edges. Neutral pose, plain background.

**Negative:** butterfly wings, rounded wings, tail, hindwing streamers, dangling legs, extra limbs, text.

## VFX textures (3 and 4): how they are used
- **Single images, not flipbooks.** AI image sites can't keep 16 frames consistent. Code animates scale, rotation and fade (ART.md §4: ability VFX are code-built; these textures replace the built-in ones).
- **Pure black background, not transparent.** The sites rarely produce real transparency. In Roblox the texture is used with `LightEmission = 1` (additive), so black disappears.
- 1024x1024 PNG, the shape centered with empty margin, nothing else in the image.

## 3. Crescent Cut slash texture
> A single crescent-moon energy slash on a pure black background: one thin, sharp arc curving from lower left to upper right, glowing pale blue with a white-hot core along the leading edge, fading into a soft trail with a few tiny sparkles. Game VFX texture, centered, nothing else in the image, no text, 1024x1024.

## 4. Crescent hit texture
> A single impact burst on a pure black background: a bright white flash at the center, a thin crescent-shaped shockwave arc around it, and sharp pale-blue light shards radiating outward. Game VFX texture, centered, nothing else in the image, no blood, no text, 1024x1024.

**Negative:** blood, gore, red or orange tones, fire, smoke, explosion debris, more than one burst, full-circle ring, background scenery, characters, weapons, frame or border, gradient or grey background, transparent checkerboard, text, watermark.

## 5. Ability icons (2D)
Match the existing Kith icons (`icon-crescent-kith.png` etc.): use the same tool (ForgeGUI `generation_image`, `icon_gfx`) if possible. Square 1024x1024 PNG.
Shared style: square game skill icon, ink-wash xianxia painting style, dark ink background (#141A24) with soft swirling mist and a subtle frame, one bold silhouette readable at small size, centered, no text.
- **(a) `icon-crescent-cut.png`:** a single pale-blue crescent-moon blade slicing diagonally, with a white-hot edge and a short motion streak.
- **(b) `icon-twin-crescent.png`:** two crescent blades crossing like an eclipse, one pale blue and one pale gold.
- **(c) `icon-piercing-edge.png`:** a pale-blue crescent blade with a sharp spear point thrusting straight forward through a thin ink ring.

## 6. Player base character (3D), on hold
> A young martial cultivator in original eastern-fantasy robes: layered dark-blue and off-white cloth, wide sleeves, a sash belt, and simple boots. A neutral expression and short tied-back hair. Stylized anime proportions (slightly large head, slim build), hand-painted textures, low-poly, rigged humanoid in T-pose (R15-compatible if the site supports it).

## Prompt lessons so far (raw notes for the future prompt guide)
- Name the exact shape, not the theme: "crescent wings" gave butterfly wings + tail (1 v1); "a thin, sharp crescent moon: a sickle-shaped curve with two pointed tips and a hollow inner curve" fixed it (1b, 2).
- Always add a **Negative** line listing what the last try got wrong (butterfly wings, tail, streamers...).
- Reuse the same sentence pattern across a family (1b matches 2) so assets read as one set.
- VFX: "pure black background" + "centered, nothing else in the image" gave a clean, usable texture on the first try (3, Ludo.ai).
