# roblox-brain skills (vendored)

Source: https://github.com/TabooHarmony/roblox-brain @ ceee4aa (v2.3.1), MIT (see LICENSE). Vendored by T-032 (D-205).
How to use (AGENTS.md §4): before domain work, pick the matching skill below and read its `SKILL.md`.
Open `references/full.md` only when SKILL.md points there for the detail you need (it is long; costs OLU).
Repo rules (AGENTS.md, DECISIONS.md, VISION.md) outrank skill advice. Update: re-copy `skills/` from upstream, regenerate this index.

| Library | Skill | Use when | Path |
|---|---|---|---|
| core | `roblox-architecture` | Use when adding, moving, refactoring, or reviewing Roblox feature ownership, code layout, dependencies, startup, or client-server boundaries. | `core/roblox-architecture/` |
| core | `roblox-collaboration-mode` | Load FIRST for any Roblox task: build, change, fix, debug, review, audit, or plan. Sets initiative and which decisions need the user. | `core/roblox-collaboration-mode/` |
| core | `roblox-data` | Use when writing, changing, debugging, or auditing Roblox player saves: DataStore, ProfileStore, session locks, schemas, migrations. | `core/roblox-data/` |
| core | `roblox-luau-core` | Use when writing, editing, or debugging any Luau: tables, control flow, string patterns, scope, closures, and errors ported from JS/Python. | `core/roblox-luau-core/` |
| core | `roblox-luau-patterns` | Use when writing or refactoring Roblox Luau modules, object lifecycles, signals, task scheduling, pcall, and cleanup. | `core/roblox-luau-patterns/` |
| core | `roblox-luau-types` | Use when adding or fixing Luau type annotations: generics, unions, narrowing, strict mode, sealed tables, module type exports, typed metatables. | `core/roblox-luau-types/` |
| core | `roblox-networking` | Use when adding, changing, or auditing RemoteEvents/RemoteFunctions: argument validation, rate limits, server authority, exploit prevention. | `core/roblox-networking/` |
| core | `roblox-performance` | Use when profiling or fixing Roblox performance: low FPS, lag, memory, network load, slow phones, hot paths. | `core/roblox-performance/` |
| core | `roblox-security` | Use when auditing or hardening Roblox code against exploits: authority, remotes, economy, purchases, and DataStore flows. | `core/roblox-security/` |
| core | `roblox-server-data` | Use when building or fixing Roblox cross-server data: OrderedDataStore leaderboards, MessagingService, MemoryStore, world state, seasons. | `core/roblox-server-data/` |
| design | `roblox-analytics` | Use when adding, changing, or auditing Roblox analytics: AnalyticsService events, economy, funnels, onboarding traces, rate limits. | `design/roblox-analytics/` |
| design | `roblox-game-design` | Use when designing or reworking a Roblox game: core loop, tutorial/FTUE, levels, economy, retention phases, juice, grind, curation. | `design/roblox-game-design/` |
| design | `roblox-growth-design` | Use for Roblox growth: diagnosing stats, discovery, retention, onboarding, experiments, LiveOps, thumbnails, and packaging. | `design/roblox-growth-design/` |
| design | `roblox-monetization` | Use when adding, changing, or auditing Roblox purchases: GamePasses, Developer Products, subscriptions, private servers, policy checks. | `design/roblox-monetization/` |
| design | `roblox-player-psychology` | Use when designing or reviewing player-behavior mechanics: first minute, rewards, streaks, daily rewards, pricing, RNG/pity, community. | `design/roblox-player-psychology/` |
| gameplay | `roblox-animation-vfx` | Use when adding, changing, or fixing Roblox animations, particles, beams, trails, tweens, camera shake, or other visual effects. | `gameplay/roblox-animation-vfx/` |
| gameplay | `roblox-audio` | Use when adding, changing, or fixing Roblox audio: playback, spatial sound, music, sound effects, SoundGroups, or dynamic effects. | `gameplay/roblox-audio/` |
| gameplay | `roblox-building` | Use when building or editing geometry, maps, props, or generated assets with MCP or standalone Luau. | `gameplay/roblox-building/` |
| gameplay | `roblox-camera` | Use when scripting or fixing Roblox camera behavior: CFrame placement, screen raycasts, first/third-person, shoulder views, cutscenes. | `gameplay/roblox-camera/` |
| gameplay | `roblox-gui` | Use when building or fixing Roblox menus, HUDs, shops, dialogs, or UI that must work on phones, tablets, desktop and console. | `gameplay/roblox-gui/` |
| gameplay | `roblox-input` | Use when handling Roblox touch, gamepad, keyboard, mouse or motion input, on-screen action buttons, or cross-platform action binding. | `gameplay/roblox-input/` |
| gameplay | `roblox-lighting` | Use when setting up or changing Roblox lighting, atmosphere, day/night cycles, or post-processing effects. | `gameplay/roblox-lighting/` |
| gameplay | `roblox-localization` | Use when adding or fixing Roblox translation: localization tables, auto-translation, locale-specific content, or region detection. | `gameplay/roblox-localization/` |
| gameplay | `roblox-npc-ai` | Use when creating or fixing Roblox NPCs, bots or enemies: pathfinding, state machines, line of sight, spawns, AI update loops. | `gameplay/roblox-npc-ai/` |
| gameplay | `roblox-physics` | Use when building or fixing Roblox physics: vehicles, ragdolls, projectiles, elevators, constraints, forces, network ownership. | `gameplay/roblox-physics/` |
| tools | `roblox-cloud` | Use for Roblox Open Cloud: API keys, OAuth 2.0, webhooks, scopes, token lifecycle, DataStore or messaging access from outside the game. | `tools/roblox-cloud/` |
| tools | `roblox-publish-checklist` | Use before publishing or updating a Roblox experience to run evidence-backed release gates and a pre-release audit. | `tools/roblox-publish-checklist/` |
| tools | `roblox-studio-mcp` | Use when working in Roblox Studio through MCP: editing scripts or scenes, generating assets, playtesting, screenshots, or input. | `tools/roblox-studio-mcp/` |
| tools | `roblox-tooling` | Use when setting up or fixing Roblox tooling: Rojo, Wally, pesde, Selene, StyLua, Lune, Rokit, luau-lsp, tests, or CI/CD. | `tools/roblox-tooling/` |
