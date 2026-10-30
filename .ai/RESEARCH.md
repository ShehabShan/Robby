# RESEARCH

- **Format per task** (AGENTS.md §4.2): Findings (each with a source) → **→ Implications** → Unknowns → Sources. ≤25 lines per task.
- Long material goes in `research/notes/`.
- Model-memory claims are labelled "(unverified)".

## R-001 Development practice (done 2026-10-29)
- **Workflow:** filesystem-first.
  - Rojo is the source of truth, code is edited outside Studio, and Rokit pins tool versions.
  - Layout: `src/{client,server,shared}`, Wally packages, `--!strict`, luau-lsp types, Selene plus `stylua --check`.
- **Testing is split in two:**
  - Engine-independent logic → Lune unit tests.
  - Engine-dependent tests run in a real Roblox server via the **Open Cloud Luau Execution API**, usually with TestEZ or Jest-Lua.
- **Luau Execution API:**
  - Upload a place version: `POST /universes/v1/{universeId}/places/{placeId}/versions` (scope `universe-places:write`).
  - Run a task: `POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks` (scope `universe.place.luau-execution-session:write`).
  - Limits: 10 concurrent tasks per place, 5-minute timeout, 4 MB script/return size, 5 tasks per minute per key owner.
- **Security and data:**
  - Server authority: the server is the single source of truth. Prefer silent mitigation (rubber-banding) over bans.
  - One profile per UserId with retries. ProfileStore session locking is the standard.
- **→ Implications:**
  - The scaffold matches current practice.
  - Batch engine tests into one cloud task per session.
  - Use ProfileStore for player data.
  - Combat must be validated on the server.
- **Sources:**
  - create.roblox.com/docs/projects/external-tools
  - create.roblox.com/docs/cloud/reference/features/luau-execution
  - create.roblox.com/docs/cloud/reference/features/places
  - create.roblox.com/docs/projects/server-authority
  - create.roblox.com/docs/scripting/security/security-tactics
  - github.com/Roblox/place-ci-cd-demo
  - github.com/thegamerbay/roblox-luau-execution-action

## R-002 Platform scan (done 2026-10-29; obby-specific parts archived)
- **Trends (2025–26):**
  - Social, low-friction, trend-driven games win, and fast iteration beats graphics alone.
  - Scope small and iterate on retention.
  - Sessions of 19 minutes or more retain and monetise better.
  - RPG, strategy and shooter games that push Roblox's visual standard are being prioritised.
- **Discovery:** Home recommendations rank on what players do after they find a game. Signals, in order:
  1. play-through rate
  2. first-play bounce rate
  3. play days per user
  4. playtime per user

  These are measured over D1, D2–7 and D8–28. Also tracked: qualified play sessions, intentional co-play days, spend days, and Robux per user.
- **Monetisation rules:**
  - Game Passes are permanent purchases; Developer Products are repeatable.
  - Honest descriptions and no fake urgency.
  - PolicyService for age/location restrictions. Paid random items are restricted for users 18 and under by default.
  - Neutral wording for minors.
  - Complete the Maturity & Compliance questionnaire.
- **→ Implications:**
  - The first minutes must hook players, to keep bounce low.
  - Co-play is a ranking signal, so plan party/social play.
  - No loot boxes.
  - Long sessions suit an RPG.
- **Sources:**
  - newzoo.com/articles/roblox-strategic-growth-platform
  - create.roblox.com/docs/discovery
  - about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
  - create.roblox.com/docs/production/monetization

