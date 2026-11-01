# OPEN_CLOUD.md — testing on the real Roblox servers

The owner connected a PromptQL **custom integration** named `roblox-open-cloud` that holds a Roblox Open Cloud API key
for the Robby experience. Any session may use it to test on Roblox (confirmed again by S43, D-191). The key never
enters the VM or the repo: PromptQL injects it when a request goes through the integration proxy.

## IDs — main and separate test experiences
| Destination | Universe ID | Start Place ID (root place) |
|---|---|---|
| Main Robby experience — production | `10773761715` | `95587500384127` |
| Separate private Wind Step test — Sober testing only | `6958375460` | `121111456135560` |

Both destinations belong to Roblox owner `7738981129`. Keep them separate: never upload the isolated test harness to the main Robby place.
- Test IDs were supplied by the owner in `research/inbox/2026-11-01-test-destination.md`; S92 confirmed PRIVATE visibility, owner and exact root with a GET-only preflight on 2026-11-01. Empty-content status and publish-write permission remain unverified.
- Test publication was authorized separately, but still requires completed release tooling, fresh preflight, verified empty/owner-consented contents and write permissions. Use the test-only release path when ready, **not `scripts/publish.py`** (production).
- The ready-made `cloud_test.py` and `publish.py` commands below target **main Robby**, not the test experience. Recording these IDs authorizes no additional upload or publication.

## How to call it (from the VM, any language)
Base URL (the proxy prefixes the real `https://apis.roblox.com`):
```sh
B="$PROMPTQL_PLATFORM_API_URL/v1/integration/roblox-open-cloud/apis.roblox.com"
curl -s "$B/cloud/v2/universes/10773761715" -H "Authorization: Bearer $PROMPTQL_USER_JWT" \
  -H "X-PromptQL-Description: Robby: read universe info"
```
Always send `Authorization: Bearer $PROMPTQL_USER_JWT` and a one-line `X-PromptQL-Description` (shown to the owner in
the approval popup). Do not add an `x-api-key` header; the proxy does. API docs: https://create.roblox.com/docs/open-cloud

## Ready-made scripts (build on these, don't re-probe)
- `python3 scripts/cloud_test.py` — Rojo-build → upload `build/Robby.rbxl` as a **Saved** (unpublished) version → run all
  specs + `tests/cloud/smoke.luau` in the real engine via a Luau Execution task → print PASS/FAIL. Safe to run any time.
  `python3 scripts/cloud_test.py <version>` reuses an uploaded version.
- `python3 scripts/publish.py` — uploads a **Published** (live) version. **Only when the owner explicitly asks.**
- `uv run scripts/upload_anims.py build/anims/<name>.rbxm …` — uploads KeyframeSequence `.rbxm` files (from `lune run scripts/extract_anims.luau <kit.rbxm>`) as Animation assets under the owner; prints `name=assetId` (T-026c).
- `scripts/cloud_runner.py` — builds the Luau script that the execution task runs.

## Rules
- Run cloud tests **from `main` after `merge.sh`** (AGENTS §9), never from a session branch.
- Upload timeouts: use ≥ 600 s for the place upload (S12).
- If a call returns 401/403, the integration is not connected in this bot: ask the owner to connect `roblox-open-cloud`
  (don't ask for the key in chat).