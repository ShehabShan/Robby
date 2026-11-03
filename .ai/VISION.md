# VISION — owner direction (highest authority)

Owner: ShehabShan. The owner is non-technical and delegates technical and design decisions, but owns the direction below.

## Direction (2026-10-29)
1. The game is based on the web novel **Reverend Insanity**. Within IP limits (D-014), this means an original world inspired by it.
2. The quality bar is **Rell Seas**, a Roblox game.
3. It is developed headlessly by AI sessions with 50 OLU each (AGENTS.md).
4. Order of work: Research → Planning → owner approval → Building.
5. 3D content: the bot uses Blender in the VM. The owner can create 3D assets using multiple sites and offers to make needed models when given a detailed description (owner, 2026-11-01; verbatim: `research/inbox/2026-11-01-owner-3d-model-capability.md`). Future asset planning can request models from the owner with a detailed brief. Owner-provided files go in `assets/source/`. Art details are settled in R-015 and P-003, so they don't block starting.

6. **Long-term, one thing at a time (owner, 2026-10-31, D-206):** this is a serious multi-year game, not a quick project; any number of sessions is fine. Build little by little: refine, rework and polish what exists, add only what is absolutely necessary, and expand only when the owner says the current part is good enough. Never build many systems at once to ship fast.
7. **Endgame-ready backend, no endgame yet (owner, 2026-10-31, D-207):** do not implement endgame (Ascendant, Ranks 6–9) now, but keep server code and data schemas flexible enough to add it later without reworking the backend.

