# T-044a — separate published Sober test destination (S92, 2026-11-01)

## Result and boundary
Owner explicitly authorizes publishing a separate test experience for Sober on Linux, NOT replacing Robby. A published running Player server can exercise physics that Saved/Luau Execution cannot. The existing Studio bundle does not run there: its Studio guard and server-only result export must not simply be removed. T-044b owns that adapter; d2b2 still owns actual evidence/repairs. No destination has been supplied or created; no upload performed.

## Verified sources
- [Official universe API reference](https://create.roblox.com/docs/cloud/reference/features/universes.md), retrieved 2026-11-01: supported Open Cloud universe methods are get/update/message/restart; no CreateUniverse endpoint is documented. The Universe schema mentions templateRootPlace/CreateUniverse, but that is NOT proof of a callable API-key method.
- [Official creation/publishing instructions](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places.md): creation is documented through Studio. Private experiences are playable by their creator and permitted playtesters; publishing a version does not require making the experience public. Do not tell the owner a browser-only Create button is verified.
- [Universe creation API discussion](https://devforum.roblox.com/t/v1-universe-creation-api-is-not-documented/4355237) and [API coverage request](https://devforum.roblox.com/t/feature-request-better-api-coverage-for-universe-related-endpoints-iac/4869921): legacy creation route is cookie-authenticated, not the connected Open Cloud API-key route. No account cookie requested or legacy creation attempted.
- Read-only Open Cloud GET confirmed Robby belongs to users/7738981129 and is PRIVATE; root is universes/10773761715/places/95587500384127. Existing integration is working. This is not permission evidence for any new universe.

## Owner's minimal unblock
Supply an EMPTY separate experience's Creator Dashboard link (universe ID) and start-place link. Use an existing empty experience or have a trusted collaborator with Studio create **Robby Test** under the owner's account/appropriate ownership. Keep it private. The owner need not install Studio just to join the published test through their existing Sober setup; Sober compatibility is not certified here.
Extend the stored Open Cloud connection's resource permissions to the TEST universe: universe read and place publishing write. A dedicated test-only credential/connection is preferable defense in depth. Never paste a key or .ROBLOSECURITY cookie in chat. No authority to publish to another person's universe is inferred.

## Implemented preparation
`scripts/test_target.py <target.json>` performs GET-only validation. Config fields: schema=1, kind="Robby isolated published test", universeId/placeId/ownerUserId as canonical decimal STRINGS. Refuses either production ID, wrong owner, missing/extra fields, non-private remote state, root/universe mismatch and any network failure. No production fallback and no upload option. Returned status is TARGET_VERIFIED_ONLY with publishReady=false and dynamicsAccepted=false. No real config checked in because IDs are unknown. Use a fresh preflight immediately before any later upload; a stored receipt is not authorization.

8 offline regression groups cover both production-ID combinations before network, malformed IDs/config, foreign/public/mismatched remote, network errors, immutable inputs and duplicate JSON. Full CHECK:PASS. Production publish.py is unchanged and must NOT be used for the isolated test.
