#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/deploy.env
tools/export_web.sh release
dir="${FTP_DIR:-/}"
lftp -u "$FTP_USER,$FTP_PASS" -e "set ftp:ssl-force true; set ftp:ssl-protect-data true; set ssl:verify-certificate ${FTP_VERIFY_CERT:-true}; set xfer:use-temp-file true; mirror --reverse --delete --verbose -x '\.import$' -x '^index\.html$' build/web $dir; put -O $dir build/web/index.html; bye" "ftp://$FTP_HOST"
echo "${WEB_URL:-}"
