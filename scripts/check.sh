#!/usr/bin/env bash
# The single quality gate. Prints a short PASS/FAIL line per stage; shows only the
# tail of output for failing stages. Exit code 0 = everything passed.
set -u
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
fail=0

run() {
	local name=$1
	shift
	local out
	if out=$("$@" 2>&1); then
		echo "PASS $name"
	else
		echo "FAIL $name"
		echo "$out" | tail -n 20
		fail=1
	fi
}

run net blink net/remotes.blink
run format stylua --check src tests
run lint selene src
run sourcemap rojo sourcemap default.project.json -o sourcemap.json
run types luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=sourcemap.json --ignore="**/Net.luau" src
run tests lune run tests/run.luau
run client-input lune run tests/client_input.luau
run rime-timing lune run tests/rime_timing.luau
run cast-dispatch lune run tests/cast_dispatch.luau
run cast-lifecycle lune run tests/cast_lifecycle.luau
run cast-receipt-client lune run tests/cast_receipt_client.luau
run cast-character-client lune run tests/cast_character_client.luau
run cast-contact-engine lune run tests/cast_contact_engine.luau
run cast-world-tree lune run tests/cast_world_tree.luau
run cast-delivery-engine lune run tests/cast_delivery_engine.luau
run cast-owner-engine lune run tests/cast_owner_engine.luau
run combat-contact-client lune run tests/combat_contact_client.luau
run wind-step-driver lune run tests/wind_step_driver.luau
run wind-step-probe-runner python3 -B tests/wind_step_probe_runner.py
run m1-authoring lune run tests/rime_m1_assets.luau
mkdir -p build
run build rojo build default.project.json -o build/Robby.rbxl
run inspect lune run tests/inspect_place.luau
run wind-step-studio-build python3 -B scripts/build_wind_step_test.py
run wind-step-studio-map rojo sourcemap wind-step-test.project.json -o build/wind-step-sourcemap.json
run wind-step-studio-types luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=build/wind-step-sourcemap.json tests/studio
run wind-step-studio-lint selene tests/studio
run wind-step-studio lune run tests/wind_step_studio.luau
run wind-step-intake-format stylua --check scripts/wind_step_evidence.luau
run wind-step-evidence-intake python3 -B tests/wind_step_evidence_intake.py
run isolated-test-target python3 -B tests/test_target.py
run owner-test-transport lune run tests/owner_test_transport.luau
run owner-test-transport-lint selene tests/published/OwnerTestTransport.luau
run owner-test-transport-types luau-lsp analyze --definitions=.cache/globalTypes.d.luau tests/published/OwnerTestTransport.luau
run owner-test-adapter lune run tests/owner_test_adapter.luau
run owner-test-adapter-lint selene tests/published/OwnerTestAdapter.luau
run owner-test-adapter-types luau-lsp analyze --definitions=.cache/globalTypes.d.luau tests/published/OwnerTestAdapter.luau
run wind-step-published-policy lune run tests/wind_step_published.luau
run wind-step-published-lint selene tests/published/WindStepPublishedPolicy.luau
run wind-step-published-builder python3 -B tests/wind_step_published_builder.py
run wind-step-published-intake-format stylua --check scripts/wind_step_published_evidence.luau
run wind-step-published-intake python3 -B tests/wind_step_published_intake.py
run wind-step-staging-format stylua --check scripts/stage_wind_step_package.luau tests/wind_step_staging_package.luau
run wind-step-staging python3 -B tests/wind_step_staging.py
run wind-step-release-preflight python3 -B tests/wind_step_release_preflight.py
run wind-step-publication-history python3 -B tests/wind_step_publication_history.py
run wind-step-permission-review python3 -B tests/wind_step_permission_review.py
run wind-step-published-build python3 -B scripts/build_wind_step_published.py
run wind-step-published-generated-lint selene build/published-test/wind_step.server.luau
run wind-step-published-generated-format stylua --check build/published-test/wind_step.server.luau
run wind-step-published-types luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=build/published-test/sourcemap.json build/published-test/wind_step.server.luau tests/published/WindStepPublishedPolicy.luau
run wind-step-published-package lune run tests/wind_step_published_build.luau
run wind-step-published-worker lune run tests/wind_step_published_worker.luau
run owner-test-view lune run tests/owner_test_view.luau
run owner-test-view-lint selene tests/published/OwnerTestView.luau tests/published/wind_step.client.luau
run owner-test-view-types luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=build/published-test/sourcemap.json tests/published/OwnerTestView.luau tests/published/wind_step.client.luau

if [ $fail -eq 0 ]; then echo "CHECK: PASS"; else echo "CHECK: FAIL"; fi
exit $fail