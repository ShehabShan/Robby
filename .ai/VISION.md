# VISION — owner direction (highest authority)

Owner: ShehabShan. The owner is non-technical and delegates technical and design decisions, but owns the direction below.

## Direction (2026-10-29)
1. The game is based on the web novel **Reverend Insanity**. Within IP limits (D-014), this means an original world inspired by it.
2. The quality bar is **Rell Seas**, a Roblox game.
3. It is developed headlessly by AI sessions with 50 OLU each (AGENTS.md).
4. Order of work: Research → Planning → owner approval → Building.
5. 3D content: the bot uses Blender in the VM. The owner will also supply 3D models later, in `assets/source/`. Art details are settled in R-015 and P-003, so they don't block starting.

## Owner ideas
None yet. R-010 adds an entry for each file in `research/inbox/`:
date, file name, and the owner's key points in their own words.

## Background
Starting points for R-011 to R-013. Facts marked (search) come from a quick web search on 2026-10-29 and still need deeper verification.
- *Reverend Insanity* (蛊真人):
  - (search) A Chinese xianxia web novel by Gu Zhen Ren, serialised on Qidian 2012–2019.
  - (search) It was removed in 2019 and is unfinished. The publisher is Qidian (China Literature).
  - (search) An official English translation (2,334 chapters) is on Webnovel. No official game adaptation was found.
  - Sources: en.wikipedia.org/wiki/Reverend_Insanity · webnovel.com/book/7996858406002505
  - (unverified) The protagonist, Fang Yuan, is ruthless and is reborn by a time-reversing Gu.
  - (unverified) "Gu" are living creatures that grant powers. Gu Masters refine, feed and combine them.
  - (unverified) Cultivation uses an aperture and primeval essence, with ranks 1–9. The tone is dark and amoral.
- *Rell Seas*:
  - (search) An open-world naval RPG by **RELL Games**, the studio behind *Shindo Life*, inspired by *One Piece*.
  - (search) Progression is non-linear and comes from activities (fishing, sailing, blacksmithing), not level grinding.
  - (search) Features: ship customisation, faction combat (Pirates, Marines, Bounty Hunters), and stamina/parry-based combat with build paths (fruits, Haki, fighting styles).
  - Sources: rellseas.org/guides/game-overview · rellseaswiki.com/systems/
  - → Rell Seas is itself an anime-IP-*inspired* original game, which is the same model as D-014.

## Known risks (resolved in research and planning)
1. **IP:** the novel is owned by its author and publisher. Using it directly risks takedowns (R-012).
   The default is an original world inspired by its themes and mechanics (D-014).
2. **Content maturity:** the novel's tone (killing, sacrifice, cruelty) must fit Roblox policy and the chosen maturity label (R-017).
3. **Art quality headlessly:** AI sessions can build code, systems, UI and procedural worlds.
   Rell Seas-level models, animations and VFX need an asset pipeline. That means artists,
   Creator Store assets or AI generation, possibly plus owner steps in Studio (R-015, P-003).
4. **Scope:** games like Rell Seas are built by teams over long periods.
   Plan a small **vertical slice** at full quality first (D-018).

## Quality bar
Defined measurably in P-003, using the R-013 teardown. It covers:
- combat feel
- animation and VFX
- UI polish
- world art
- performance targets (including mobile)