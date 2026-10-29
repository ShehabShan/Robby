# How to run a Robby session (owner guide)

Each session is a **new bot** in PromptQL. The bot reads this repo to find out where the project is,
does one or two tasks, saves everything to GitHub, and tells you what's next. You don't need to understand the code.

## Start a session
1. In PromptQL, start a new bot. For research sessions, pick a model that is strong at research in the model selector.
   For building sessions, pick a strong coding model.
2. Paste this message:

> @Enasn Bot Continue the Robby project. Repo: https://github.com/ShehabShan/Robby.
> Provision a VM, clone the repo through the GitHub integration, then read AGENTS.md and follow it exactly.
> Hard limit: 50 OLU. Stop new work at 43 and finish saving by 45.

3. Approve the pop-ups. They are for the VM, GitHub pushes and web searches.
4. At the end, the bot tells you what it did and what's next. If it asks you a question, answer it in that bot.

## Give the bot your ideas (research material)
Any of these works:
- Add them to the start message, after the text above: "My ideas: …". The bot saves them word for word in `research/inbox/`.
- Upload files (notes, images, documents) to the bot's chat and say "add these to the research inbox".
- Add a text file to the `research/inbox/` folder on GitHub's website.

Your ideas are the highest authority. The research and design work around them, and the bot tells you
if an idea conflicts with copyright or Roblox rules.

## The phases
1. **Research:** the bot studies Reverend Insanity, Rell Seas, similar Roblox games, copyright, how to make art and assets, and the technology.
2. **Planning:** you pick one of 3 game concepts. The bot then writes the design, art plan, technical plan and roadmap.
3. **Your approval.**
4. **Building:** small, tested pieces, one or two per session. You can play-test them in Studio at each milestone, using `PLAYTEST.md`.

## If something goes wrong
- **The session was cut off:** start a new session as usual. At most one step is lost.
- **The bot seems confused:** tell it "re-read AGENTS.md and .ai/STATE.md".
- **You want to change direction:** tell the bot. It records your decision in `.ai/VISION.md` and `.ai/DECISIONS.md`.