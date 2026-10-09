#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Run every scenario against a pack on the lightweight Linux smoke template.

Catches engine classes the build profile leaves out. Logs go to build/smoke/.

Usage:
    uv run tools/smoke_templates.py [binary]
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SMOKE = PROJECT_ROOT / "build" / "smoke"

SCENARIOS = [
    "m0", "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9",
    "intro", "ui", "progression", "pane", "art", "audio", "field", "stations",
    "desktop", "prestige", "sdk", "away", "gate",
]  # fmt: skip


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", nargs="?", default="build/templates/linux_smoke.x86_64")
    args = parser.parse_args()

    SMOKE.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["godot", "--headless", "--path", ".", "--export-pack", "Linux smoke", "build/smoke/smoke.pck"],
        cwd=PROJECT_ROOT,
        check=True,
    )
    binary = SMOKE / "smoke.x86_64"
    shutil.copy(PROJECT_ROOT / args.binary, binary)
    binary.chmod(0o755)

    failed = []
    for scenario in SCENARIOS:
        log = SMOKE / f"{scenario}.log"
        with open(log, "w") as f:
            result = subprocess.run(
                [str(binary), "--headless", "--", "--scenario", scenario],
                cwd=PROJECT_ROOT,
                stdout=f,
                stderr=subprocess.STDOUT,
            )
        if result.returncode != 0:
            failed.append(scenario)
        lines = [line for line in log.read_text(errors="replace").splitlines() if re.search(r"^RESULT|ERROR", line)]
        print("\n".join(lines[:5]))

    if failed:
        sys.exit(f"failed: {' '.join(failed)} (logs in build/smoke/)")


if __name__ == "__main__":
    main()