## Owner ideas
None yet. R-010 adds an entry for each file in `research/inbox/`:
date, file name, and the owner's key points in their own words.
- **2026-10-30** `research/inbox/2026-10-30-ri-structure-and-first-ability.md`: "The structure should be similar to RI. It will be open-world, but there will also be a good number of systems aligned with RI." Rell Seas mirrors One Piece (Haki, fruit) — "we can also work around it." Order: a very short research (1–2 sessions), a plan (1–2 sessions), then a few build sessions to create the first proper ability — "a popular GU that has some shine move" — to test whether headless development can really build a Roblox game (no Studio access). **IP flag:** Rell Seas uses One Piece names directly (takedown risk, R-012/R-013); we mirror RI systems with our own names (D-023, D-025).
- **2026-10-30** `research/inbox/2026-10-30-gu-ability.md`: "Research one Gu in depth and turn it into the first proper ability: good visuals, good range coverage. R1 (left click) attack + special moves on Z, X, C. Research must be in depth; the final quality should be very goo…"
- **2026-10-30** `research/inbox/2026-10-30-multi-session-branches.md`: "Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly. Har…"
- **2026-10-30** `research/inbox/2026-10-30-no-publish-now.md`: "Don't need to upload to roblox now. I will be going away for few hour. so do the normal work and push."
- **2026-10-30** `research/inbox/2026-10-30-owner-directive-list.md`: "Owner note: treat as a directive, not the source of truth. Think critically and pick the best elements of the novel for the game. Process every point in ONE session (R-027). Rank of Gu, rank of Gu Master, and how Gu r…"
- **2026-10-30** `research/inbox/2026-10-30-owner-fidelity.md`: "You still have 17 OLU left. Do work for 12 OLU, anything that doesn't conflict with the next task and can polish the system. Then push. Note: You are a world-class Roblox game designer, programmer, and engineer. And y…"
- **2026-10-30** `research/inbox/2026-10-30-owner-notes-s7.md`: "Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly. Har…"
- **2026-10-30** `research/inbox/2026-10-30-owner-p006-approval.md`: "Owner replied 'Yes' in chat to: 'Approve the P-006 plan so building can start next session?' (15:35 +06). This approves `.ai/P-006-summary.md` plus the S8 changes (D-042…D-048)."
- **2026-10-30** `research/inbox/2026-10-30-owner-r021-prereq.md`: "Before the R-021, can we do anything for it to be more robust when data-driven ability system building start. Maybe one session for any prerequisite work before we start the R-021. It's just my suggestion, take the de…"
- **2026-10-30** `research/inbox/2026-10-30-owner-r027-verdicts.md`: "'Each point gets a verdict (adopt, adapt, park or reject)' -> Evaluate each point with a verdict (Adopt, Adapt, Salvage, Park, or Reject). Prioritize playability above all else—what works in a novel doesn't always tra…"
- **2026-10-30** `research/inbox/2026-10-30-playtest-v11.md`: "Cut do damage the dummy now. it feel responsive but it follow the camera not the mouse pointer for pc. We can work with the costs and cooldowns later. it's good."
- **2026-10-30** `research/inbox/2026-10-30-publish-now-and-version-numbers.md`: "Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly. Har…"
- **2026-10-30** `research/inbox/2026-10-30-publish-request.md`: "If you can publish the game, do it. Upload the game using the roblox-open-cloud for me to test it in Roblox."
- **2026-10-30** `research/inbox/2026-10-30-r15-movement.md`: "Owner uploaded `R15 Movement System.rbxm` (walking system) and asked to add it to the game as a task. File: `assets/source/R15 Movement System.rbxm`. Task: T-026."
- **2026-10-30** `research/inbox/2026-10-30-research-depth.md`: "I was thinking of doing in-depth research. Is the current research good? I wanted that the system should be solid and flexible from start. What do you think? No need to worry about sessions. I can run many fresh sessi…"
- **2026-10-30** `research/inbox/2026-10-30-roblox-ids.md`: "Universe ID: 10773761715 Place ID: 95587500384127 Provider ID: roblox-open-cloud or roblox-open-cloud-2"
- **2026-10-30** `research/inbox/2026-10-30-sprint-shiftlock-no-dash.md`: "Check, we added sprint in left shift, but clicking the left shift do shift lock and clicking the control also do shift lock. I want left shift for sprint (run) and for now, let's remove the dash system. we will have n…"
- **2026-10-30** `research/inbox/2026-10-30-studio-ok-and-research.md`: "(Verbatim, except one sentence naming a specific AI model, left out at the owner's request.) > No need for a Robby.rbxl file. The ability is working inside Roblox Studio. Way to go. We can really build a game using Pr…"
- **2026-10-31** `research/inbox/2026-10-31-focus-direction.md`: "1)How many task are there in the repo. 2)Is the game structures enough to Focus on working on a gu ability properly. 3)Can we check out a skill to see if it improve our quality. 4)I Thik we need to Focus on at a think…"
- **2026-10-31** `research/inbox/2026-10-31-kith-state-inventory.md`: "I don't know anything about dormant and tired. You should add the details in the inventory. if the kith is Dormant or Tired (mean if it can't be use), then it should't available for add to the slot before we feed it.…"
- **2026-10-31** `research/inbox/2026-10-31-rimeshard-direction-approved.md`: "Reply to: 'Approve this direction and prototype left-click first?' Recommended direction in that message: sharp, hand-shaped ice with deliberate attack poses (option A, faceted frost). Verbatim owner message: Yes"
- **2026-10-31** `research/inbox/2026-10-31-rimeshard-quality-direction.md`: "<agent_mention /> Add a task for next session that we will heavily work on Rimeshard to make it better. Doesn't matter how long it take, we will make it a proper ability. It look shit now. We have blox fruit for refer…"
- **2026-10-31** `research/inbox/2026-10-31-slot-abilities.md`: "Fix some issues: 1) Rimeshard should be one ability, which we can put onto one of the 3 slot available. Eg: slot 2. When player selected that slot two (the one we put the Rimeshard), then player can use it ability. 2)…"
- **2026-10-31** `research/inbox/2026-10-31-v20-playtest.md`: "1. Crescent Strike's Z move should move to **right click** when Crescent is selected. 2. With Crescent selected, Z works. With **Rimeshard** selected, **none** of its moves work. 3. Switching between slots 1, 2 and 3…"
- **2026-10-31** `research/inbox/2026-10-31-wind-step-rework.md`: "Wind Step isn't done or good. it look and function terrible. so you can better it if you want as you like."
- **2026-11-01** `research/inbox/2026-11-01-S106-publication-approval.md`: "2026-11-01T17:15:39.438Z, verbatim: <agent_mention /> I approve ONE complete overwrite and publication of the exact S106 corrected test package identified by the pins below to test universe 6958375460 / root place 121…"
- **2026-11-01** `research/inbox/2026-11-01-S91-cloud-delivery-request.md`: "can't you directly upload it via 'roblox-open-cloud' intrigation. why I need to manually add .rbxl file."
- **2026-11-01** `research/inbox/2026-11-01-centralize-test-ids.md`: "<agent_mention /> Can we save the test also in where the Main experience is saved so it will be more convenient for new session."
- **2026-11-01** `research/inbox/2026-11-01-corrected-test-build.md`: "You prepare the corrected test build in here."
- **2026-11-01** `research/inbox/2026-11-01-linux-isolated-experience.md`: "<agent_mention /> Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and foll…"
- **2026-11-01** `research/inbox/2026-11-01-owner-permission-waiver.md`: "2026-11-01T09:42:10Z (verbatim, bot mention omitted): > The test experience I gave you doesn't contain anything important, you can overwrite and do anything with it. and the api key that's store in 'roblox-open-cloud'…"
- **2026-11-01** `research/inbox/2026-11-01-s102-continuation.md`: "Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly. Har…"
- **2026-11-01** `research/inbox/2026-11-01-s106-version4-test-report.md`: "Owner message (verbatim): test result from the S106 test build: '{'cleanup':true,'error':'ServerScriptService.WindStepTest:327: case failed: travel-auto\nServerScriptService.WindStepTest:327 function runCase\nServerSc…"
- **2026-11-01** `research/inbox/2026-11-01-s108-version5-test-report-full.md`: "{'cleanup':true,'runCompleted':true,'passed':106,'matrixPassed':true,'dynamicsAccepted':false,'remaining':['death/original-root replacement','supported rate variation and final-partial analysis','device/owner feel (se…"
- **2026-11-01** `research/inbox/2026-11-01-s109-version5-test-report.md`: "Verbatim owner message (bot mention omitted). NOTE: the paste is TRUNCATED by the chat client inside the second result (`travel-player`, at `'x':0.8`); the full matrix rows beyond that point were not received. Summary…"
- **2026-11-01** `research/inbox/2026-11-01-sober-test-publish.md`: "<agent_mention /> I mean can't we publish the test experice for me to test it using Sober on Linux"
- **2026-11-01** `research/inbox/2026-11-01-test-destination.md`: "<agent_mention /> Can you use this: Universe ID: '6958375460' Start Place ID: '121111456135560'"
- **2026-11-01** `research/inbox/2026-11-01-test-single-block.md`: "Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly. Har…"
- **2026-11-01** `research/inbox/2026-11-01-wind-step-travel-auto-result.md`: "<agent_mention /> @27 Bot Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby. Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md…"
- **2026-11-02** `research/inbox/2026-11-02-asset-prompt-guide.md`: "The site name is 'https://app.ludo.ai/'. Also add a negative prompt section for vfx-crescent-hit. Can't we also have a file that explains how the new session writes the asset prompt, cause new session doesn't know how…"
- **2026-11-02** `research/inbox/2026-11-02-crescent-ranks-and-kith-scaling.md`: "we will not do any task from the AGENT.md. check assets folder, you will see many crescent assets is available. We will ignore Rimeshard now and build the crescent kith now. My initial plan is for crescent kith to hav…"
- **2026-11-02** `research/inbox/2026-11-02-version6-test-report.md`: "Owner message: 'Haven't we already test this 106 case before. also explain shortly what wind step do and it role in the game and how much is it build and does all the 106 test only for wind step alon?' result of the t…"
- **2026-11-02** `research/inbox/2026-11-02-version7-test-report.json`: "JSON test report; keys: cleanup, runCompleted, passed, matrixPassed, dynamicsAccepted, remaining"
- **2026-11-02** `research/inbox/2026-11-02-version7-test-report.md`: "Owner uploaded the report as a pasted-text file (PromptQL bot ed1828b3-108b-4a9b-a6ae-9d7776920c76, artifact `pasted-text`) with no message text. Exact bytes retained in `2026-11-02-version7-test-report.json` (74943 B…"
- **2026-11-03** `research/inbox/2026-11-03-crescent-art-pick.md`: "1) Choose 4 for the slash. Also, for the twin crescent, choose 2 blades (choose 3 for the golden one and 4 (the usual) for the blue one). 2) Also generate a new image for the 3rd blade with the reference of 3rd image…"
- **2026-11-03** `research/inbox/2026-11-03-crescent-sound-pick.md`: "Owner message, verbatim: '3, 1, 1, 2' Answer to: which variant (1-3) of each Crescent Cut sound, order cast, hit, hum, thud. Meaning: cast = 3, hit = 1, hum = 1, thud = 2."
- **2026-11-03** `research/inbox/2026-11-03-third-ring-pick.md`: "3rd blade: B and Ring: B. Additionally, the ring B should have a spin animation. So, within those 3 seconds, it remains around the player and spins around the player."
- _(S135, D-421: entries above for the other 2026-10-30…11-03 files are the opening lines of each file, auto-extracted; the file is the source of truth.)_

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