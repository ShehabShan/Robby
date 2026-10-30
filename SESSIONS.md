# How to run a Robby session (owner guide)

Each session is a **new bot** in PromptQL. The bot reads this repo to find out where the project is,
does one or two tasks, saves everything to GitHub, and tells you what's next. You don't need to understand the code.

## Start a session
1. In PromptQL, start a new bot. For research sessions, pick a model that is strong at research in the model selector.
   For building sessions, pick a strong coding model.
2. Paste this message:

Use the **same message every time**. The bot works out on its own where the last session stopped.

> @Enasn Bot Continue the Robby project from where the last session left off. Repo: https://github.com/ShehabShan/Robby.
> Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly.
> Hard limit: 50 OLU. Stop new work at 43 and finish saving by 45. Keep your final report short.

3. Approve the pop-ups. They are for the VM, GitHub pushes and web searches.
4. At the end, the bot tells you what it did and what's next. If it asks you a question, answer it in that bot.

## Run several sessions at the same time
You can start two or more bots at once with the same message. Each bot claims a different task in `.ai/CLAIMS.md`,
works on its own branch (`session/S<n>`) and merges into `main` when it finishes. Nothing extra is needed from you.
If a bot is cut off, the next bot finds its branch and finishes merging it.
How many at once: count the tasks with no `after` in `.ai/STATE.md` → **Parallel lanes** (5 on 2026-10-30).
Extra bots find no free task and stop after about 5 OLU. Each bot can use up to 50 OLU.

## Give the bot your ideas (research material)
Any of these works:
- Add them to the start message, after the text above: "My ideas: …". The bot saves them word for word in `research/inbox/`.
- Upload files (notes, images, documents) to the bot's chat and say "add these to the research inbox".
- Add a text file to the `research/inbox/` folder on GitHub's website.

Your ideas are the highest authority. The research and design work around them, and the bot tells you
if an idea conflicts with copyright or Roblox rules.

## Give the bot 3D models, images or sounds
Upload them to the bot's chat and say "add these to assets/source". You can also add them to `assets/source/` on GitHub. Tell the bot where they came from (made by you, bought, free), because licenses matter on Roblox. The bot can also create 3D models itself with Blender.

## The phases
1. **Research:** the bot studies Reverend Insanity, Rell Seas, similar Roblox games, copyright, how to make art and assets, and the technology.
2. **Planning:** you pick one of 3 game concepts. The bot then writes the design, art plan, technical plan and roadmap.
3. **Your approval.**
4. **Building:** small, tested pieces, one or two per session. You can play-test them in Studio at each milestone, using `PLAYTEST.md`.

## If something goes wrong
- **The session was cut off:** start a new session as usual. At most one step is lost.
- **The bot seems confused:** tell it "re-read AGENTS.md and .ai/STATE.md".
- **You want to change direction:** tell the bot. It records your decision in `.ai/VISION.md` and `.ai/DECISIONS.md`.