#!/usr/bin/env bash
# Idempotent: installs Blender LTS for headless use in the PromptQL VM (not part of bootstrap: ~350 MB).
# Usage: bash scripts/blender-setup.sh   then: blender -b --factory-startup -P art/blender/<script>.py -- <out_dir>
set -euo pipefail
VER=4.2.3
DIR="$HOME/.local/blender-$VER"
if [ ! -x "$DIR/blender" ]; then
	sudo apt-get update -qq >/dev/null 2>&1 || true
	sudo apt-get install -y -qq libxi6 libxkbcommon0 libsm6 libgl1 libegl1 libxrender1 libxxf86vm1 libxfixes3 >/dev/null 2>&1 || true
	mkdir -p "$HOME/.local"
	curl -sSfL "https://download.blender.org/release/Blender4.2/blender-$VER-linux-x64.tar.xz" | tar -xJ -C "$HOME/.local"
	mv "$HOME/.local/blender-$VER-linux-x64" "$DIR"
fi
mkdir -p "$HOME/.local/bin"
ln -sf "$DIR/blender" "$HOME/.local/bin/blender"
echo "BLENDER: $("$DIR/blender" --version 2>/dev/null | head -1) at ~/.local/bin/blender"