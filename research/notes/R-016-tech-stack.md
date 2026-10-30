# R-016 — Tech for a high-quality action RPG on Roblox (S4, 2026-10-30)

Goal: a recommended stack with reasons, as input to P-004 (architecture). [n] marks a source. Model-memory items are labelled "(unverified)".

## 1. Findings
### Combat netcode
- Standard model: the client detects hits locally for instant feedback and sends a hit claim; the server validates and applies damage. [1][2][3]
- Server keeps a ring buffer of recent positions and timestamps, rewinds the target by the attacker's latency, and checks range, line of sight and cooldowns. [1][3][4]
- Roblox's Server Authority feature/docs describe server-authoritative techniques and network ownership pitfalls. [1][4][5]

### Animation & VFX (see R-013 §7)
- Start animations on the client at once; drive hit logic from animation markers; server hit detection with spatial queries, not `.Touched`; 2–4 frame hit-stop. [6][7][8]
- VFX are ParticleEmitter/Beam/Trail instances driven by code (R-015).

### Large maps & mobile
- StreamingEnabled with ModelStreamingBehavior = Improved, StreamOutBehavior = Opportunistic, StreamingMinRadius ~64, TargetRadius ~1024. [9][10]
- SLIM level-of-detail on static models cuts draw calls and memory. [9][11]
- Mobile budget: < 500 draw calls, < 500k triangles on screen, < 1.3 GB client memory (to run on 2 GB phones). [12][13]

### Libraries
- Data: ProfileStore for new projects; ProfileService is legacy. [14][15]
- Networking: ByteNet for general high-frequency use; Blink for typed, generated contracts; Zap a fast alternative. [14]
- Lifecycle: Trove + Signal are standard. [14]
- Frameworks: Knit is legacy and not recommended for new projects; prefer small modules. [14][16][17][18]

### Testing
- Pure-logic tests run locally with Lune (already in the repo).
- Luau Execution API (Open Cloud) runs Luau in a real place headlessly: ≤ 5 min per task, ≤ 10 concurrent tasks per place; returns logs. [19][20]
- CI pattern: Rojo builds `.rbxl` → upload → run Jest Roblox suites via Luau Execution (Roblox's place-ci-cd-demo; jest-roblox-cli). [21][22][23]

## 2. Recommended stack (input to P-004)

| Area | Choice | Reason |
|---|---|---|
| Project/tooling | Rojo + Rokit + StyLua + Selene + Wally (existing) | Headless, already working (T-001) |
| Game logic | Pure modules in `src/shared`, thin server/client wiring | Testable in Lune; matches AGENTS §4 |
| Combat | Client-predicted animation + hit claim; server validates with position history (rewind), range, cooldown | Responsive and cheat-resistant (server authority rule) |
| Hit detection | Server spatial queries / shape casts from animation markers | Reliable, avoids `.Touched` |
| Networking | Blink (typed contracts, generated code) — ByteNet as fallback | Typed contracts suit AI-written code; low bandwidth |
| Data | ProfileStore | Current standard, session locking |
| Lifecycle | Trove + Signal | Standard, small |
| Framework | None (no Knit) | Knit is legacy; small modules are clearer |
| World | StreamingEnabled (Improved, Opportunistic), SLIM LOD | Large maps on mobile |
| Budgets | < 500 draw calls, < 500k tris, < 1.3 GB memory | Mobile-first audience |
| Tests | Lune unit tests locally; Jest Roblox via Luau Execution in cloud (T-010) | Engine-level checks without Studio |

## 3. Unknowns
- Blink vs ByteNet decided by a small spike in T-phase.
- Exact rewind window and hit-claim tolerance — tune in testing.
- Cloud tests need a place ID and an Open Cloud key (existing blocker for T-010).

## 4. Sources
1. create.roblox.com/docs/en-us/projects/server-authority
2. create.roblox.com/docs/en-us/scripting/security/security-tactics
3. create.roblox.com/docs/en-us/projects/server-authority/techniques
4. devforum.roblox.com/t/server-authority-tech-deep-dive-engineering-insights/4624565
5. create.roblox.com/docs/en-us/scripting/security/network-ownership
6. kitsblox.com/blog/how-to-make-combat-system-roblox
7. roclicks.gg/resources/animation/hit-feel
8. devforum.roblox.com/t/the-basics-of-combat-games-hitboxes/3002930
9. create.roblox.com/docs/en-us/workspace/streaming/techniques
10. create.roblox.com/docs/workspace/streaming
11. create.roblox.com/docs/en-us/workspace/streaming/slim
12. devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146
13. mcrs-docs.gitbook.io/robloxvistools/articles/roblox-optimisation
14. github.com/officialmmt/OpenRoblox
15. mattqdev.github.io/blog/profileservice-datastore-in-roblox-studio-2026-developer-guide
16. devforum.roblox.com/t/is-knit-still-worth-using-in-2026-for-a-1-speed-escape-obby/4666518
17. devforum.roblox.com/t/recommending-a-framework/4628977
18. devforum.roblox.com/t/best-community-frameworks-and-architectural-patterns-for-clean-scalable-luau-code/4887691
19. create.roblox.com/docs/cloud/reference/features/luau-execution
20. devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185
21. github.com/Roblox/place-ci-cd-demo
22. github.com/roblox/jest-roblox
23. github.com/christopher-buss/jest-roblox-cli