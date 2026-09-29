#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project="$PWD"
godot_src="${GODOT_SRC:-$HOME/work/source/godot}"
emsdk="${EMSDK_DIR:-$HOME/work/source/emsdk}"
what="${1:-web}"

common=(
	-j"$(nproc)"
	build_profile="$project/tools/web.gdbuild"
	deprecated=no
	disable_advanced_gui=yes
	modules_enabled_by_default=no
	module_gdscript_enabled=yes
	module_freetype_enabled=yes
	module_text_server_fb_enabled=yes
)

mkdir -p build/templates
cd "$godot_src"

case "$what" in
web)
	source "$emsdk/emsdk_env.sh" >/dev/null 2>&1
	for target in template_release template_debug; do
		scons platform=web target="$target" threads=no production=yes lto=full optimize=size_extra "${common[@]}"
		cp "bin/godot.web.$target.wasm32.nothreads.zip" "$project/build/templates/web_${target#template_}.zip"
	done
	;;
smoke)
	podman run --rm --security-opt label=disable -v "$godot_src:$godot_src" -v "$project:$project" -w "$godot_src" fedora:43 \
		bash -c 'dnf install -qy gcc-c++ libstdc++-static scons >/dev/null && scons "$@"' _ \
		platform=linuxbsd target=template_debug x11=no wayland=no vulkan=no accesskit=no "${common[@]}"
	cp bin/godot.linuxbsd.template_debug.x86_64 "$project/build/templates/linux_smoke.x86_64"
	;;
*)
	echo "usage: $0 [web|smoke]" >&2
	exit 1
	;;
esac
