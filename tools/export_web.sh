#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-debug}"
rm -rf build/web
mkdir -p build/web
godot --headless --path . --export-"$mode" "Web" build/web/index.html
