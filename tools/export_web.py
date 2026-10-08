#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Export a web build.

The build is stamped with the build number (git commit count) and the commit hash,
e.g. 0.2.0-m20+102.bb5dfcc, with -dirty when there are uncommitted changes. The version
is shown in the settings and written to version.txt next to the build.

Usage:
    uv run tools/export_web.py [debug|release] [Web|CrazyGames|CrazyGamesAds]

Example:
    uv run tools/export_web.py
    uv run tools/export_web.py release CrazyGames
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

OUTPUTS = {
    "Web": "build/web",
    "CrazyGames": "build/crazygames",
    "CrazyGamesAds": "build/crazygames_ads",
}


def run(cmd: list[str]) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=PROJECT_ROOT, check=True, capture_output=True, text=True
    ).stdout.strip()


def is_dirty() -> bool:
    return git("status", "--porcelain") != ""


def build_stamp() -> str:
    stamp = f"{git('rev-list', '--count', 'HEAD')}.{git('rev-parse', '--short', 'HEAD')}"
    if is_dirty():
        stamp += "-dirty"
    return stamp


def game_version() -> str:
    project = (PROJECT_ROOT / "project.godot").read_text()
    return re.search(r'^config/version="(.*)"$', project, re.MULTILINE).group(1)


def export(mode: str, preset: str) -> Path:
    """Exports the preset and returns the output directory."""
    out = PROJECT_ROOT / OUTPUTS[preset]
    stamp = build_stamp()
    version = f"{game_version()}+{stamp}"

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    (PROJECT_ROOT / "build" / ".gdignore").touch()

    stamp_file = PROJECT_ROOT / "build.txt"
    stamp_file.write_text(stamp + "\n")
    try:
        run(["godot", "--headless", "--path", ".", f"--export-{mode}", preset, str(out / "index.html")])
    finally:
        stamp_file.unlink()

    if b"WEBPVP8" in (out / "index.pck").read_bytes():
        sys.exit(
            "error: WebP textures in the pack (template has no webp module);"
            " reimport with force_png (restart the editor)"
        )

    (out / "version.txt").write_text(version + "\n")
    print(f"\nExported {mode} build {version}:")
    print(f"  output: {out}")
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", default="debug", choices=["debug", "release"])
    parser.add_argument("preset", nargs="?", default="Web", choices=sorted(OUTPUTS))
    args = parser.parse_args()
    export(args.mode, args.preset)


if __name__ == "__main__":
    main()
