# R-026 Retention & first session (S9, 2026-10-30)

## 1. Benchmarks
- 2025 Roblox benchmark report: session length predicts retention. Games with sessions under 6 min often have D1 < 10% and D7 < 2%. Games with sessions over 19 min reach double-digit D1. The 95th percentile holds about 8% at D7 and about 2% at D30. [investgame 2025 report]
- A "good" D1 is roughly 10–15%, and platform averages are quoted at about 12–15%. Benchmarks vary by genre, so compare against similar experiences in Creator Analytics. [investgame; devforum "good day 1 retention"; Creator Hub retention docs]
- Retention is a cohort from the first play date (D1/D7/D30). Big influxes of new users temporarily lower it. [Creator Hub retention docs]

## 2. What the algorithm rewards (2025 Recommended for You)
- Six 7-day per-user signals: qualified play-through rate, playtime (capped at 60 min/day), play days, spend days, Robux spent, and intentional co-play days (joins via invites, parties or private servers). [devforum discovery posts 3587441, 3557533]
- Sessions with friends are on average 1.9× longer than solo sessions. Party lets up to 6 users move between experiences together. [Roblox newsroom 2024-12; devforum Party post]
- → Return days and co-play matter as much as one long first session.

## 3. Onboarding practice
- Get players into the core loop fast and teach only the essentials. Use contextual or just-in-time tutorials that fire when a feature becomes relevant. Use timed hints only after the player struggles. Prefer visuals over text, which reads better on small screens and is easier to localise. [Creator Hub onboarding + onboarding-techniques docs]
- A goal should be clear within 60 s, and progress should be felt within 5 min. [bloxtest FTUE guide]
- Rigid, unskippable, front-loaded tutorials cause early drop-off. One developer reported that 41% of players left within 30 s of the tutorial. Other causes are long loading (preload with ContentProvider), small text and non-mobile controls. [devforum 3814365, 3147818, 3064458]
- Measure every step with funnel events (`AnalyticsService:LogOnboardingFunnelStepEvent`), then fix the biggest drop first. [Creator Hub analytics; devforum 3064458]
- "Three times rule": a core action is repeated successfully three times before it is considered learned. Offer a skip for experienced players. [Meta growth insights; Supersonic FTUE; Apple onboarding for games]

## 4. What keeps RPG players (D7/D30)
- D7: clear short-term goals and daily quests completable in about 15–45 min. D30: guilds, trading, co-op challenges, and content updates every 2–4 weeks. [bloxg retention guide; Creator Hub quest design] (secondary sources)
- Rell Seas opens with a small task (loot a shipwreck), then runs a linear starter quest through the first town (tools, fishing). It ends with a timed boss, "Defeat Big Boss Man". [rellseaswiki guide]

## 5. Changes for Robby (→ GDD §8, D-051)
- §8 becomes a **first 20 minutes** plan: first hit by 0:30, a stated goal by 1:00, Stage progress on the first kill, and the first (mini-)boss (Academy Rank test) by about 18 min.
- The Opening Rite is cut to ≤ 20 s, comes after the first hit, and can be skipped on replay. Dummies are replaced by real weak beasts. Each core action is used 3 times. Hints appear only when the player is stuck.
- Return hooks are rewards, not punishments: a first daily bounty, the Binding grove's rare spawn, and the Academy stipend. There is no streak loss.
- Co-play: a one-time, non-blocking invite prompt with a co-op bonus after the first parry fight. Party-friendly spawn.
- Instrumentation: one funnel step per beat. This becomes an M1 requirement for P-008/T-tasks.
- Targets (owner-visible, to verify in playtests): D1 ≥ 15%, D7 ≥ 5%, average session ≥ 20 min.

## 6. Unknowns
- Exact RPG-genre benchmarks (Creator Analytics only after launch). Real drop-off points (only after playtests). Whether a 20-min first session fits on low-end mobile without load stalls.