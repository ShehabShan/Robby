# Rimeshard — from floating shards to a deliberate frost technique

T-043a · S65 · 2026-10-31 · **OPTION A APPROVED — owner 2026-10-31; M1 prototype first, whole-kit acceptance still pending**

Owner request: [verbatim](../inbox/2026-10-31-rimeshard-quality-direction.md). Evidence and current-code audit: [reference study](T-043a-reference-audit.md). Illustrated short version: [review board](T-043a-review.html). This is a direction, not a claim that the game already looks this way.

## 1. Choose the visual language, not the damage numbers

| Option | What the player feels | Advantage / cost |
|---|---|---|
| **A — Faceted frost / recommended** | A precise practitioner shapes sharp ice splinters with the hands; pressure builds in targets and breaks on command. | Distinct poses, hard ice silhouettes and restrained mist work at phone scale. Requires authored attack animation and a small original mesh/texture kit, not more generic particles. |
| B — Snowstorm caster | Broad flowing snow ribbons, soft wind and large drifting clouds. | Atmospheric and closer to Blizzard references, but easily hides opponents and resembles existing generic frost effects. Higher transparency/overdraw risk. |
| C — Ice gauntlet brawler | Heavy arm armour, close strikes and big body follow-through. | Strong physical impact, but reads as melee while Needle actually travels 45 studs. Would require a new combat design rather than an honest visual overhaul. |

**Recommendation: A.** Keep the ranged kit and its build-Chill → Shatter payoff. Borrow Blox Fruits' pose contrast and layered phases, not its fruit identities, weapons, silhouettes or asset files. Avoid its screen-filling whiteout. Ask the owner: **“Shall we take this sharp, hand-shaped ice direction and prove it with the left-click combo first?”** A different answer changes the proposal, not a finished system.

## 2. Shared art grammar

- **Primary form:** an asymmetrical, pointed three-face splinter with a dark blue side plane, blue mid-plane and a narrow pale edge. Opaque geometry carries the silhouette; transparency is an accent. No constant cyan neon box.
- **Palette proposal:** deep ice `#18415C`, body `#68B7D4`, edge `#E1FAFF`, restrained frost mist `#ACC6D0`. The existing warning semantics remain separate: hostile danger must not depend on blue/red colour alone; preserve outline/pattern and threat readability.
- **Four silhouettes:** M1 = narrow straight line; Z = separated forward fan; X = bounded downward column/ground crown; C = inward fracture at marked targets. A muted phone-size image should distinguish them without key labels.
- **Three layers, with priority:** (1) body pose + solid signature shape; (2) short edge/trail or crack ribbon; (3) sparse flecks/mist. Under load drop layer 3, then shorten 2; never drop a danger boundary or required hit/readiness cue first.
- **Motion:** small gather → sharp release → useful negative space → brief residue. One dominant peak, not constant maximum brightness. M1 must feel good without camera shake or decorative particles.
- **Original assets:** one shard mesh with variants, one crack/fleck texture sheet and dedicated R15 attack clips. Build from original source; license/ownership and asset permission checks before use. No reference video extraction into game assets. Headless previews are useful but never replace a Roblox client recording.

## 3. Per-move storyboard and timing proposals

Times below are **proposed presentation targets**, not measured Roblox frame timings. Authoritative values come from `Config.Abilities.Rimeshard`. Timing must be resolved in T-043c before promising visual alignment. Do not silently slow M1 or buff the kit to improve appearance.

### Left click — Needle 1 → Needle 2 → paired finisher

**Pose:** compact left-hand draw across the chest → right-hand counter-flick → both palms compress then separate. Shoulders and forearms do the action; avoid pelvis/root motion that fights movement and aiming. Upper-body action tracks must blend over walking/running and release cleanly on slot switch/death.

**Silhouette:** single slender faceted dart on hits 1/2; two clearly separated brighter darts on the finisher, not one large projectile. A short slanted wrist streak ties each release to the body. Visual launch must bridge from hand to the **server's existing launch origin**, not move the hitbox to the hand.

**Timing:** keep first-input release immediate under the existing contract. Do not add a wind-up tax; give the second/third shots readable preparation in the preceding recovery, with distinct neutral starts if delayed. Use the existing 0.25 s light recovery and 0.8 s chain window. Finisher has its existing 1.2 s lockout: settle the hands, let small crystals dissolve, communicate “recovering”; do not loop attacks that cannot fire. No movement lock.

