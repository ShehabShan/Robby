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

run format stylua --check src tests
run lint selene src
run sourcemap rojo sourcemap default.project.json -o sourcemap.json
run types luau-lsp analyze --definitions=.cache/globalTypes.d.luau --sourcemap=sourcemap.json src
run tests lune run tests/run.luau
mkdir -p build
run build rojo build default.project.json -o build/Robby.rbxl

if [ $fail -eq 0 ]; then echo "CHECK: PASS"; else echo "CHECK: FAIL"; fi
exit $fail