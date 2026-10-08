#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-debug}"
preset="${2:-Web}"
out=build/web
if [ "$preset" = CrazyGames ]; then
	out=build/crazygames
elif [ "$preset" = CrazyGamesAds ]; then
	out=build/crazygames_ads
fi
build="$(git rev-list --count HEAD).$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain)" ]; then
	build="$build-dirty"
fi
rm -rf "$out"
mkdir -p "$out"
touch build/.gdignore
echo "$build" > build.txt
trap 'rm -f build.txt' EXIT
godot --headless --path . --export-"$mode" "$preset" "$out/index.html"
if grep -a -q 'WEBPVP8' "$out/index.pck"; then
	echo "error: WebP textures in the pack (template has no webp module); reimport with force_png (restart the editor)" >&2
	exit 1
fi
version="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)+$build"
echo "$version" > "$out/version.txt"
echo "$version"