**Impact:** confirmed hit = narrow entry flare + a few oriented chips + one local frost patch; a miss gets only travel/fade. Finisher hit = paired crack accents, not twice the whole flash. Preserve projectile count, 6° finisher spread, 45-stud range and actual damage.

**Sound/camera proposal:** short dry ice flick with subtle left/right variation; finisher adds a lower snap. No M1 camera shake by default. If hit-pause survives testing, pause only this kit's owned action track on confirmation and restore its previous speed; never freeze locomotion or other systems' tracks.

**Proof:** record isolated 1/2/3, interrupted chain, moving casts and 30 seconds of repeated combo on desktop and owner phone. Owner accepts this slice before special-move art begins.

### Z — Shard Fan

**Pose:** hands draw a small arc inward, then open into a sharp horizontal sweep. Five splinters briefly form a readable spread; centre line aligns with the actual shot direction. Do not animate a new held-charge mechanic.

**Silhouette/layers:** five individually readable tapered lanes over the existing 30°; a short curved release ribbon, sparse grain behind, narrow per-target chips. Not a wall of fog or an oversized semicircle suggesting a wider hit area. At most two shards can damage the same target, as now; visual impact count must not promise five hits.

**Timing:** intended 0.20 s preparation → release → short recoil and fade. **Blocked:** Content declares 0.20 s but the audited server currently launches immediately. T-043c must test and explicitly reconcile this, including parry/chain-cancel behaviour. Until then this is only a storyboard. No camera punch for firing into empty space.

**Sound:** layered ice scrape during preparation, one airy release, sharper confirmed contact. Keep peak quieter/smaller than Shatter. Device check: five lanes remain distinct over bright grass and dark ground.

### X — Rime Fall

**Pose:** one hand lifts to draw the cold overhead, then a downward command. A few upward glints connect the caster's intent to the aimed ground point without implying a projectile from the player to the centre.

**Silhouette/layers:** crisp radius-7 boundary with patterned progress, sparse upward slivers during the 0.60 s warning; then four grouped downward beats, one for each server damage tick over 1 s. Tall narrow shards and a low broken ice rim give height without building an opaque tower. Keep bodies/feet visible inside. Decorative drops are not extra damage ticks.

**Timing:** one common cast timeline for caster and observers. Ground location comes from accepted server aim/raycast; predicted location can correct gently before release. No remote rain during a warning the caster still sees. Fade decorative ground residue within roughly 0.5 s after the final beat; retain gameplay danger for exactly as long as needed, not as long as the prettiest decal.

**Sound/camera:** a thin falling whistle per group with restrained crunchy impacts. Repeated ticks never stack camera shake. No giant full-screen ice flash. Low-quality mode retains the boundary and grouped impact silhouettes, removes airborne snow first.

### C — Shatter

**Pose:** draw fingers together to tighten the frost, then close the hands with a compact decisive snap. Hands/torso provide the anticipation; a 50-stud glowing bubble does not.

**Silhouette/layers:** during the existing 0.30 s wind-up, subtle strands suggest tension towards eligible marked targets. Eligibility is provisional until server selection. At confirmed targets: cracks pull inward, then a brief angular burst opens out and clears. A three-stack/Rimed target gets a distinct broken crown and stagger beat; fewer stacks get smaller breaks. No ring suggesting damage to every unmarked enemy in radius.

**Truth requirement:** stack-aware presentation needs authoritative replicated stack information or confirmed event data. Do not derive stacks from local Highlights or number of received puffs. If there are no valid hits, show a restrained hand release only—no successful-hit sound, camera punch or fake target burst. Expiry/death/target movement during wind-up is normal, not a reason to invent a hit.

**Sound/camera:** compressing ice creak → dry break at confirmed impact → short low tail. Optional small local camera impulse, once per cast even with 12 targets; setting to zero must preserve readability. No random cumulative camera drift or white screen. Other players receive world FX/audio, not forced camera movement.

### Chill / Rimed — the connecting language

One/two/three directional frost chips or readable segments around the target, with a shape change at three (not colour alone). Avoid covering the entire avatar in bright fill. Authoritative expiry and consumption clear it immediately; a new hit can refresh it without old delayed cleanup deleting the refreshed cue. Shatter uses the same fissures so its payoff feels earned. Reduce distant markers to a small outline/segment count, never a misleading full stack.

## 4. Mobile, audio and engineering guardrails

