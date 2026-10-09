#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Record the video scenario and cut the preview videos and screenshots from it.

Frames go to build/video/, the results to release/marketing/videos/ (portrait.mp4
1080×1620, landscape.mp4 1920×1080) and release/marketing/screenshots/. Opens a window
and overwrites the desktop save.

Usage:
    uv run tools/make_videos.py
"""

import argparse
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
FRAMES = "build/video"
OUT = "release/marketing"

ENCODE = ["-r", "60", "-c:v", "libopenh264", "-b:v", "10M", "-pix_fmt", "yuv420p", "-an", "-movflags", "+faststart"]
TALL = "scale=1080:1620:flags=neighbor,setsar=1"

# (stage, first frame, seconds)
PORTRAIT = [("pile", 12, 2.3), ("build", 4, 5.4), ("mid", 24, 3.2), ("late", 10, 2.2), ("nuke", 0, 4.8)]
# (stage, first frame, seconds, top of the 360×203 band shown)
LANDSCAPE = [
    ("mid", 24, 3.2, 0),
    ("pile", 12, 1.7, 337),
    ("build", 4, 4.8, 328),
    ("build", 292, 1.2, 0),
    ("late", 10, 2.2, 234),
    ("nuke", 0, 4.1, 0),
]
SCREENSHOTS = {
    "factory": "build_0200",
    "first_mech": "build_0345",
    "battle": "mid_0110",
    "army": "late_0060",
    "nuke": "nuke_0200",
}


def run(cmd: list[str]) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True)


def cover(name: str) -> list[str]:
    return ["-loop", "1", "-framerate", "60", "-t", "0.7", "-i", f"{OUT}/covers/{name}.png"]


def clip(stage: str, start: int, seconds: float) -> list[str]:
    return ["-framerate", "60", "-start_number", str(start), "-t", str(seconds), "-i", f"{FRAMES}/{stage}_%04d.png"]


def band(top: int) -> str:
    return f"crop=360:203:0:{top},scale=1920:1083:flags=neighbor,crop=1920:1080:0:0,setsar=1"


def encode(inputs: list[str], filters: list[str], output: str) -> None:
    """Concatenates the inputs, each through its own filter, into one video."""
    labels = [f"[v{i}]" for i in range(len(filters))]
    graph = ";".join(f"[{i}]{f}{label}" for i, (f, label) in enumerate(zip(filters, labels)))
    graph += f";{''.join(labels)}concat=n={len(filters)}"
    run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", graph, *ENCODE, output])


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    shutil.rmtree(PROJECT_ROOT / FRAMES, ignore_errors=True)
    run([
        "godot", "--path", ".", "--display-driver", "x11", "--audio-driver", "Dummy",
        "--fixed-fps", "60", "--disable-vsync", "--resolution", "360x540",
        "--", "--scenario", "video", "--shots", FRAMES,
    ])  # fmt: skip
    for folder in ("videos", "screenshots"):
        (PROJECT_ROOT / OUT / folder).mkdir(parents=True, exist_ok=True)

    inputs = cover("portrait")
    for stage, start, seconds in PORTRAIT:
        inputs += clip(stage, start, seconds)
    encode(inputs, [TALL] * (1 + len(PORTRAIT)), f"{OUT}/videos/portrait.mp4")

    inputs = cover("landscape")
    filters = ["setsar=1"]
    for stage, start, seconds, top in LANDSCAPE:
        inputs += clip(stage, start, seconds)
        filters.append(band(top))
    encode(inputs, filters, f"{OUT}/videos/landscape.mp4")

    for name, frame in SCREENSHOTS.items():
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{FRAMES}/{frame}.png", "-vf", TALL, f"{OUT}/screenshots/{name}.png"])


if __name__ == "__main__":
    main()
