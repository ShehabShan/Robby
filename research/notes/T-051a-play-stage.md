# T-051a play-mode TEST publication (S117)

- Build: `python3 scripts/build_wind_step_play.py --target research/releases/S100-wind-step-target.json` -> `build/play-test/`.
- Stage (clean synced main only): `python3 scripts/stage_wind_step_play.py --stage --target research/releases/S100-wind-step-target.json --enable-local-test` -> `build/play-stage/` (manifest + RBXL, prints both SHA256).
- Verify: `python3 scripts/stage_wind_step_play.py --verify --manifest M --manifest-sha256 PIN --place P`.
- Publish: existing `transact_wind_step_publication.py` with consent/review records binding the exact manifest/place pins (kind-dispatched verify, D-374). One shot; never retry a consumed consent.
- Only the final card's main revision and pins may be approved; rehearsal hashes never count.
- Owner check after publish: Start the TEST place, press R (PC) or Dash (mobile); report distance/feel, wall stops, cooldown.