### R-011 Source study: Reverend Insanity (done 2026-10-30)
Full notes: `research/notes/R-011-reverend-insanity.md`.
- **Findings:**
  - Abilities are living creatures (Gu), ranked 1–9 (1–5 mortal, 6–9 immortal), each needing a specific food (sagaofgu.com/cultivation/gu-worms).
  - Gained by subduing wild ones or fusing two + materials via recipes into a higher rank (sagaofgu.com/cultivation/refinement).
  - Killer moves = fixed combos of several Gu, stronger but costlier; formations = placed, breakable setups (sagaofgu.com/cultivation/killer-moves).
  - Cultivation: inner aperture stores essence; 9 ranks × 4 stages; aptitude A–D sets pool/regen/ceiling; essence colour changes per rank (sagaofgu.com/cultivation/aperture).
  - World: mountain clan villages, bloodline clans vs. lone outcasts; talent-based sects in the centre (sagaofgu.com/factions).
  - Fans love strategic plotting and a cruel, logical world; critics cite length, pacing, bleakness (ficfun.com, goodnovel.com reviews).
  - Gu is real Chinese folklore (jar of venomous creatures); xianxia realms/sects/tribulations are genre conventions (en.wikipedia.org/wiki/Gu_(poison), /wiki/Xianxia).
- **→ Implications for Robby:**
  - Core fantasy candidate: tame, feed, fuse and combo living abilities on a colour-coded rank ladder.
  - Combos and path affinities give action-RPG build depth; clan vs. outcast = faction choice.
  - Keep the cunning tone, but neutral wording for minors; all names and plot original (D-014).
  - Don't tie gu users to any real ethnic group (folklore stereotype).
- **Unknowns:** whether feeding upkeep is fun or a chore; details of dao marks; sources are wikis/reviews, not the novel.
- **Sources:** see the notes file (30 sources).
### R-012 IP & licensing (done 2026-10-30)
Full notes: `research/notes/R-012-ip-licensing.md`. Not legal advice.
- **Findings:**
  - RI by Gu Zhen Ren, Qidian/China Literature 2012–2019, English licensed to Webnovel; game-rights terms not public (en.wikipedia.org/wiki/Reverend_Insanity).
  - Removed from Qidian in 2019 by a Chinese regulatory campaign; no official game or anime, only a licensed manhua (novelbrief.com, novelupdates.com).
  - Roblox removes games on DMCA notice, often without warning: Shinobi Life 2 (VIZ), anime simulators over MHA assets (devforum.roblox.com, polygon.com).
  - Roblox rules forbid unlicensed names, characters, branding (about.roblox.com/community-standards).
  - Mechanics are not copyrightable; expression is — Tetris v. Xio, Spry Fox v. LolApps (17 U.S.C. §102(b); loeb.com; pillarlegalpc.com).
- **→ Implications for Robby:**
  - A license is unrealistic; D-014 confirmed and tightened (D-023).
  - Keep systems and tone; never use the title, names, plot, coined terms, text or art.
  - Use our own word for the creatures (not "Gu"); no "inspired by RI" in the store page.
- **Unknowns:** exact game-rights owner; non-US law (Roblox enforcement is the practical gate).
- **Sources:** see the notes file (15 sources).
### R-013 Rell Seas teardown (done 2026-10-30)
Full notes + draft quality bar (14 items): `research/notes/R-013-rell-seas.md`.
- **Findings:**
  - Pre-release open-world pirate RPG by RELL Games (two brothers), years in development, expected 2026; early build ~591k visits, ~6 CCU (bloxinformer.com, rovitals.com).
  - Combat: 5-hit M1 chain + launcher into air combos, timed parry, side-dash i-frames, combo-breaker evade bar, posture (rellseaswiki.com/fighting-styles/combat-mechanics).
  - Progression: every activity counts; 5-star bar → rank-up choice; bonded weapon class; 39 weapons, 38 bosses (rellseaswiki.com/systems/progression-system).
  - World: 4 seas, ~28–30 islands incl. sky/underwater (rellseas.org/guides/game-overview).
  - No pay-to-win; cosmetics, rerolls, slots; crews, battlegrounds, ranked 1v1 (rellseas.fandom.com/wiki/Monetisation).
  - Praised for cinematic VFX/animation; criticised for delays (progameguides.com, mobilematters.gg).
  - Uses One Piece IP → DMCA risk; we copy quality, not that (polygon.com).
