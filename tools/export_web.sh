#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-debug}"
rm -rf build/web
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-"$mode" "Web" build/web/index.html
if grep -a -q 'WEBPVP8' build/web/index.pck; then
	echo "error: WebP textures in the pack (template has no webp module); reimport with force_png (restart the editor)" >&2
	exit 1
fi
