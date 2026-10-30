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
- **Sources:** see the notes file (28 sources).
## R-014 … R-018
Not started. See TASKS.md.