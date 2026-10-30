# T-005 — Headless verification report (S6, 2026-10-30)

| Check | Result |
|---|---|
| `check.sh` (format, lint, strict types, Lune tests, `rojo build`) | PASS |
| Local place inspection (`tests/inspect_place.luau` on `build/Robby.rbxl`): 9 scripts/modules in the expected places, obby sample gone | PASS |
| Cloud test (Open Cloud upload + Luau Execution: dummy HP drops by 20) | NOT RUN — blocked (T-005b) |

## Cloud blocker
- Universe 10773761715 / place 95587500384127 (owner inbox 2026-10-30).
- `roblox-open-cloud` integration: `GET cloud/v2/universes/10773761715` returns **401 "Failed to read token."**. Same result through the VM proxy and `run_http`.
- Likely cause: the integration sends the key as `Authorization: Bearer …`, but Roblox API keys must be sent in an **`x-api-key`** header.
- `roblox-open-cloud-2` is not enabled in the project (404).
- Owner fix: edit the integration so the key is sent as header `x-api-key`. The key needs these permissions on this experience:
  - universe/place read + write (place publishing)
  - Luau execution

## Cloud result (T-005b, S6, 2026-10-30)
- Owner switched the key to an `x-api-key` header and fixed the key; universe/place GET now 200.
- `scripts/cloud_test.py` uploaded `build/Robby.rbxl` as **Saved** version 3 (not published) and ran `tests/cloud/smoke.luau` as a Luau Execution task.
- Place Scripts do **not** auto-run in a Luau Execution session; the smoke test starts `ServerScriptService.Server.{Dummy,Abilities}` itself.
- **CLOUD: PASS** — dummy + humanoid exist, 3 remotes, `damageFor(1) == 20`, dummy HP 200 → 180.
