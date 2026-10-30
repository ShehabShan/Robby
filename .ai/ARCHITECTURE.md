# ARCHITECTURE v2 (P-008, S9, 2026-10-30; v1 P-004, S6)

Inputs: R-016 (stack), GDD v1, SPIKE.md / T-004 (proven pattern), ART.md (budgets). Supersedes the obby-era doc (D-019).

## 1. Stack
| Layer | Choice | Why |
|---|---|---|
| Toolchain | Rokit-pinned Rojo, Wally, StyLua, selene, luau-lsp, Lune (`rokit.toml`) | Headless, file-managed (D-001) |
| Language | Luau `--!strict` everywhere | Type gate in `check.sh` |
| Networking | **Blink** (IDL → generated typed remotes); plain RemoteEvents only in the spike | Compact and typed (R-016); ByteNet is the fallback |
| Data | **ProfileStore** (session-locked) | Replaces ProfileService (R-016) |
| Utilities | Trove (cleanup) and Signal | Small, no framework (Knit is legacy) |
| Framework | None: plain modules with `start()` | Fewer moving parts for AI sessions |
| World | StreamingEnabled with opportunistic stream-out; SLIM LOD | Mobile-first (R-016) |

## 2. Data model (default.project.json)
- `ReplicatedStorage.Shared` ← `src/shared`: pure rules and config (no services).
- `ReplicatedStorage.Packages` ← `Packages/` (Wally, once deps are added).
- `ServerScriptService.Server` ← `src/server`: authority and wiring.
- `StarterPlayer.StarterPlayerScripts.Client` ← `src/client`: input, VFX, UI.

## 3. Module map v2 (Kith GAS-lite, D-044, D-052; schemas in `.ai/SCHEMAS.md`)
| Area | Shared (pure, tested) | Server | Client |
|---|---|---|---|
| Config | `Config` (tunables), `Flags` | `ConfigService` (bounded remote overlay) | — |
| Types & content | `Types`, `Content/*` (Kith, Moves, Effects, Weaves, Paths as data), `Registry` | — | — |
| Stats | `Stats` (one aggregation), `DamageMath` (R-022), `Tags` | — | — |
| Abilities | `Effects` (apply/stack/tick), `Moves` (validate, costs, cooldowns), `Deliveries/*` (Projectile, Melee, Self, System, Zone, Channel first) | `AbilityService` (CastRequest → simulate → Effects) | `AbilityInput`, `FxRegistry` |
| Combat core | `Combo`, `Parry`, `Dash` (as Moves + Effects) | `CombatService` (rewind buffer, sanity checks, rate limits) | `CombatInput`, `HitFeel` |
| Cultivation | `Stages`, `Crucible`, `Loom` (Weave validation, Friction), `Upkeep`, `Binding`, `Loadout` (Rank lock, Qi Reserve) | `ProgressionService` | Journal, Loom, Crucible UI |
| Economy | `Wallet` (tier ledger), `Shop`, `Stipend` | `EconomyService` (only currency writer, analytics) | Shop UI |
| Enemies | `AI/Brain`, `Telegraph` | `EnemyService`, `BossService` | Telegraph VFX |
| Data | `ProfileSchema`, `Migrations`, `Retired` | `DataService` (ProfileStore) | — |
| World & onboarding | `Zones`, `Onboarding` (beats, funnel steps) | `WorldService`, `OnboardingService` | Hints, prompts |
| Viewer | — | sends tags in `EntityState` | `Viewer` (renders by own Seek/Path Sense) |
- Rule: logic lives in `src/shared` and takes dependencies as arguments; services are thin wiring. Content is data; a new Kith adds files under `Content/` only.

## 4. Networking & authority
- **v2 contract:** the Blink remotes in `.ai/SCHEMAS.md` §9 replace the list below (D-050).
- Client sends **intent only**: cast(moveId, aimDir), attack(chainStep), dash(dir), parry().
- The server validates: unit-vector aim, cooldown, Qi, alive state, rate limit. It then simulates projectiles and blockcasts itself (T-004 pattern).
- Melee uses **rewind**: the server keeps ~1 s of target positions and checks range and line of sight at `now − ping`, capped at 250 ms.
- The server broadcasts cosmetic events (CastFx, HitFx). The caster's client skips its own duplicate.
- The server is the only writer of Qi, cooldowns, HP, progression and currency.

