#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Print the funnel from the analytics logs (plan.md M24).

Fetches analytics/log/ from the webspace over FTPS into build/analytics/ (same
account as deploy_web.py, tools/deploy.env), then counts sessions per event and
prints one funnel per device class: sessions, share of starts, median seconds.

Usage:
    uv run tools/funnel.py [--no-fetch] [--day YYYY-MM-DD] [--build PREFIX] [--src cg|web] [--new]
"""

import argparse
import statistics
import subprocess
import sys

from deploy_web import read_env
from export_web import PROJECT_ROOT

LOG_DIR = PROJECT_ROOT / "build" / "analytics"
EVENTS = ["start", "first_tap", "first_mech", "wave1", "min1", "min3", "min5", "min10", "gate", "nuke"]


def fetch() -> None:
    env = read_env()
    remote = env.get("FTP_DIR", "/").rstrip("/") + "/analytics/log"
    commands = [
        "set ftp:ssl-force true",
        "set ftp:ssl-protect-data true",
        f"set ssl:verify-certificate {env.get('FTP_VERIFY_CERT', 'true')}",
        f"mirror --verbose -i 'events-.*\\.log' {remote} {LOG_DIR}",
        "bye",
    ]
    subprocess.run(
        ["lftp", "-u", f"{env['FTP_USER']},{env['FTP_PASS']}", "-e", "; ".join(commands), f"ftp://{env['FTP_HOST']}"],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--no-fetch", action="store_true", help="read build/analytics/ as it is")
    parser.add_argument("--day", help="only sessions started on this day (YYYY-MM-DD, UTC)")
    parser.add_argument("--build", help="only sessions whose build starts with this prefix")
    parser.add_argument("--src", choices=["cg", "web"], help="only this source")
    parser.add_argument("--new", action="store_true", help="only sessions with 0 wars won")
    args = parser.parse_args()

    if not args.no_fetch:
        fetch()

    # sid -> {ev: t}; per sid the fields of its first seen line and its start day
    sessions: dict[str, dict[str, float]] = {}
    fields: dict[str, tuple[str, str, str, int]] = {}  # build, src, dev, wars
    start_day: dict[str, str] = {}
    for path in sorted(LOG_DIR.glob("events-*.log")):
        for raw in path.read_text().splitlines():
            parts = raw.split(" ")
            if len(parts) != 9 or parts[1] != "1":
                continue
            ts, _, sid, build, src, dev, wars, ev, t = parts
            sessions.setdefault(sid, {})[ev] = float(t)
            fields.setdefault(sid, (build, src, dev, int(wars)))
            if ev == "start":
                start_day[sid] = ts[:10]

    def keep(sid: str) -> bool:
        build, src, dev, wars = fields[sid]
        if args.build and not build.startswith(args.build):
            return False
        if args.src and src != args.src:
            return False
        if args.new and wars > 0:
            return False
        if args.day and start_day.get(sid) != args.day:
            return False
        return True

    kept = [sid for sid in sessions if keep(sid)]
    for device in ["mobile", "desktop"]:
        sids = [s for s in kept if fields[s][2] == device]
        starts = sum(1 for s in sids if "start" in sessions[s])
        print(f"\n{device}: {starts} sessions")
        if not starts:
            continue
        for ev in EVENTS:
            times = sorted(sessions[s][ev] for s in sids if ev in sessions[s])
            if not times:
                print(f"  {ev:<10} {0:>5}    0 %")
                continue
            median = statistics.median(times)
            print(f"  {ev:<10} {len(times):>5}  {100 * len(times) / starts:3.0f} %  median {median:6.1f} s")


if __name__ == "__main__":
    main()
