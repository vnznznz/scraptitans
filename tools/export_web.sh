#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-debug}"
preset="${2:-Web}"
out=build/web
if [ "$preset" = CrazyGames ]; then
	out=build/crazygames
fi
rm -rf "$out"
mkdir -p "$out"
touch build/.gdignore
godot --headless --path . --export-"$mode" "$preset" "$out/index.html"
if grep -a -q 'WEBPVP8' "$out/index.pck"; then
	echo "error: WebP textures in the pack (template has no webp module); reimport with force_png (restart the editor)" >&2
	exit 1
fi
