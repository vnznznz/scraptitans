#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Build the lightweight Godot export templates from source.

web: release and debug web templates → build/templates/web_<target>.zip
smoke: a Linux debug template with the same build profile, built in a Fedora container
→ build/templates/linux_smoke.x86_64

Environment: GODOT_SRC (default ~/work/source/godot), EMSDK_DIR (default
~/work/source/emsdk).

Usage:
    uv run tools/build_templates.py [web|smoke]
"""

import argparse
import os
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = PROJECT_ROOT / "build" / "templates"

COMMON = [
    f"-j{os.cpu_count()}",
    f"build_profile={PROJECT_ROOT / 'tools' / 'web.gdbuild'}",
    "deprecated=no",
    "disable_advanced_gui=yes",
    "modules_enabled_by_default=no",
    "module_gdscript_enabled=yes",
    "module_freetype_enabled=yes",
    "module_text_server_fb_enabled=yes",
]


def run(cmd: list[str], cwd: Path) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, cwd=cwd, check=True)


def build_web(godot_src: Path, emsdk: Path) -> None:
    for target in ("template_release", "template_debug"):
        scons = [
            "scons",
            "platform=web",
            f"target={target}",
            "threads=no",
            "production=yes",
            "lto=full",
            "optimize=size_extra",
            *COMMON,
        ]
        with_emsdk = 'source "$0/emsdk_env.sh" >/dev/null 2>&1 && exec "$@"'
        run(["bash", "-c", with_emsdk, str(emsdk), *scons], cwd=godot_src)
        shutil.copy2(
            godot_src / "bin" / f"godot.web.{target}.wasm32.nothreads.zip",
            TEMPLATES / f"web_{target.removeprefix('template_')}.zip",
        )


def build_smoke(godot_src: Path) -> None:
    scons = [
        "platform=linuxbsd",
        "target=template_debug",
        "x11=no",
        "wayland=no",
        "vulkan=no",
        "accesskit=no",
        *COMMON,
    ]
    in_container = 'dnf install -qy gcc-c++ libstdc++-static scons >/dev/null && scons "$@"'
    run(
        [
            "podman",
            "run",
            "--rm",
            "--security-opt",
            "label=disable",
            "-v",
            f"{godot_src}:{godot_src}",
            "-v",
            f"{PROJECT_ROOT}:{PROJECT_ROOT}",
            "-w",
            str(godot_src),
            "fedora:43",
            "bash",
            "-c",
            in_container,
            "_",
            *scons,
        ],
        cwd=godot_src,
    )
    shutil.copy2(
        godot_src / "bin" / "godot.linuxbsd.template_debug.x86_64",
        TEMPLATES / "linux_smoke.x86_64",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("what", nargs="?", default="web", choices=["web", "smoke"])
    args = parser.parse_args()

    godot_src = Path(os.environ.get("GODOT_SRC", Path.home() / "work/source/godot"))
    emsdk = Path(os.environ.get("EMSDK_DIR", Path.home() / "work/source/emsdk"))
    TEMPLATES.mkdir(parents=True, exist_ok=True)

    if args.what == "web":
        build_web(godot_src, emsdk)
    else:
        build_smoke(godot_src)


if __name__ == "__main__":
    main()
