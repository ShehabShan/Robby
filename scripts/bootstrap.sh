#!/usr/bin/env bash
# Idempotent setup for a fresh machine/VM. Safe to run every session.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v rokit >/dev/null 2>&1 && [ ! -x "$HOME/.rokit/bin/rokit" ]; then
	curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash >/dev/null 2>&1
fi
export PATH="$HOME/.rokit/bin:$PATH"
rokit install --no-trust-check >/dev/null 2>&1

# Roblox API type definitions for luau-lsp
mkdir -p .cache
if [ ! -s .cache/globalTypes.d.luau ]; then
	curl -sSfL -o .cache/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi

# Wally packages (only when dependencies are declared)
if sed -n '/^\[dependencies\]/,$p' wally.toml | grep -qE '^[A-Za-z_]+ *= *"'; then
	# The VM's global git config routes github.com through the PromptQL proxy, which wally's
	# libgit2 cannot authenticate to; run wally with a clean HOME (public index, no auth needed).
	WALLY_BIN=$(find "$HOME/.rokit/tool-storage" -type f -name wally 2>/dev/null | head -1)
	WALLY_HOME=$(mktemp -d)
	HOME="$WALLY_HOME" "${WALLY_BIN:-wally}" install >/dev/null
	rm -rf "$WALLY_HOME"
fi

# PromptQL VM only: route git through the GitHub integration proxy (no tokens stored)
if [ -n "${PROMPTQL_PLATFORM_API_URL:-}" ]; then
	git config --global url."$PROMPTQL_PLATFORM_API_URL/v1/integration/__github/github.com/".insteadOf "https://github.com/"
	git config --global credential."$PROMPTQL_PLATFORM_API_URL".helper \
		'!f() { test "$1" = get && printf "authtype=Bearer\ncredential=%s\n" "$PROMPTQL_USER_JWT"; }; f'
fi

echo "bootstrap OK"