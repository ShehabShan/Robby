# Contributing to Robby

Thanks for helping! Robby is mostly built by an AI bot in PromptQL sessions. The bot reviews and merges pull requests (PRs) at the start of each session.

## Setup (once)
1. Clone the repo, then run `bash scripts/bootstrap.sh` to install the tools (Rojo, Lune, StyLua, Selene, Wally).
2. To play your changes in Roblox Studio, run `rokit install && wally install && rojo serve`, connect the Rojo plugin, and press Play.

## Flow
1. Make a branch: `git checkout -b <your-name>/<short-topic>`.
2. Make your change. Run `stylua src tests` to format it.
3. `bash scripts/check.sh` must print `CHECK: PASS` before you push.
4. Push the branch and open a PR to `main`. Say in a few lines what you changed and how you tested it.
5. Never push to `main` directly, and never commit secrets (API keys, cookies, passwords).

## Good areas to help with
- **Content:** new abilities and Kith, following `src/shared/Content/Crescent.luau` as the example.
- **Studio assets:** models, VFX, animations and sound. Rojo is the source of truth, so anything you make must be saved into the repo, not only in Studio.
- **Research notes:** in `research/notes/`.
- **Playtesting:** play the published game and write feedback (what felt good, what felt bad, any bugs) in a PR or send it to the owner.

## Please leave these to the bot
`src/shared/Config.luau`, `net/remotes.blink`, server services (`src/server/*Service.luau`), `init` scripts, and everything in `.ai/`.

## Rules
- Every `src` file starts with `--!strict`. Tabs, StyLua formatting.
- The server decides hits, progression and currency. Never trust the client.
- The world is original and only *inspired by* Reverend Insanity: never use its names, characters, places, plot or text.