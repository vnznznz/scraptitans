#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Serve a web build over HTTPS with Caddy, on localhost and the LAN address.

Environment: WEB_ROOT (default build/web), LAN_IP (default: this machine's), CADDY.

Usage:
    uv run tools/serve_web.py

Example:
    WEB_ROOT=build/crazygames_ads uv run tools/serve_web.py
"""

import argparse
import os
import socket
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def lan_ip() -> str:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.connect(("1.1.1.1", 80))
        return s.getsockname()[0]


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    web_root = Path(os.environ.get("WEB_ROOT", PROJECT_ROOT / "build" / "web")).resolve()
    os.environ["WEB_ROOT"] = str(web_root)
    os.environ.setdefault("LAN_IP", lan_ip())
    print(f"https://localhost:8443  https://{os.environ['LAN_IP']}:8443")

    os.chdir(PROJECT_ROOT)
    caddy = os.environ.get("CADDY", "caddy")
    os.execvp(caddy, [caddy, "run", "--config", "tools/Caddyfile", "--adapter", "caddyfile"])


if __name__ == "__main__":
    main()
