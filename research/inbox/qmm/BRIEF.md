# Brief for Gemini — Qing Mao Mountain extraction (Robby, research R-032 prep)

You are running in this bot as **Gemini 3.1 Pro Preview**. The owner will upload the Reverend Insanity chapters set on **Qing Mao Mountain** (about 200 chapters). Your only job is to **read them and produce structured research notes**. A later model (Claude) will verify them, reason over them and plan the game map, so give **facts, not game design**.

## Hard rules
1. **Only extract.** Don't edit the GitHub repo, don't start any other Robby task, don't plan the map, and don't suggest gameplay.
2. **Use your own words.** Paraphrase everything. Quote only names, Gu names, titles or a key term, and never more than ~10 words in a row. No passages copied from the chapters.
3. **Cite every fact** with its chapter number(s), e.g. `(ch 12, 47)`. If a fact is unsure or only implied, mark it `[implied]`. If two chapters contradict each other, write `CONFLICT: ...` with both chapter numbers.
4. **Merge repeats.** The chapters repeat a lot. Record each item once and add the chapter numbers where it comes up again, e.g. `(ch 3; repeated 15, 22, 40)`. Don't write one entry per mention.
5. **Names:** give the English name used in the upload, plus pinyin if it's shown, e.g. Gu Yue Fang Yuan, Moonlight Gu.
6. **Be complete over pretty.** Small spatial details matter most: what is next to what, uphill or downhill, how long a walk takes, what buildings exist, and what the terrain, plants and weather are like.

## How to work
- Work in **batches of about 40–50 chapters**, in chapter order. Store **one markdown artifact per batch**:
  - identifier `qmm-batch-01`, `qmm-batch-02`, ...
  - title `QMM notes ch X–Y`
  - store with `metadata={'text': {'content_type': 'text/markdown'}}`
- If the upload is too large to finish in one run, finish the batches you can, store them, and say in chat which chapter to continue from.
- After all batches are done, store **one index artifact**: identifier `qmm-index`, title `QMM index + key chapters`.

## Sections in every batch artifact (use these exact headings)
1. **Chapter map:** one line per chapter: `ch N: main event (≤15 words) | location | filler? yes/no`.
2. **Places and layout:** every named or described place on or around the mountain, such as the Gu Yue village, the academy, the clan halls, Gu storage, the cliffs, caves, springs, forests, roads, and the Xiong and Bai villages. For each one give:
   - where it is relative to other places
   - its terrain and elevation
   - its buildings and size
   - who uses it
   - the visual details (materials, plants, light, smells)
   - chapter numbers
3. **Factions and power:** the Gu Yue, Xiong and Bai clans. For each give:
   - leaders and elders by role
   - their ranks and strength
   - their territory and resources
   - how they relate to each other (alliances, feuds, trade)
   - how the clan is run inside: the academy, the stipend, missions, punishment, inheritance
4. **People:** the important characters. For each give their role, clan, rank, key Gu, personality in a few words, where they are usually found, and what happens to them in this batch.
5. **Gu and cultivation:**
   - every Gu that appears: its rank, what it does, its cost or what it eats, how it's refined or used, and who uses it
   - how rank 1–3 cultivation works in this arc: aperture, primeval essence, grades, and how breakthroughs happen
   - money and primeval stones: prices and how they're earned
6. **Creatures and nature:** wild Gu, beasts and wolf packs (e.g. during a wolf tide). Give where they live, how strong they are, how they behave, and when they show up.
7. **Events and conflicts:**
   - fights, missions, tests, ceremonies, disasters and inheritance trials
   - for each: where it happens, who is involved, what it costs the people involved, and how it turns out
   - mark the ones that change the setting (a place destroyed, a power shift)
8. **Mood and time:** the season and weather by chapter range, the time of day, what daily life looks like, and the overall tone (bleak, ruthless, quiet...).
9. **Recurring objects:** items, documents, landmarks and rules that keep coming back.
10. **Open questions:** things the text leaves unclear that matter for drawing a map, like distances, directions or how many people live there.

## The `qmm-index` artifact
- **Timeline:** the whole arc in 15–30 lines, each with a chapter range.
- **Place list:** every place from all batches merged into one list, with a rough layout described in words (no images), plus the main chapters for each place.
- **Faction summary:** three short blocks plus how the three clans relate.
- **Key chapters for close reading:** the **10 chapters** that hold the most map, layout or setting detail, each with one line on why. Claude will read these in full later.
- **Filler ratio:** roughly what share of the chapters are filler or repeat old material.
- **All CONFLICT and Open-question items**, collected in one place.

## When done
Post one short chat message: which artifacts you stored, the chapter range they cover, and anything that went wrong. Then stop. The owner will switch the model back to Claude for verification and planning.