**Budget hypotheses, to validate rather than claim:** start with <=24 active projectile/decorative shard meshes per client, <=96 live decorative particles across the kit, <=8 trail/beam objects and <=4 simultaneous kit sound voices. Use global admission priorities; do not confuse per-emitter Rate with live-particle count. Extend/revise only with recorded device evidence. Enforce cleanup/cancellation; reuse resources. Up to 12 Shatter targets must degrade to cheap target cracks rather than spawning 12 maximal bursts.

- Test phone landscape and portrait HUD constraints where supported, with camera zoom/occlusion, high/low graphics, bright grass and dark terrain. Start target: stable >=30 FPS on the owner's agreed test phone; record model/settings/scene, baseline and casting frame times. Not a proven performance guarantee.
- Stress: four nearby simultaneous casters, maximum Shatter targets, persistent X, slot swaps, death, respawn and leaving; counters return to baseline after lifetimes. Essential tells survive budget pressure. No whole-screen transparent layers, dynamic lights or required flipbooks.
- Audio is a new original/licensed frost palette, not a claim copied from the silent references. Spatial rolloff, bounded concurrency and bus headroom; no repeated tick crackle drowning enemy cues. Accessibility: reduced flash/motion and independent effects volume.
- Game state stays on the server. Cast identity/timestamps, prediction/rejection, target reconciliation and cleanup are explicit contracts; animation markers are presentation cues, never client-authoritative damage.
- Use pure planning/timeline modules plus thin engine wiring, Lune tests and mocked client checks. Freeze existing balance values unless a named timing-fix decision states the intentional change and tests it. No new publish without owner instruction.

## 5. Small delivery gates

Each row is a separately claimable **S-sized** task (target <=30 OLU work plus boot/save). Split further before starting if its code scope grows. Avoid parallel edits to `RimeFx`, KithInput, server Abilities or remotes. TASKS.md holds the actionable AC.

1. **T-043b — owner direction review.** Show this board and options; record choice/edits. Waiting is intentional, not permission to rebuild all moves.
2. **T-043c1 — timing contract/regressions.** Demonstrate Z immediate launch and X observer-delay mismatch; choose explicit desired times and cast identity/prediction requirements in tests/spec, no art.
3. **T-043c2 — Z timing alignment.** Implement only the agreed Z scheduling fix; test cancellation, duplicate inputs and parry/chain implications.
4. **T-043c3 — X observer alignment.** Shared timeline/accepted centre for X; caster and observer tests, four authoritative beats. Do not bundle whole FX refactor.
5. **T-043d1 — original M1 asset/pose prototype.** Small shard kit and 1/2/finisher poses with source and headless previews; permission path documented. No special art.
6. **T-043d2 — M1 integrated slice.** Pure presentation plan, bounded resources, moving/standing attack blends and verified hits, preserving damage/timing; check + mocked tests.
7. **T-043d3 — M1 audio and owned-track feel.** Licensed/original frost sound set, concurrency and safe track-only hit-pause; reduced-motion option. Separate from d2 to protect session size.
8. **T-043e — owner M1 review.** Main-only cloud functional smoke; real PC/phone recording after explicit publish request if needed. Record owner accept/iterate; otherwise create a small revision task and repeat.
9. **T-043f — Z visual slice.** Owner-approved grammar, five lanes + hand sweep + impact/audio; c2 required.
10. **T-043g — X visual slice.** Boundary + four grouped falls + cleanup/audio; c3 required.
11. **T-043h1 — truthful Chill state.** Replicated stack/expiry/consumption contract + simple 1/2/3 markers and tests, before C art.
12. **T-043h2 — C visual slice.** Target-local fracture, empty-cast distinction, one bounded camera/audio impulse per cast, using h1.
13. **T-043i1 — stress/cleanup pass.** Automated resource/cancellation regression and profiling instrumentation, four-caster scenario.
14. **T-043i2 — real-device whole-kit review.** Record functional, visual, audio and frame-time evidence separately; owner judges ALL moves including M1. Keep T-043 open until explicit satisfaction; repeat small revisions as needed.

## 6. Review checklist (not completed)

- Can the owner identify M1/Z/X/C in silent, reduced-size clips without labels?
- Do pose, release, accepted damage and sound peak agree? Are misses honest?
- Does left-click still feel deliberate after 30 seconds, including its finisher recovery?
- Can the player see the enemy, ground and danger throughout X/C?
- Do 1/2/3 Chill and the successful Shatter read without a UI explanation?
- Does low-quality mode preserve essential shapes and input feedback, with safe cleanup and recorded device performance?
- Does the owner explicitly want this kit kept, rather than merely saying it works?

Automated tests answer functionality. Rendered recordings answer presentation. Only the owner answers whether the quality target has been met.