## 5. Data (ProfileStore)
- **v2:** the Profile type in `.ai/SCHEMAS.md` §7 supersedes this line.
- One profile per player (v1): `{ version, talent, rank, stage, marks{path}, shards, jade, kith[{id, rank, fed}], loadout, journal{recipes, weaves}, settings }`.
- `version` plus ordered migrations in `ProfileSchema`. Autosave and release on leave; never trust client data.
- Robux purchases go through `ProcessReceipt` with an idempotent receipt log in the profile.

## 6. Sample replacement
- Done in T-004: obby `RoundState` and HUD were removed; the spike wiring is in `src/server/{Abilities,Dummy}` and `src/client/{AbilityInput,CrescentFx}`.
- T-002 refactors the spike into the module map (§3), adds Wally deps (Blink, ProfileStore, Trove, Signal) and keeps `check.sh` green.

## 7. Testing plan
1. **Lune unit tests** (`tests/*.spec.luau`) for every shared module — part of `check.sh`.
2. **Place inspection** (`tests/inspect_place.luau`) on the Rojo-built place — part of `check.sh`.
3. **Cloud tests** (T-005b/T-010): upload the place via Open Cloud, run Luau Execution tasks (≤ 5 min, ≤ 10 concurrent) with Jest Roblox in the real engine. Blocked on the key header fix.
4. **Owner playtests** on a private test place, only with explicit OK (T-006); feedback goes to `research/inbox/`.

## 8. Budgets (mobile-first, R-016 / ART §5)
< 500 draw calls, < 500k triangles in view, ≤ 1.3–1.5 GB client memory, 60 fps on a mid-range phone; ≤ 50 KB/s network per player.

## Scripts
- `scripts/bootstrap.sh`: idempotent setup (Rokit tools, type defs, Wally, git proxy in the PromptQL VM).
- `scripts/check.sh`: the quality gate (format, lint, sourcemap, types, tests, build, inspect), then `CHECK: PASS|FAIL`.
- `scripts/olu.sh`: the OLU meter. A fresh bot counts from 0; `start` sets a baseline for a reused bot.
- `scripts/search.sh "q" [chars]`: web search through PromptQL's Exa integration, with a capped answer and sources.
- `scripts/save.sh "ID: msg"`: commit, rebase and push, then show the OLU meter.
- `scripts/blender-setup.sh`: installs Blender 4.2 LTS headless (idempotent, ~350 MB, art tasks only).
  - Run: `blender -b --factory-startup -P art/blender/<script>.py -- build/art`

## Conventions
- Pure modules take dependencies as arguments; no `game:GetService` in `src/shared`.
- Server modules require shared via `require(ReplicatedStorage.Shared.X)` (resolved by the Rojo sourcemap for type checking).
- Entry scripts require their own modules via `script.X`.

## 9. Notes for P-008 (R-027, S8) — folded into `.ai/SCHEMAS.md` (S9)
- **Kith = species data + owned instance.** Species: id, rank, Path, role, tags, moves, food id. Instance: uid, speciesId, satiety, strain, wounded/dormant flags, bond, obtainedAt. Never store derived stats.
- **Character:** `cores` is a list (default 1) so a Twin Core needs no migration; stats include Will; Imprints are a list of {path, slot}.
- **Rules as checks:** Rank lock at equip time; Friction cap (−20%) and Qi Reserve in the stat calc (R-022).
- **Timestamps, not ticks:** perishables, Sanctum output and cooldown-type timers store an expiry/start time and resolve lazily.
- **Currency ledger** keyed by tier (Shards now, later tiers); exchange is one-way upward (R-023).
- **Global uniqueness** (Singular Kith, Ascendant) needs a MemoryStore/DataStore lock; not before Ascendant.
- **Per-viewer info** (Seek layer, Path Sense): the server sends tags; the client decides what to render.
- **Saves (R-024, D-047):** `schemaVersion` + ordered pure migrations (Lune-tested from every past version) → Reconcile → validate; add fields freely, never reuse keys; stable string content ids with a Retired map; new systems behind ConfigService flags with coded fallbacks and bounded tuning (`research/notes/R-024-save-liveops.md`).
- **Combat netcode (R-025, D-050):** intent-only `CastRequest(moveId, aim, seq)`; client predicts cosmetics only; server hit check rewinds a 20 Hz/1 s position buffer by min(ping estimate, 250 ms), ignoring client timestamps; per-hit sanity checks (alive, i-frames, range +4 studs, line of sight, cooldown/Qi/Strain); token-bucket rate limits; UnreliableRemoteEvent only for aim/FX (`research/notes/R-025-combat-netcode.md`).

## 10. Analytics (R-026, R-023)
- One onboarding funnel step per GDD §8 beat; economy events for every faucet and sink; Rank/Stage ups as custom events (`.ai/SCHEMAS.md` §10).
