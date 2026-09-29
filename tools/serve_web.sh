#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export WEB_ROOT="$PWD/build/web"
export LAN_IP="${LAN_IP:-$(ip -4 route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p')}"
echo "https://localhost:8443  https://$LAN_IP:8443"
exec "${CADDY:-caddy}" run --config tools/Caddyfile --adapter caddyfile