- **→ Implications for Robby:**
  - Draft quality bar: client-instant animation + server hits, 5-hit chains, parry/dash/breaker, hit-stop + VFX + SFX on every hit, telegraphed bosses, ≥3 build layers.
  - Art/animation throughput is the biggest gap for a headless pipeline — plan for it in P-003/P-004.
- **Unknowns:** exact combat numbers, team size, post-release retention.
- **Sources:** see the notes file (32 sources).
### R-014 Comparable Roblox games (done 2026-10-30)
Full table (9 games) and gaps: `research/notes/R-014-comparable-games.md`.
- **Findings:**
  - Anime action RPGs are big: Blox Fruits 120k–158k CCU, Grand Piece Online ~15k, Jujutsu Infinite ~3–4k, Deepwoken ~2.5k (statroblox.com, rovitals.com).
  - Cultivation games are small: Martial Arts World ~1–1.4k, Mortal to Immortal ~800, Murim ~100, Soul Cultivation ~30 (rblxdb.com, bloxed.gg).
  - Their loop is meditate → breakthrough → quests → combat; players like breakthroughs and idle farming, dislike slow grinds, bugs and no endgame (boundbyflame.com, bladerpg.com).
  - An RI fan game already exists ("Reverend Insanity cultivation", incremental sim using the title and terms) (creatorexchange.io).
  - Permadeath adds tension but causes burnout (earnaldo.com).
- **→ Implications for Robby:**
  - Gap: cultivation + Rell Seas-grade action combat; creature taming/fusion/combos; an original, takedown-proof world.
  - Endgame tension from rivals and risky fusions, not permadeath; short sessions that still progress.
- **Unknowns:** CCU of the RI fan game; real retention data.
- **Sources:** see the notes file (18 sources).
### R-015 Headless asset pipeline feasibility (done 2026-10-30)
Full notes + route table: `research/notes/R-015-asset-pipeline.md`.
- **Findings:**
  - Open Cloud Assets API uploads models (FBX/GLB/rbxm), images, audio, animations (rbxm/rbxmx) and meshes; 20 MB max; needs an API key (create.roblox.com/docs/cloud/guides/usage-assets).
  - Limits: 20k triangles per mesh, 4 bone influences, textures ~1024 (create.roblox.com/docs/en-us/art/modeling/specifications).
  - Audio ≤7 min; 100 uploads/month if ID-verified, else 10 (create.roblox.com/docs/en-us/audio/assets).
  - `anim2rbx` converts FBX animations to `.rbxmx` without Studio (github.com/jiwonz/anim2rbx).
  - VFX and terrain (`WriteVoxels`) are code, so Rojo-friendly (create.roblox.com/docs/reference/engine/classes/Terrain).
  - AI 3D: Roblox Cube 3D (beta), Tripo/Meshy APIs; licences differ (meshy.ai/api).
  - Creator Store assets are licensed for experiences but free models can be stolen (en.help.roblox.com Creator Store Terms).
- **→ Implications for Robby:**
  - A fully headless pipeline is feasible; the one owner step is an Open Cloud API key in a custom integration.
  - VFX, terrain and UI can be good and cheap; hero meshes and combat animations are the quality bottleneck → stylised art and a likely animator budget (P-004).
  - Early T-phase spike: upload one Blender mesh + one anim2rbx animation and play them.
- **Unknowns:** anim2rbx with R15/custom rigs; AI mesh quality; `__higgsfield` availability/licence.
- **Sources:** see the notes file (31 sources).
### R-016 Tech for a high-quality action RPG on Roblox (done 2026-10-30)
Full notes + recommended stack table: `research/notes/R-016-tech-stack.md`.
- **Findings:**
  - Combat standard: client hits locally for feel, sends a claim; server rewinds positions by latency and checks range/LOS/cooldown (create.roblox.com/docs/en-us/projects/server-authority).
  - Streaming: Improved model streaming, Opportunistic stream-out, SLIM LOD (create.roblox.com/docs/en-us/workspace/streaming/techniques).
  - Mobile budget: < 500 draw calls, < 500k tris, < 1.3 GB memory (devforum.roblox.com/t/…/3127146).
  - Libraries: ProfileStore (not ProfileService), ByteNet/Blink/Zap networking, Trove + Signal; Knit is legacy (github.com/officialmmt/OpenRoblox).
  - Luau Execution API runs tests in a real place: ≤ 5 min, ≤ 10 concurrent; Jest Roblox via Rojo-built place (create.roblox.com/docs/cloud/reference/features/luau-execution).
