# T-053a plan — Crescent Cut (Rank 1) feel/look rework + free 3D aim

Owner request 2026-11-02 (`research/inbox/2026-11-02-crescent-ranks-and-kith-scaling.md`, D-375–D-379): make Crescent Cut a *proper good ability* using the new assets; fix that the slash cannot go down from a rooftop and misses short beasts. **Damage and button stay unchanged** (left click, 20 dmg, 10 Qi, 1.2 s cd). Quality first; several sessions allowed.

## 1. Current state (code read S120)
| Part | Where | Today |
|---|---|---|
| Numbers | `Config.Abilities.CrescentCut` | speed 90, range 60, maxHits 2, hitbox 6×1.5×2, spawnOffset 3 |
| Client aim | `src/client/AimDir.luau`, `KithInput.luau` ~l.114 | mouse ray meets the plane at the root's height, then Y is dropped; shift lock = character facing (flat); touch/gamepad = camera look |
| Server aim | `src/server/Abilities.luau` `authorizeCast` ~l.578–630 | checks unit/finite, then `Projectile.flatten` → `Vector3.new(x,0,z)`; origin = root + dir·3 + CHEST |
| Hits | `Abilities.luau` `sweep` ~l.261 | Blockcast box along dir each Heartbeat; **walls and ground are skipped** (blade passes through) |
| Blade look | `src/client/CrescentFx.luau` | 7 neon Part segments in a 120° arc, Trail, PointLight, stock sparkles; no uploaded art |
| Cast feel | `CrescentFx.swipe` | tweened shoulder Motor6D + hand glow + placeholder `swordslash.wav` |
| Hit feel | `src/client/HitFeel.luau` (`Config.HitFeel`) | shared spark burst, white flash, damage number, 3-frame hit-stop, small shake |
| Art (unused) | `assets/source/` | `vfx-crescent-slash.png`, `vfx-crescent-hit.png` (1024², opaque on black), `icon-crescent-cut.png`, `creature-crescent-kith-v2.glb` |

**Root cause of the owner's bug:** both client and server throw away the vertical part of the aim, and the blade flies at chest height. Tilting the character can't change it.

## 2. Goals and acceptance
1. The blade flies **toward what the player points at**, including up and down: rooftop down-shots, short beasts, ledges.
2. The blade **looks like the art**: the slash texture as the blade, the hit texture on impact, readable to other players.
3. Casting **feels good**: anticipation, a snappy release, the body turns to the aim, real sound, impact weight.
4. Server stays authoritative (no aimbot or through-wall abuse); Rimeshard / Volley / Twin Crescent are unchanged.
5. AC per subtask: `check.sh` PASS + Lune tests. Final AC: the owner playtest checklist (§8) passes.

## 3. Free 3D aim (T-053a1)
**Client (new `AimDir.free`)**
- Aim ray: mouse pointer ray (normal mouse), screen-centre ray (shift lock / LockCenter, gamepad, touch).
- Raycast that ray into the world (exclude own character and FX folder, max 500 studs) to get the **aim point**; with no hit, use the point 500 studs out along the ray.
- Direction = (aimPoint − bladeOrigin).Unit, where bladeOrigin = root + flatForward·spawnOffset + CHEST (the same formula the server uses). This removes camera-vs-shoulder parallax: the blade lands where the cursor is.
- If the aim point is closer than 4 studs or behind the player, fall back to flat look.

