# T-043a — Rimeshard reference study and implementation audit

S65 · 2026-10-31 · Baseline gameplay commit `2197be4` · Research, not quality approval.
Owner brief: [original inbox](../inbox/2026-10-31-rimeshard-quality-direction.md).
Proposal: [direction and delivery plan](T-043a-rimeshard-direction.md). Visual review: [board](T-043a-review.html).

## Evidence method and limits

Five short, silent gameplay clips embedded by Gamersberg were downloaded and sampled into 12-frame contact sheets with ffmpeg. The sheets were visually inspected, not merely inferred from search descriptions. Times below are approximate **clip positions**, not measured input latency, damage windows or animation frame data. Clip game versions and capture settings are unknown; this is a craft study, not a claim about the latest Blox Fruits build. No audio track exists in these files, so no competitor sound claim is made.

YouTube showcase `leN9UiOkkBs` and official Wriothesley demo `kdQOis0VRoo` were located through web search but playback access failed; neither is treated as watched evidence. Fandom pages returned 403. All findings below use the accessible clips or inspected source code instead. Third-party assets are reference-only: do not import their meshes, textures, animation or sound into Robby.

## Linked visual evidence

| ID / source | Observed in sampled frames | Interpretation for Robby (proposal, not source fact) |
|---|---|---|
| V1 — [Ice M1, 3.36 s](https://asset.gamersberg.com/blox-fruits/extra/ice-awakened-normal-attack.mp4), [sheet](T-043a-references/ice-m1.jpg) | At 0.28–0.84 the weapon/arms change orientation through a swing; 1.12–1.96 reads as recovery/reposition; 2.24–3.08 another swing. The avatar remains readable against the grass. | The everyday attack needs authored body action and rhythm, not just a projectile emitted from an idle character. Borrow pose contrast, not its ice weapon. |
| V2 — [Cold Storm, 3.64 s](https://asset.gamersberg.com/blox-fruits/extra/ice-awakened-cold-storm.mp4), [sheet](T-043a-references/ice-storm.jpg) | Compact start; white/cyan rings and snow plume extend forwards around 1.21–2.12; the trail disperses around 2.43–3.34. | Distinguish source, directional body and trailing residue. Avoid making the whole effect equally bright. |
| V3 — [Absolute Zero, 4.40 s](https://asset.gamersberg.com/blox-fruits/extra/ice-awakened-absolute-zero.mp4), [sheet](T-043a-references/ice-zero.jpg) | Quiet scene at 0–0.37; bright floor footprint at 0.73; near-white peak at 1.10; large angular blue ice crown at 1.47–3.67 obscures much of the character and ground. | Strong geometric silhouette sells ice better than generic smoke. **Anti-reference:** do not copy the whiteout or persistent screen-filling crown for a frequently used mobile kit. |
| V4 — [Snowflake Shuriken, 4.24 s](https://asset.gamersberg.com/blox-fruits/showcase-folders/snowflake-shuriken.mp4), [sheet](T-043a-references/blizzard-3.jpg) | Two raised bright hands at 0.71; compact burst at 1.06; several separate bright discs spread at 1.41; smoky connectors at 1.77; loops/specks dissipate at 2.12–2.47, clearer by 2.83. | A fan should read as a deliberate opening gesture and distinct lanes, not five duplicates hidden inside fog. Our forms remain angular needles, not copied snowflake discs. |
| V5 — [White Out, 7.64 s](https://asset.gamersberg.com/blox-fruits/showcase-folders/white-out.mp4), [sheet](T-043a-references/blizzard-4.jpg) | Small ground swirl at 1.27 grows into a tall bounded spiral at 1.91–4.46; thinner tail at 5.09–6.37. | Use height to distinguish Rime Fall from the flat fan, with a clear start/peak/tail. Do not turn Rime Fall into a tornado or copy that move's mechanics. |

Source landing pages: [Ice](https://www.gamersberg.com/blox-fruits/wiki/fruits/ice), [Blizzard](https://www.gamersberg.com/blox-fruits/wiki/fruits/blizzard). Contact sheets are low-resolution analysis excerpts, not game assets. Their timestamps were burned into the sampled frames; full clips are not committed.

## What the current kit actually does

This is a **code audit**, not a live render/playtest. The owner's rejection is the visual-quality evidence. A readable implementation can still render badly, and a good-looking plan is not a game build.

| Move / layer | Observed implementation | Design diagnosis / risk |
|---|---|---|
| M1 Needle 1/2 | `RimeFx.take/fly` uses the same 0.3 × 0.3 × 1.8 Glass cuboid and short trail; `needle.cast` plays a placeholder sword slash. No authored attack-pose playback in the audited KithInput/RimeFx path. | High-priority weak identity: no dedicated attack pose, tiny constant section, same visual vocabulary on every light. |
| M1 finisher | Two shards, 6° spread; same geometry, louder slash; 1.2 s gameplay recovery. | Needs a recognisable paired release and settling pose so the pause looks intentional. Keep the 2-projectile gameplay footprint. |
| Z Shard Fan | Five shards over 30°, reused Needle travel plus extra shards, same sword slash. Content declares 0.2 s telegraph; `volleyCast` immediately inserts shots and broadcasts FX. | A pose alone must not promise a safe 0.2 s warning that the damage simulation ignores. Record/test this timing mismatch before rebuilding; no stealth balance change in art work. |
| X Rime Fall | Red radius-7 disc; eight cuboids descend from 18 studs with 0.22 s tween, staggered over 1 s; snow, frost disc and final crack. Local `rain` waits 0.6 s; remote `rain` starts immediately, while server sends cast/travel together and Zone owns its delay. | Different observer timing is visible in code; exact perceived offset needs two-client reproduction. Rain/decorative drops must match four server damage ticks, not suggest eight independent hits. |
| C Shatter | Local chilled-highlight list draws veins; expanding Neon **sphere** reaches 50-stud diameter in 0.3 s. Camera shake happens on cast even without confirmed targets; hits add generic puff. Server selects Chilled targets after 0.3 s. | An all-enclosing sphere reads as indiscriminate damage, although only Chilled targets qualify. Payoff belongs at confirmed targets, not an empty caster explosion. |
| Chill / Rimed | `crust` replaces a single Highlight with a fixed timeout; local cache is visual, not authoritative stack count. | Current presentation cannot honestly distinguish 1/2/3 stacks. Stack-aware art requires replicated authoritative state, not counting client hit puffs. |
| Sound / hit feel | Built-in swordslash and electronicpingshort; smoke texture. `pause` freezes every playing animation and restores all speeds to 1. | These are placeholders, not frost identity. Hit-pause can interfere with locomotion or non-unit track speeds; freeze only owned attack tracks and restore prior speed in future work. |
| Lifecycle / performance | Projectile pool cap 24 and per-cast layout cap 12 exist. Puff, disc, Highlight, veins and snow create additional effects; projectile `fly` runs full range without hit reconciliation in that function. | Projectile count alone is not a total FX budget. Need global admission/LOD, cancellation and per-cast ownership; hit/projectile reconciliation requires an ID contract. These are identified risks, not measured leaks/FPS regressions. |

Audit files: [`Config.Abilities.Rimeshard`](../../src/shared/Config.luau), [`Content/Rimeshard`](../../src/shared/Content/Rimeshard.luau), [`RimeFx`](../../src/client/RimeFx.luau), [`RimeFxPlan`](../../src/shared/RimeFxPlan.luau), [`KithInput`](../../src/client/KithInput.luau), [`init.client`](../../src/client/init.client.luau), [`Abilities`](../../src/server/Abilities.luau).

## Mobile source check

Roblox's [particle-emitter documentation](https://create.roblox.com/docs/effects/particle-emitters), checked against [the official source](https://github.com/Roblox/creator-docs/blob/main/content/en-us/effects/particle-emitters.md), states 400 particles/s per emitter on desktop and **100/s on mobile**, warns about overlapping transparency/overdraw, and says low-memory clients may deactivate flipbooks. A search answer incorrectly said 400/s on mobile; it is rejected. These are API limits, **not** a recommended effect budget or a measured Robby device result. Shape/contrast must survive with secondary particles disabled.

## Conclusions and unknowns

- Borrow layered phases, strong silhouettes and deliberate body action; not the borrowed IP, textures, moves or screen saturation.
- Rebuild a small **M1 vertical slice first**. It is the highest-frequency contact with the ability and the owner's explicit complaint. An owner-approved M1 becomes the grammar for the rest of the kit.
- Keep gameplay values initially: Needle 4 damage, 120 speed, 45 range; Z 5 lanes/30°/35 range; X radius 7/four ticks; C radius 25/Chilled-only/max 12. Any timing reconciliation is a separate tested change.
- Still unknown: real-device input correctness (T-042b), current live visual baseline, audio mix, strongest acceptable flash/shake, animation asset permissions, low-end-phone GPU cost and the owner's preferred direction. No visual acceptance or performance PASS claimed.