- **→ Implications for Robby:**
  - Stack: Rojo toolchain + pure modules, server-validated combat with rewind, Blink, ProfileStore, Trove/Signal, no framework.
  - Mobile-first budgets and streaming from day one; Lune locally + Jest Roblox in cloud (T-010).
- **Unknowns:** Blink vs ByteNet (spike); rewind tolerances; T-010 still needs place ID + key.
- **Sources:** see the notes file (23 sources).
### R-017 Content maturity & audience (done 2026-10-30)
Full notes + tone table: `research/notes/R-017-maturity-audience.md`.
- **Findings:**
  - Labels: Minimal (occasional mild violence), Mild (repeated mild violence, unrealistic blood), Moderate (non-graphic realistic injury), Restricted (graphic violence) (create.roblox.com/docs/en-us/production/promotion/content-maturity).
  - Restricted = 18+ ID-verified only, hidden from under-18s (en.help.roblox.com Restricted-Content-Policy).
  - Always banned: torture, extreme gore, serious abuse (about.roblox.com/community-standards).
- **→ Implications for Robby:**
  - Target label **Mild** (D-024); Moderate only as fallback; never Restricted.
  - Keep RI's cunning and scarcity as strategy and rivalry; no gore, corpses or cruelty; stylised hit effects; creatures merge, not devour.
- **Unknowns:** exact age per label; discovery effect of Mild vs Moderate.
- **Sources:** see the notes file (9 sources).
### R-018 Research synthesis — Options (done 2026-10-30)
Built from R-011…R-017. All names are working names (D-023); label Mild (D-024). Creatures = our own term, not "Gu".

**Option A — "Beastbound" open-world action RPG (recommended)**
- Pitch: your powers are living creatures you tame, feed, fuse and chain into combos, climbing a 9-rank ladder.
- Loop: explore a mountain region → fight/tame creatures → fuse into stronger ones → rank up (pick 1 of 3 perks) → harder zones and bosses.
- Hook: Rell Seas-style combat (5-hit chains, parry, dash) + a creature collection no Roblox game has (R-014 gap).
- Vertical slice: one mountain village + valley, 6 creatures, 2 fusion recipes, 3 combos, 1 two-phase boss, ranks 1–2.
- Risks: creature art and animation are the bottleneck (R-015); feeding may feel like a chore.
- Cost: high (largest art/animation need; likely artist/animator budget).