**Server (opt-in per move, data-driven)**
- New Move param `delivery.params.aim = "Free"` (default `"Flat"`, so every other move stays exactly as today).
- New pure module `src/shared/Aim.luau`: `clampPitch(dir, maxPitchDeg)`, which keeps the yaw and clamps elevation to ±`maxPitch` (proposal **70°**). It also handles non-finite or degenerate input. Tested in `tests/Aim.spec.luau`.
- Origin stays server-computed from the **flat** forward, so pitching never spawns the blade inside the floor. A root→origin raycast pulls the origin back if a wall is in between (no shooting through a wall you're hugging).
- Rate and cooldown are unchanged (existing Moves/CastAdmission).

**Stop on world (proposal, owner Q1)**
- With down-aim, a blade that ignores the ground would vanish underground.
- Proposal: `stopOnWorld = true` for Crescent Cut. The blade ends at the first anchored, collidable, non-character part or terrain, and plays a ground-impact effect.
- Humanoid hits and pierce (maxHits 2) are unchanged.

**Hitbox:** the Blockcast box rotates with the pitch (`CFrame.lookAt`, safe because the pitch is clamped). Proposal: height 1.5 → **2.5** for slight vertical forgiveness. Width and damage are unchanged. This is a tuning knob for playtest.

**Everyone sees the same:** the server already broadcasts `dir` in `CastFx`. The client FX use the full 3D dir and orient the blade with its pitch.

## 4. Assets → Roblox (T-053a2)
- Make processed copies with Pillow via `uv run`: crop to content, 512² or 1024² as needed, plus an alpha version (luminance → alpha) for any surface that isn't additive. Store them in `assets/processed/` and keep the originals untouched.
- Upload as Image assets through Open Cloud (the existing `roblox-open-cloud` integration, owner user 7738981129, same flow as `scripts/upload_anims.py`). This needs a new `scripts/upload_images.py`.
- Record the ids in a new `src/shared/AssetIds.luau`; update `assets/source/INDEX.md`.
- If an id is missing or under moderation, the code falls back to today's code-built look. Tests stay offline.
- Risk: moderation delay or integration permission (image upload scope). Check in a1 or a2 with a dry run first.

## 5. Blade look (T-053a3)
- **Main blade:** a textured **Beam** across the blade's two tips, with `FaceCamera=false`, `LightEmission=1` and `LightInfluence=0`. Additive blending makes the black background vanish, so the opaque PNG works as-is. The Beam lies in the blade plane and follows pitch.
  - Fallback: alpha-texture Decals on a thin invisible plane, if the Beam reads poorly edge-on.
- **Core:** keep a thinner neon arc as a bright inner edge (fewer parts), plus a soft PointLight.
- **Motion:**
  - grow-in 0.6→1.0 scale over 0.06 s
  - slight forward roll (tilt) for life
  - tip Trail ribbon kept and tuned
  - sparse moon-dust particles (custom texture cut from the slash art) instead of stock sparkles
- **End:** a 0.12 s dissolve (fade, widen, light down) at range or on world stop.
- **Config:** `Config.Fx.CrescentCut` holds the tunables (scale, colours, trail life, particle rate) and `look = "Art" | "Classic"`, so we can A/B in playtest.
- **Perf:** reuse instances from a small pool (≤ 8 live blades per client) and skip particles on low graphics quality.

## 6. Cast feel (T-053a4)
- **Turn to aim:** on cast the character snaps (0.08 s) to face the aim's yaw if it isn't shift-locked. Today a blade can leave sideways from the body.
- **Swing:** a 3-phase arm motion:
  - anticipation pull-back 0.05 s
  - release 0.07 s
  - follow-through 0.15 s
  - Still tweened Motor6D (no upload needed). Optional later: a real uploaded animation through the existing animation pipeline.
- The blade spawns from the hand side and blends into the server origin within 2 frames.
- Hand flash (hit-texture sprite, small) plus a short FOV kick (−2°, 0.1 s), which can be turned off in settings.
- **Sound:** a cast whoosh with a moon "ring", a travel hum (quiet, on the blade), a hit chime/slice and a ground-impact thud. The source is open (owner Q4).
- **Mobile/gamepad:** same aim rules (centre ray); no extra UI.

## 7. Hit and impact (T-053a5)
- **Hit on a target:** a burst of the `vfx-crescent-hit.png` sprite, camera-facing, additive, 2→6 studs over 0.18 s. It runs on top of the existing HitFeel (number, flash, hit-stop, shake), with no damage change.
- **Pierce:** the blade dims a little after the first target, so a pierce reads as a pierce.
- **World impact** (if Q1 = stop): a smaller hit sprite flattened onto the surface normal, dust puff and short spark scatter.
- Other players see the same impacts (server `HitFx` already fans out; add `kind = "world"`).

## 8. Owner playtest checklist (T-053a6)
1. From a rooftop, click a beast on the ground: the blade goes down and hits.
2. A short test beast at your feet level: it gets hit.
3. Aim up at a ledge or roof target: it hits.
4. Aim into a wall or the ground next to you: the blade stops with an impact (if Q1 = stop) and doesn't go through.
5. Shift lock, normal mouse, gamepad and touch all aim where expected.
6. Looks: the blade matches the art, reads clearly, hit and ground impacts look right. Compare to Classic with the config switch.
7. Feel: the cast is snappy, the body turns to the aim, sounds fit, there's no lag between click and blade.
8. Damage, cost, cooldown and the button feel the same as before.

## 9. Build split (each S-sized, one session or less)
| Id | Work | Depends |
|---|---|---|
| T-053a1 | `Shared.Aim` + tests; `AimDir.free`; server opt-in `aim="Free"`, pitch clamp, origin wall-check; `stopOnWorld`; hitbox knob | — |
| T-053a2 | Process the PNGs; Open Cloud image upload script; `AssetIds.luau`; INDEX | integration check |
| T-053a3 | Art blade (Beam), core, grow, dissolve, dust, pool, `Config.Fx.CrescentCut`, Classic switch | a1, a2 |
| T-053a4 | Turn-to-aim, 3-phase swing, hand flash, FOV kick, sounds | a1 (sounds: Q4) |
| T-053a5 | Hit sprite burst, pierce dim, world impact + `HitFx kind` | a2, a3 |
| T-053a6 | Owner playtest build (Studio via Rojo or TEST place), tuning pass from feedback | a1–a5 |

## 10. Open questions for the owner (answered in §11)
1. **Walls and ground:** should the blade stop when it hits a wall or the ground? Recommend **yes**. Without it, a down-shot sinks into the floor.
2. **Pitch limit:** recommend **±70°** (no straight-down shot at your own feet). OK?
3. **Kith model:** should the Rank 1 Crescent Kith model be visible (for example floating at the shoulder, with the blade launching from it)? Recommend a **separate later task**; it touches every Kith.
4. **Sounds:** may we use Roblox's free licensed sounds from the Creator Store, or will you provide or generate sounds?
5. **Playtest:** Studio through Rojo, or the private TEST place like Wind Step?
6. **Speed and range** (90 studs/s, 60 studs) count as *feel*, not damage. May the playtest pass tune them?

## 11. Owner answers (2026-11-03 00:11 +06, D-380)
Owner: "I go with your recommendations. But want to add for point 4. I think promptql has in-build access of few good audio model which we can use for better sound effect. But you decide which to use for now."
1. Blade **stops on walls/ground** (`stopOnWorld = true`) with an impact FX.
2. Pitch clamp **±70°**.
3. Kith model visible beside the player: **later, separate task** (all Kith).
4. **Sounds: owner wants Google Gemini models (2026-11-03 00:14 +06, D-381; replaces the Higgsfield idea).** Access goes through the managed integration `__gemini-web-search` (a general Gemini API key; `__gemini` and `__gemini-search` are not enabled). Models probed in S120 with `GET generativelanguage.googleapis.com/v1beta/models`:
   - **Lyria** (music): `lyria-3-clip-preview` (30 s clips), `lyria-3-pro-preview`, `lyria-3.5`, all through `generateContent`. Also `lyria-realtime-exp` (bidi stream).
   - **TTS** (speech only): `gemini-3.8-flash-tts` and others.
   - **Native-audio and live** models (bidi conversation).
   - None of them is a dedicated sound-effect model.

   **S120 test:** a whoosh prompt to `lyria-3-clip-preview` returned a 30.5 s `audio/mpeg` clip. It is *musical* and quiet for the first ~1 s, with a part labelled `<instrumental>`. The bot artifacts `lyria_whoosh` and `lyria_whoosh_first3s` (in bot d039233e) hold it for the owner to listen to.

   **Approach for T-053a4:**
   - **Lyria makes the tonal "moon" layers:** a cast ring/shimmer, a hit chime, a rank-flavour stinger. Prompt for very short, sparse, single-hit tones, then cut the best 0.2–1.0 s slice with ffmpeg (trim, fade, loudness-normalise).
   - **Non-tonal layers** (air whoosh, slice transient, ground thud) are synthesised with ffmpeg or numpy (filtered noise sweeps, pitch envelopes), then layered with the Lyria tone.
   - Make 2–3 variants per sound for the owner to pick.
   - Store under `assets/source/sfx-crescent-*.ogg` and upload to Roblox as Audio through Open Cloud.
   - Creator Store remains the last-resort fallback.
   - Cost: each Lyria call costs OLU and goes through approval.
5. Playtest in the **private TEST place** (like Wind Step).
6. The playtest **may tune speed and range**.

## 12. Higgsfield audio check (S120, 2026-11-03 00:19 +06, owner asked)
- The Higgsfield integration (`__higgsfield`) is provisioned: the API answers through the integration. Its full docs are at `https://docs.higgsfield.ai/llms-full.txt`.
- **No audio-only or sound-effect model is listed.** The catalogue covers image and video models (Kling, Seedance, Wan, Hailuo, PixVerse, LTX, Grok Imagine, Soul, Recraft, Ideogram and others). Audio appears only as *native sound in video models* (for example Kling 2.6/3.0 text-to-video `"sound": "on"`, 5 or 10 s, 16:9/9:16/1:1) and as audio *reference* inputs.
- **Possible route (untested):** generate a 5 s Kling text-to-video of the slash with `sound: on`, then extract the audio with ffmpeg. That is a video-priced job (several OLU per try, needs approval) and the sound quality is unknown. A test was not run in S120 because of the session OLU limit (~38/50).
- **Next step (T-053a4):** run one Kling test and compare it with Gemini Lyria (§11.4). The owner prefers Higgsfield if the result is good.
