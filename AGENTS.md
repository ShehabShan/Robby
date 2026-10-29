# AGENTS.md — read this first, every session

**Robby** (codename) is a Roblox action RPG inspired by the web novel *Reverend Insanity*. The quality benchmark is
the Roblox game *Rell Seas*. It is built **headlessly** (no Roblox Studio) by AI sessions in PromptQL VMs.
- `.ai/VISION.md` holds the owner's direction. It is the highest authority.
- The owner is not technical and has delegated all technical and design decisions to you. Make them, log them in
  `.ai/DECISIONS.md`, and explain results to the owner in plain language.
- The repo is the **only** memory between sessions. If it isn't in the repo, the next session won't know it.

## 0. Session contract (non-negotiable)
- **Start without waiting.** The owner sends the same generic message every session (SESSIONS.md). Find where the last session left off and continue on your own.
- **Finding where we left off:**
  1. Any task marked `doing` in `.ai/TASKS.md`: resume it from its "Resume from:" note.
  2. Otherwise, take NEXT in `.ai/STATE.md`.
  3. If STATE looks stale, `git log --oneline -5` is the truth.
- **At least one committable piece of work per session.** That means a finished task, or a finished sub-task that meets its own AC, saved with `save.sh`.
  Close-out edits alone don't count.
- **Size every task to fit one session.**
  - An S task is about 30 OLU of work or less (boot ~5 + work ≤30 + close-out ~5 + buffer).
  - If a task might not fit, split it **before** starting into sub-tasks (`R-011a`, `R-011b`, …), each with its own AC and S-sized. Save the split, then do the first sub-task.
- **If a task grows mid-way:** at 30 OLU, stop expanding.
  - Move the rest into a new sub-task with a "Resume from:" note.
  - Bring what's done up to that sub-task's AC, then commit it.
- **Blocked on the owner** (choices in P-001/P-006, missing keys):
  - Put the question in the short report, then do the next unblocked task.
  - If there is none, do prep work that can be committed, such as drafting the next deliverable.
  - Never end a session with zero useful commits.

## 1. OLU budget (hard rule)
- Every session has a hard cap of **50 OLU**. Reaching it kills the session mid-work.
- **At 43 OLU, stop new work and do close-out. Close-out must start by 45 OLU at the latest.**
  The remaining 5–7 OLU are insurance for updating `.ai/` files, committing and pushing.
- Measure, don't guess. Append `bash scripts/olu.sh` to commands you already run; the script itself costs no OLU.
  - Fresh bot: the meter counts the whole bot from 0.
  - Reused bot (an existing VM): run `bash scripts/olu.sh start` first.
- The meter prints what to do: `OK` → `FINISH CURRENT STEP` (30+) → `WRAP UP` (43+) → `EMERGENCY` (45+: one-line STATE update + `save.sh`, nothing else).
- The main costs are big file reads and long command output, so keep both short. Read only the files the task needs.
  Each step costs more as the context grows.

## 2. Phases (gated, in order)
1. **Research** (R-tasks): findings go in `.ai/RESEARCH.md`, and long notes in `research/notes/`.
2. **Planning** (P-tasks): concept, GDD, art/asset plan, architecture, roadmap. Ends with **owner approval (P-006)**.
3. **Building** (T-tasks): only after P-006 is done.

