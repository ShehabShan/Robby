ROBBY: ISOLATED WIND STEP TEST (NOT THE LIVE GAME)

This bundle is disabled by default and has no Robby saves, combat or startup.
It requires Roblox Studio on a supported computer. Do not publish it.
This is a diagnostic test, NOT a playable preview or accepted movement change.

1. Extract this zip and open WindStepTest.rbxl in Roblox Studio.
2. Keep avatar type R15. Enable Explorer, Properties and Output in View.
3. Select ServerScriptService > WindStepTest in Explorer. In Properties,
   set the attribute RunWindStep to true, and uncheck Disabled / check Enabled.
4. Press Play (F5), NOT Run. Use one player. Do not move. Wait up to two minutes.
5. After WIND_STEP_SUMMARY appears, switch to Server view. Select
   ServerStorage > WindStepEvidence and copy its Value (full JSON) to
   a plain-text file named WindStepEvidence.json BEFORE stopping Play.
   Upload that JSON plus WindStepTest.manifest.json to the Robby bot.
   If no summary appears, send the Output error instead.
6. Stop Play. Do not save over, upload or publish the production game.

If copying the Value is awkward, paste this into the SERVER Command Bar and
send every numbered chunk from Output (not just the summary):
local s=game.ServerStorage.WindStepEvidence.Value; for i=1,#s,3000 do print("WIND_STEP_JSON_CHUNK "..i.." "..s:sub(i,i+2999)) end
The developer must reconstruct full JSON from those ordered chunks first;
the intake command accepts JSON only, not an Output log.

WHAT THE RESULT MEANS
Even a first-slice PASS leaves death/replacement, supported-rate/final-partial
analysis and device/owner feel unresolved. dynamicsAccepted stays false.
Offline checks of JSON consistency do not prove Roblox execution. Do not
activate the new movement based on this bundle or a summary alone.

MANIFEST
WindStepTest.manifest.json identifies the exact source hashes and revision,
and the SHA256 of WindStepTest.rbxl. Keep it with your returned report.
Hashes detect accidental mismatches; they are NOT a signed attestation.

DEVELOPER REVIEW (matching source checkout + bootstrap tools)
python3 -B scripts/ingest_wind_step_evidence.py WindStepEvidence.json --manifest WindStepTest.manifest.json
Exit 0: FIRST_SLICE_REPORTED_PASS, not activation approval.
Exit 1: BLOCKED_OR_FAILED; retain the original JSON and inspect failures.
Exit 2: INVALID_OR_UNVERIFIABLE; resolve malformed/provenance mismatch first.
