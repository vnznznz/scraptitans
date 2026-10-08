#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Export the release build of the own site and upload it with the marketing files.

Refuses to run with uncommitted changes, so the deployed version always names a commit.
The FTP account is read from tools/deploy.env (FTP_HOST, FTP_USER, FTP_PASS, optional
FTP_DIR, FTP_VERIFY_CERT, WEB_URL).

Usage:
    uv run tools/deploy_web.py
"""

import argparse
import shlex
import subprocess
import sys

from export_web import PROJECT_ROOT, export, is_dirty


def read_env() -> dict[str, str]:
    env = {}
    for line in (PROJECT_ROOT / "tools" / "deploy.env").read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = "".join(shlex.split(value))
    return env


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    if is_dirty():
        sys.exit("error: uncommitted changes; commit them first, a deployed build has to match a commit")

    env = read_env()
    out = export("release", "Web")

    remote = env.get("FTP_DIR", "/")
    marketing = remote.rstrip("/") + "/marketing"
    commands = [
        "set ftp:ssl-force true",
        "set ftp:ssl-protect-data true",
        f"set ssl:verify-certificate {env.get('FTP_VERIFY_CERT', 'true')}",
        "set xfer:use-temp-file true",
        "mirror --reverse --delete --verbose"
        f" -x '\\.import$' -x '^index\\.html$' -x '^marketing/' build/web {remote}",
        f"put -O {remote} build/web/index.html",
        f"mirror --reverse --delete --verbose release/marketing {marketing}",
        "bye",
    ]
    print(f"$ lftp {env['FTP_HOST']}")
    subprocess.run(
        ["lftp", "-u", f"{env['FTP_USER']},{env['FTP_PASS']}", "-e", "; ".join(commands), f"ftp://{env['FTP_HOST']}"],
        cwd=PROJECT_ROOT,
        check=True,
    )

    version = (out / "version.txt").read_text().strip()
    print(f"\nDeployed {version}:")
    web_url = env.get("WEB_URL", "").rstrip("/")
    if web_url:
        print(f"  game:      {web_url}/")
        print(f"  marketing: {web_url}/marketing/")
        print(f"  version:   {web_url}/version.txt")


if __name__ == "__main__":
    main()
