#!/usr/bin/env bash
# Renders the HUD mock (T-016c, D-068) to build/hud_*.png with headless Chrome. Prints one line per PNG.
set -eu
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
for f in $(lune run scripts/hud_mock.luau); do
	size=$(echo "$f" | grep -o '[0-9]*x[0-9]*' | tr x ,)
	png="${f%.html}.png"
	google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars --window-size="$size" \
		--screenshot="$png" "file://$PWD/$f" >/dev/null 2>&1
	echo "$png"
done