**Option B — Clan war PvPvE**
- Pitch: join a mountain clan or live as an outcast; fight for territory and scarce springs.
- Loop: gather → raid/defend points → clan ranks and shared upgrades.
- Hook: rivalry and cunning (the source's tone, kept Mild).
- Vertical slice: 1 map, 2 factions, 3 capture points, 4 creatures.
- Risks: needs many players online; balance and toxicity.
- Cost: medium.

**Option C — Crucible roguelite**
- Pitch: short runs into a shifting crucible; draft and fuse creatures mid-run; permanent rank progress between runs.
- Loop: enter → fight rooms → fuse picks → boss → keep rank XP.
- Hook: 10–15 minute sessions that always progress (R-014 "respect time").
- Vertical slice: 3 floors, 10 creatures, 1 boss, procedural rooms.
- Risks: less of the "big world" quality of the benchmark; needs lots of run variety.
- Cost: low–medium (procedural rooms, fewer hand-built maps).

**Recommendation:** A as the game, with B (clans) and C (crucible runs) as later modes on the same combat and creature systems. Start small: the A vertical slice.

### R-019 RI systems map + first-ability pick (done 2026-10-30)
Full map (18 systems) and ability notes: `research/notes/R-019-systems-map.md`.
- **Findings:**
  - RI's most iconic early attack is a rank 1 crescent creature that throws pale-blue crescent blades at range for ~10% of a rank-1 pool; it eats moon-flower petals and later fuses into a rank 2 version (sagaofgu.com/gu/moonlight-gu).
  - Other popular early creatures: permanent-strength boars, an essence-refining worm (sagaofgu.com/gu/white-boar-gu, /gu/liquor-worm).
  - A crescent projectile can be built in code: Trail/Beam/neon parts + particles + tween, spherecast hitbox (roclicks.gg/resources/vfx/beams-trails-projectiles).
- **→ Implications for Robby:**
  - Every RI system gets a Robby mirror with its own working name (Kith, Core/Qi, Binding, Crucible fusion, Weaves, Paths, Arrays, Clans/Rogues).
  - Spike ability: **Crescent Kith → Crescent Cut** (Moon path, rank 1).
- **Unknowns:** numbers (P-007); whether code-built VFX look shiny enough (T-004).
- **Sources:** see the notes file (10 sources).
### R-020a Gu system in depth (done 2026-10-30)
Full table (10 findings → mirrors) and 20 sources: `research/notes/R-020a-gu-system.md`.
- **Findings:**
  - Taming a wild creature-tool is a sustained essence tug-of-war against its will (sagaofgu.com/cultivation/refinement).
  - Each eats a specific food; heavy use makes it hungry sooner; starved ones go dormant or die (sagaofgu.com/cultivation/gu-worms).
  - Low-rank tools collapse if spammed without rest; some are consumables (sagaofgu.com/cultivation/mortal-gu).
  - Stages are a wall hardening light → water → stone → crystal; breakthroughs shatter it; partial damage heals (sagaofgu.com/cultivation/aperture-and-primeval-essence).
  - Fusion needs sustained focus while stones are fed in; high-rank fail rates are brutal (sagaofgu.com/cultivation/gu-fusion).
  - One life-bound tool shares injury with its master; rank 6+ tools are world-unique (sagaofgu.com/cultivation/vital-gu, /immortal-gu).
- **→ Implications for Robby:** Binding = skill tug-of-war; per-Kith Satiety + Strain with Dormant/Exhausted/Wounded states (no permanent loss); Core Shell Stage visual + wave breakthrough trial; Heart Kith identity; Shards = money + Qi refill; Singular Kith parked for Ascendant.
- **Unknowns:** meter overload on mobile HUD; real numbers are design choices (P-007).
- **Sources:** see the notes file.

### R-020b Paths & killer moves (done 2026-10-30)
Full table (10 findings → mirrors) and 19 sources: `research/notes/R-020b-paths-killer-moves.md`.
- **Findings:**
  - Power is split into many thematic paths, each with sub-paths (sagaofgu.com/paths).
  - Path marks multiply that path's moves; enough marks lift a move a rank (sagaofgu.com/cultivation/dao-marks).
  - Marks of different paths conflict (fire vs water); most specialise in 1–2 paths; mark-dense areas suppress rivals (basicutils.com dao-marks guide).
  - Attainment is a separate understanding ladder that improves control, move creation and reduces friction (sagaofgu.com/cultivation/attainment).
  - A combo move = one core tool that sets the effect + supports that amplify; costs more essence and strain (sagaofgu.com/cultivation/killer-moves).
  - A balanced kit covers attack, defence, healing, storage, movement, investigation (sagaofgu.com/cultivation/gu-set).
- **→ Implications for Robby:** Path Marks as per-Path scaling; use-based Mastery tiers; Path Friction wheel (allied/opposed); Weave = core + supports built in a Weave Loom; Kith role tags; Path Ground in Reaches; Party Arrays later.
- **Unknowns:** launch Path count (suggest 5); Weave Loom clarity on mobile.
- **Sources:** see the notes file.

### R-020c World structure, factions & progression pacing (done 2026-10-30)
Full table (10 findings → mirrors) and 30 sources: `research/notes/R-020c-world-factions-pacing.md`.
- **Findings:**
  - Five regions, each a distinct society (sects, clans, tribes, sea, desert) (sagaofgu.com/regions).
  - Regional walls suppress crossers, stronger ones more (sagaofgu.com/cultivation/regional-walls).
  - Clans = bloodline + elder council + mission/asset halls; heirs compete via rival elders (sagaofgu.com/factions/internal-affairs-hall).
  - Centre sects recruit by talent with entry/loyalty tests (reverend-insanity.fandom.com/wiki/Central_Continent).
  - Righteous vs demonic is sociopolitical, not good vs evil (reverend-insanity.fandom.com/wiki/Righteous_Path).
  - Recurring beast tides escalate to beast-king assaults (sagaofgu.com/cultivation/beast-tide).
  - Inheritance grounds: keyed pocket worlds with a testing spirit and restrictions (sagaofgu.com/inheritances/three-kings-inheritance).
  - Each rank is a large power jump; talent sets pace, resources speed it (sagaofgu.com/cultivation/aptitude).
- **→ Implications for Robby:** a society per Reach; Veils with Rank gate + damping; Clan hub (Elder Council, Mission Hall, stipends, rival elders); grey Clans vs Rogues; Wild Surge event; Legacy Vault dungeons with a Warden rule; steep Rank gap, Rank 3 milestone, Talent = soft cap.
- **Unknowns:** Wild Surge server load on mobile; pacing numbers (P-007).
- **Sources:** see the notes file.

### R-020d What fans value + GDD change list (done 2026-10-30)
Findings table, 25-item GDD change list for P-006 and 20 sources: `research/notes/R-020d-fan-values-gdd-changes.md`.
- **Findings:**
  - Fans love the long climb, a ruthless self-serving lead, and a rigorous system where strategy beats raw power (chapterchronicles.com; goodnovel.com).
  - Readers quit over darkness without catharsis and over-exposition (controllerandcape.com review).
  - Iconic: second-chance rewinds, brutal taming trials, signature combo moves (tvtropes.org Awesome/ReverendInsanity).
  - A fan card-game mod uses recipe drops → collect tools → synthesise at rest (steamcommunity.com workshop 3701087103).
  - Roblox cultivation games are small; players hate stat-click grind and sluggish combat (bloxed.gg; devforum.roblox.com).
  - An RI-named Roblox pet/meditate game fell from ~130 CCU to ~1 (robloxgo.com; trackers disagree).
- **→ Implications for Robby:** systems are the star; grim world but rewarding play; Rogue agency; Signature Weave; utility Kith in M1; depth + combat feel are the edge. See the notes for the full GDD change list.
- **Unknowns:** phone HUD load; conflicting CCU data.
- **Sources:** see the notes file.

### R-022 Stats, modifiers & damage maths (done 2026-10-30)
Draft model, curve table and 10 sources: `research/notes/R-022-stat-damage-math.md`; sim `research/sims/r022_curves.py`.
- **Findings:**
  - Additive "increased" vs multiplicative "more" buckets; more compounds (poewiki.net; poe2.dev).
  - A fixed damage pipeline keeps maths predictable (poedb.tw).
  - Hyperbolic armour K/(K+A) gives diminishing returns, no immunity (blog.lokkij.com; warcraft.wiki.gg).
  - Soft caps stop single-stat stacking (gamemechanicshoard.com).
  - MMOs add level-gap factors (TrinityCore; PSO2 NGS wiki).
- **→ Implications for Robby:** two buckets (Boost additive, Surge multiplicative, Surge cap ×3); pipeline Base × Potency × (1+ΣBoost) × ΠSurge → Guard → Friction in one tested `DamageMath` module; Guard K scales with attacker Rank; Marks hyperbolic (+30% at 60); no extra gap penalty. Sim: best/fresh DPS ≈ 2.95, TTK 10 s / 16 s / 26 s at +0/+1/+2 Rank.
- **Unknowns:** enemy tier numbers, Qi/Strain curves (P-007b); PvP fairness.
- **Sources:** see the notes file.