The current phase and NEXT task are in `.ai/STATE.md`. Never start a later-phase task early.
R-010 (process the owner's inbox) may run in any phase.

## 3. Boot (do exactly this)
The VM must be provisioned first (`provision_vm`, default size). Each `run_shell` starts fresh,
so begin every command with `cd /workspace/Robby && export PATH="$HOME/.rokit/bin:$PATH"`.

Fresh bot (no `/workspace/Robby`). This routes git through PromptQL's GitHub integration; no tokens are needed:
```sh
git config --global url."$PROMPTQL_PLATFORM_API_URL/v1/integration/__github/github.com/".insteadOf "https://github.com/"
git config --global credential."$PROMPTQL_PLATFORM_API_URL".helper '!f() { test "$1" = get && printf "authtype=Bearer\ncredential=%s\n" "$PROMPTQL_USER_JWT"; }; f'
git config --global user.name "Enasn Bot"; git config --global user.email "bot@users.noreply.github.com"
cd /workspace && git clone -q https://github.com/ShehabShan/Robby.git && cd Robby && bash scripts/bootstrap.sh >/dev/null 2>&1; bash scripts/olu.sh
```
Reused bot: `cd /workspace/Robby && git pull -q --rebase && bash scripts/olu.sh start`.

Then read **`.ai/STATE.md` only**. If the owner's message contains ideas or material, save it **verbatim** to
`research/inbox/YYYY-MM-DD-<topic>.md` and run `save.sh` before anything else.
If the owner asks for something specific, it outranks STATE's NEXT. Add it to TASKS.md first, then do it.
Use the next session number (`S<n>`) after the newest entry in `.ai/SESSION_LOG.md`.

## 4. Work loop
1. Take the NEXT task from STATE.md, and read its entry in `.ai/TASKS.md`.
   - On the first save of the task, mark it `doing`, with a one-line "Resume from:" note, in both TASKS.md and STATE.md.
     Then a cut-off session leaves an accurate trail.
   - Size check and splitting: see §0.
   - Start a second task only if you are under 25 OLU.
2. **Research**: run `bash scripts/search.sh "question" [chars]`. It does a web search with a capped answer and sources, typically 3–8 searches per task.
   - Write each task up in RESEARCH.md using this format:
     `### R-0XX Title (done YYYY-MM-DD)` → **Findings**, with a source on each fact → **→ Implications for Robby** → **Unknowns** → **Sources**.
   - Keep each section to 25 lines or fewer. Put longer material in `research/notes/R-0XX-<topic>.md` and link it.
   - Label anything from model memory "(unverified)".
3. **Planning**: write the deliverables named in the P-task. Choices go to the owner in plain language:
   2–3 options plus your recommendation. Log the owner's pick as a decision.
4. **Building**:
   - Logic goes in **pure modules** in `src/shared` (no `game:GetService`), with Lune tests in `tests/*.spec.luau`.
   - Server and client scripts are thin wiring.
   - `bash scripts/check.sh` must print `CHECK: PASS` before saving. `stylua src tests` auto-formats.
5. **Save after every working step**: `bash scripts/save.sh "R-011: short message"`. It commits, rebases, pushes, and prints the OLU used.

## 5. Close-out (at 43 OLU, or when the task is done)
1. `.ai/STATE.md`: phase, NEXT task, blockers, and the last check result.
2. `.ai/TASKS.md`: update statuses. A half-done task stays `doing` and gets a "Resume from:" note.
3. `.ai/SESSION_LOG.md`: add one entry at the top (6 lines or fewer, including the OLU used).
4. Append new decisions to `.ai/DECISIONS.md`. Don't re-open logged decisions unless the owner asks.
5. `bash scripts/save.sh "<ID>: close-out"`.
6. Send the owner a **short report** of 5 lines or fewer, in plain language: what was done, what's next, and any owner action.
   - Details belong in the repo, not in chat. Output tokens are expensive (§6 "Output").
   - Give more detail only if the owner asks.

## 6. Rules
- **IP (D-014):** the world is original, *inspired by* Reverend Insanity. Never use its names, characters, places,
  plot or text in game content. Never commit chapters or long quotes; summaries and short quotes in research notes are fine.
- **Owner input:** `research/inbox/` files are never edited or deleted. Owner intent outranks research,
  and research outranks AI suggestions.
- **Code:** `--!strict` in every `src` file. Tabs and StyLua formatting. Rojo is the source of truth; nothing exists only in Studio.
- **Server authority:** the server decides combat hits, progression and currency. Never trust the client.
- **Secrets:** never commit them. Roblox Open Cloud keys come from a PromptQL custom integration and are never pasted in chat.
- **Publishing:** don't publish to Roblox unless the owner explicitly asks.
- **Web search:** use `__exa-web-search` (in `search.sh`). If it is unavailable, try `__gemini-web-search`.
- **Output (saves OLU):** output tokens are the most expensive part of a session.
  - Send at most one short acknowledgement at the start and one short final report. No progress chatter.
  - Never paste file contents, diffs or logs into chat.
  - Pipe command output through `tail` or `head`.
  - Write files once, then use small `edit_file` edits instead of rewriting whole files.

## 7. Map
- `.ai/VISION.md`: owner direction, owner ideas, known risks
- `.ai/STATE.md`: phase, NEXT task (short)
- `.ai/TASKS.md`: backlog by phase, with acceptance criteria
- `.ai/RESEARCH.md`: research findings (`research/notes/` for long notes)
- `.ai/GDD.md`: game design (written in P-002)
- `.ai/ARCHITECTURE.md`: code structure, scripts, tech stack
- `.ai/DECISIONS.md`: decision log
- `.ai/SESSION_LOG.md`: session history (newest first)
- `.ai/archive/`: superseded docs (do not use)
- `research/inbox/`: owner material
- `SESSIONS.md`: the owner's guide to running sessions
- `scripts/`: `bootstrap.sh`, `check.sh`, `olu.sh`, `search.sh`, `save.sh`, `blender-setup.sh` (on demand, only for art tasks)
- `art/blender/`: Blender Python scripts that generate assets into `build/art/`
- `assets/source/`: owner-provided models, textures and audio (never edit; listed in `INDEX.md`)

## 8. Human testing (Studio, on the owner's machine)
`rokit install && rojo serve`, then connect the Rojo plugin in Studio and press Play.