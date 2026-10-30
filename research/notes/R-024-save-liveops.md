# R-024 Save data & live-ops flexibility (S8, 2026-10-30)

Goal: rules for adding systems without breaking saves (ARCHITECTURE §5, §9).

## 1. Findings
- **ProfileStore** is the successor to ProfileService. It uses session locking, so only one server writes a player's data at a time. That prevents data loss and dupes. Session-lock conflicts are resolved faster via MessagingService. Auto-save is every 300 s (fewer DataStore calls). It has built-in Luau types and is recommended for new projects [1][2][3].
- **`profile:Reconcile()`** fills keys missing from the template. It never renames or removes fields, so renames and type changes need explicit migrations [1][4][5].
- **Versioned saves:** put a version tag in every save. On load, run migrations in order (v1→v2→v3…) until the data is current [6][7].
- **ConfigService:** live variables and feature flags without server restarts, managed in Creator Hub or Open Cloud. `GetConfigAsync` returns global values; `GetConfigForPlayerAsync` returns per-player values and **experiments** (A/B variants) [8] (URL not captured this session; unverified link).
- Roblox DataStore best practices: budget the request limits, use retries, and never trust the client for purchased data [9][10].

## 2. Rules for Robby (D-047)
1. **One profile, one version field:** `schemaVersion` (int). `Migrations[n]` turns version n-1 into n. Each migration is a pure function in `src/shared/Save/Migrations.luau`, with a Lune test using a fixture of the old shape.
2. **Load order:** start session → run migrations → `Reconcile()` → validate (types, ranges) → build runtime state. Never run Reconcile before the migrations.
3. **Only add fields freely.** Renames, removals or type changes always go through a migration. Never reuse an old key with a new meaning.
4. **Store sources, not results:** Kith instances, Marks, Imprints, Bond and the currency ledger by tier — never derived stats (ARCH §9, D-044).
5. **Content ids are stable strings** (`kith.crescent`, `move.crescent_cut`). Content data lives in code (versioned in git), and saves only reference ids. A removed id maps to a replacement in `Content/Retired.luau`, so no save ever breaks.
6. **Timestamps, not counters,** for perishables, stipend banking (≤7 days, D-046) and Sanctum output; resolve lazily on load.
7. **Feature flags via ConfigService:** each new system ships behind a flag (default off) with a coded fallback if the config call fails. Tuning numbers (e.g. D-046 costs) are remote-configurable within coded min/max bounds. Experiments go per player.
8. **Server-only writes:** all currency and Kith changes are server-side and atomic. Trades go through a trade state that reverts on disconnect (D-045). Kith instances carry unique ids.
9. **Shared world state** (Singular Kith, contested Springs) goes in separate DataStores/MemoryStores, never inside player profiles.
10. **Tests:** `check.sh` runs migration tests from every past version to the current one; a release cannot raise `schemaVersion` without a fixture.

## 3. Unknowns
- ConfigService limits (request rate, value size) — check when T-010 builds the cloud pipeline.
- Open Cloud DataStore access for offline migrations/backups (P-008).

## 4. Sources
1. https://madstudioroblox.github.io/ProfileStore/ · https://madstudioroblox.github.io/ProfileStore/api/
2. https://github.com/MadStudioRoblox/ProfileService/
3. https://madstudioroblox.github.io/ProfileService/
4. https://devforum.roblox.com/t/profile-store-reconcile/3671975
5. https://xopoiii.github.io/KeepBlox/guides/schema-and-migrations/
6. https://framework.prayit.works/data/version-history/
7. https://devforum.roblox.com/t/migrating-data-to-use-profilestore-instead/3293896
8. https://create.roblox.com/docs/reference/engine/classes/ConfigService (unverified link)
9. https://create.roblox.com/docs/en-us/cloud-services/data-stores/best-practices.md
10. https://create.roblox.com/docs/en-us/cloud-services/data-stores/player-data-purchasing.md