#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bin="${1:-build/templates/linux_smoke.x86_64}"
mkdir -p build/smoke
godot --headless --path . --export-pack "Linux smoke" build/smoke/smoke.pck
install -m755 "$bin" build/smoke/smoke.x86_64
failed=()
for s in m0 m1 m2 m3 m4 m5 m6 m7 m8 intro; do
	build/smoke/smoke.x86_64 --headless -- --scenario "$s" > "build/smoke/$s.log" 2>&1 || failed+=("$s")
	grep -E "^RESULT|ERROR|SCRIPT ERROR" "build/smoke/$s.log" | head -5 || true
done
if ((${#failed[@]})); then
	echo "failed: ${failed[*]} (logs in build/smoke/)"
	exit 1
fi
