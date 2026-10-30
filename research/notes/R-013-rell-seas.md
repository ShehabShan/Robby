# R-013 — Rell Seas teardown (S4, 2026-10-30)

Rell Seas is Robby's quality benchmark. Goal: learn what "Rell Seas quality" means in measurable terms, for P-003.
[n] marks a source. Model-memory items are labelled "(unverified)".

## 1. Facts
- Open-world pirate action RPG, inspired by One Piece, by RELL Games (led by brothers RELLsin and RELLbad). [1][2][3]
- Pre-release: years in development, missed 2025 targets, expected 2026. Irregular update cadence; long internal development before public showcases. [3][4][5]
- An early build ("RELL Seas Legacy") page: ~591,752 visits, ~19,203 likes, ~6 CCU on 2026-10-30. [6][7]
- Team size and budget: not public.

## 2. Core loop & progression
- Non-linear: almost any activity (combat, exploration, seafaring, fishing, cooking, mining, woodcutting, crafting, navigation) gives progress. [1][8][9]
- Level + a 5-star progress bar; when it fills, the player ranks up and picks a new passive or ability. [8][9]
- At character creation the player bonds with one weapon class (Light, Medium, Heavy, Ranged) for an XP bonus. [8][10]
- 39 documented weapons and 38 bosses, from starter bosses to multi-phase raids. [10][11]
- Races: Human, Mink, Fish-man, Skypiean, Cyborg (One Piece IP). [1][12]

## 3. Combat
- Skill-based and movement-heavy, inspired by Devil May Cry air-ladder combos. [1][13]
- M1 chain of 5 hits; an uppercut before the last hit launches the target into an air combo. Attack speed depends on the style. [13][14]
- Parry: precise timing before impact; a miss leaves you open. A "spec" parry, charged by dealing damage, opens a guaranteed combo window. [13][14]
- Dash: side dashes have i-frames, front/back don't; shared cooldown. [13][15]
- Evade bar: fills as you take damage, spent to break out of combos with i-frames. Posture is managed in combat. [13][16]
- Layers: weapon class + special powers + an aura/willpower layer + fighting styles. [1][13]
- Bosses have telegraphed attack patterns; there are dynamic sea events. [1]

## 4. World
- 4 seas, 7 depth levels, about 28–30 islands, including sky and underwater locations. [9][12][17]

## 5. Monetisation & social
- No gamepasses on sale yet. Developers state no pay-to-win: cosmetics (character, ship), race/stat rerolls, extra character slots. [18][19][20]
- Crews for naval coordination and faction fights; free-for-all Battlegrounds; ranked 1v1 duels; private servers expected. [8][21]

## 6. Reception
- Praised: cinematic VFX and custom animation, visible quality jumps between showcases, boss entrances, world design. [22][23][24]
- Criticised: early "mediocre" power visuals (later reworked), long delays. [25][26]
- Risk: built on One Piece IP, which can be taken down at any time (see R-012). We copy its quality, not its IP. [27][28]

## 7. Combat-feel technique (general Roblox practice)
- Play the attack animation on the client instantly; the server validates and decides the hit. [29][30]
- Drive hit logic from animation markers (HitFrame, CancelOpen, Recovery). [29][31]
- Server hit detection with spatial queries / shape casts, not `.Touched`, with small latency tolerance. [29][32]
- Hit-stop: freeze animation and local effects for 2–4 frames on impact; plus camera shake that doesn't drift. [29][31]

## 8. Draft quality bar for P-003 (measurable)
1. Input → visible attack animation in ≤ 1 frame on the client (client-side start).
2. Every hit decided on the server (spatial query), with ≤ 150 ms latency tolerance.
3. M1 chain of 5 hits, with a launcher into air combos.
4. Timed parry with a clear window (target ~150–200 ms, tune in testing) and a punish on a miss.
5. Directional dash with i-frames on at least one direction, and a cooldown.
6. A combo-breaker resource so no one is stun-locked forever.
7. Every hit has hit-stop (2–4 frames) + VFX + SFX + small camera shake.
8. Every enemy attack is telegraphed (wind-up animation or ground marker ≥ 0.4 s).
9. Each boss has ≥ 2 phases and an entrance moment.
10. At least 3 build layers (e.g. weapon class, creature loadout, affinity/path).
11. Rank-up gives a meaningful choice (pick 1 of 2–3 passives/abilities).
12. Several non-combat activities that also give progress.
13. A unique custom animation set per weapon class (no default Roblox animations in combat).
14. No pay-to-win: monetisation is cosmetics, slots and rerolls only.

## 9. Unknowns
- Exact frame data and timings; post-release retention; team size.
- Most facts are from fan wikis and guides about a pre-release game; they may change.

## 10. Sources
1. rellseas.org/guides/game-overview
2. roblox.com/games/118832659999543/RELL-Seas-Legacy
3. progameguides.com/roblox/rell-seas-sneak-peaks-ultimate-guide-to-upcoming-features-gameplay/
4. bloxinformer.com/wikis/rell-seas/
5. youtube.com/watch?v=BGCI9Ml-4q4
6. rovitals.com/game/91433030196741
7. roregister.com/group/11020595
8. rellseaswiki.com/systems/
9. rellseaswiki.com/systems/progression-system/
10. rellseaswiki.com/weapons/
11. rellseaswiki.com/bosses/
12. rellseas.org/guides/game-overview (races, islands)
13. rellseaswiki.com/fighting-styles/combat-mechanics/
14. pickscribe.com/v/FBI0uN13L4E/
15. rellseaswiki.com/fighting-styles/
16. rellseaswiki.com/systems/ui-explanation/
17. rellseaswiki.com/posters/
18. rellseaswiki.wiki/systems/RELL-Seas-gamepasses
19. reddit r/RELLseas (via redlib.vanillax.me)
20. rellseas.fandom.com/wiki/Monetisation
21. rellseaswiki.wiki/systems/RELL-Seas-crews
22. progameguides.com/roblox/rell-seas-best-one-piece-roblox-game-ever/
23. destructoid.com/official-rell-seas-movie-3-trailer-analysis/
24. tryhardguides.com/rell-seas-game-page-has-been-revealed/
25. summarize.ing/video-52737-RELL-Seas-Just-Made-INCREDIBLE-CHANGES-
26. mobilematters.gg/guides/roblox/roblox-rell-seas-release-date-and-latest-development-updates
27. polygon.com/gaming/499820/one-piece-roblox-ip-infringement/
28. github.com/Roblox/creator-docs (ip-licensing/creators.md)
29. kitsblox.com/blog/how-to-make-combat-system-roblox
30. devforum.roblox.com/t/combat-system-with-rollback/3685525
31. roclicks.gg/resources/animation/hit-feel
32. devforum.roblox.com/t/the-basics-of-combat-games-hitboxes/3002930