#!/usr/bin/env bash
# Fallback when `rokit install` gets 403 (anonymous GitHub API rate limit on the VM, D-390): read the
# release list through the PromptQL GitHub integration and download the pinned linux x86_64 builds from
# rokit.toml straight into ~/.rokit/bin. Usage: bash scripts/tools_fallback.sh
set -euo pipefail
cd "$(dirname "$0")/.."
bin="$HOME/.rokit/bin"; mkdir -p "$bin"; tmp=$(mktemp -d)
grep -E '^[A-Za-z-]+ *= *"' rokit.toml | while IFS= read -r line; do
	name=$(echo "$line" | cut -d= -f1 | tr -d ' ' | tr 'A-Z' 'a-z')
	spec=$(echo "$line" | cut -d'"' -f2); repo=${spec%@*}; ver=${spec#*@}
	[ -x "$bin/$name" ] && { echo "have $name"; continue; }
	if [ -n "${PROMPTQL_PLATFORM_API_URL:-}" ]; then
		api="$PROMPTQL_PLATFORM_API_URL/v1/integration/__github/api.github.com"
		auth=(-H "Authorization: Bearer ${PROMPTQL_USER_JWT:-}")
	else
		api="https://api.github.com"
		auth=()
	fi
	rel=$(curl -sS "${auth[@]}" "$api/repos/$repo/releases/tags/v$ver" || true)
	echo "$rel" | grep -q browser_download_url || rel=$(curl -sS "${auth[@]}" "$api/repos/$repo/releases/tags/$ver")
	url=$(echo "$rel" | python3 -c 'import json,sys
a=[x["browser_download_url"] for x in json.load(sys.stdin).get("assets",[])]
ok=lambda u:u.endswith((".zip",".tar.xz",".tar.gz"))
z=[u for u in a if "linux" in u.lower() and ("x86_64" in u or "x86-64" in u or "amd64" in u) and ok(u)]
z=z or [u for u in a if "linux" in u.lower() and ok(u) and "arm" not in u.lower() and "aarch" not in u.lower()]
print(z[0] if z else "")')
	[ -n "$url" ] || { echo "FAIL $name: no linux asset"; continue; }
	curl -sSfL -o "$tmp/$name.pkg" "$url"
	rm -rf "$tmp/x"; mkdir "$tmp/x"
	case "$url" in *.zip) unzip -q -o "$tmp/$name.pkg" -d "$tmp/x" ;; *) tar -xf "$tmp/$name.pkg" -C "$tmp/x" ;; esac
	exe=$(find "$tmp/x" -type f | head -1)
	install -m 755 "$exe" "$bin/$name"; echo "ok $name $ver"
done
rm -rf "$tmp"
