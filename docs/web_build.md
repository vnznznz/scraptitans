# Lightweight web build

Custom Godot 4.7.2 web export templates with only the engine parts the game uses. Result (release `index.wasm`):

| | raw | gzip -9 | brotli 11 |
|---|---|---|---|
| official 4.7.2 `web_nothreads_release` | 39.5 MB | 10.1 MB | 7.1 MB |
| custom | 12.9 MB | 3.8 MB | 2.6 MB |

`.pck` 188 → 208 KB (PNG instead of WebP); 305 KB after the M10 art.

## Game needs

- 2D nodes: `Node2D`, `Sprite2D`, `CPUParticles2D` (+ `Gradient`)
- Controls: `Label`, `Button`, `ScrollContainer`, box/panel containers, `TextureRect`, `TextureProgressBar`, `ColorRect`; theme with `StyleBoxTexture`
- `Tween`, `JSON`, `FileAccess`, GDScript
- One TTF font (Silkscreen, ASCII only), dynamic via FreeType
- Lossless PNG sprites

Not needed: 3D, physics (2D and 3D), navigation, XR, audio formats, video, networking, advanced GUI (dialogs, `RichTextLabel`, `Tree`, …), SVG/JPG at runtime, MSDF fonts, WOFF2.

## Gotchas (from engine source)

- Lossless imports are stored as WebP in the `.pck` unless `rendering/textures/lossless_compression/force_png` is on (`editor/import/resource_importer_texture.cpp:275`). Without it, dropping the webp module breaks every sprite.
- "Detect from Project" always keeps the advanced text server (its class list contains `CanvasItem`), so the switch to the fallback text server is manual. Biggest single saving (ICU data, HarfBuzz).
- Profile editor: "dynamic fonts" (FreeType) depends on the advanced text server, so disabling the advanced one can switch FreeType off too. Keep `module_freetype_enabled`: the fallback text server needs it for the TTF.
- Default theme icons are SVG-generated; with the svg module off they're blank. The game's theme covers everything it shows.
- `JavaScriptBridge` exists only with `javascript_eval` (default on); M11 Poki needs it.
- Templates must match the editor version exactly: `~/work/source/godot` is at `4.7.2-stable`.
- Emscripten: 4.0.11 (what 4.7.2's CI uses; the minimum is 4.0.0). The docs' "6.0.1+" is for the newer engine version.

## Steps

- [x] Toolchain: emsdk 4.0.11 in `~/work/source/emsdk` (`./emsdk install 4.0.11 && ./emsdk activate 4.0.11`, no `--permanent`); scripts source `emsdk_env.sh`
- [x] `project.godot`: `force_png` on + reimport; drop the leftover Jolt setting
- [x] Web preset: `vram_texture_compression/for_desktop=false`; `custom_template/debug|release` → `build/templates/web_{debug,release}.zip`
- [x] Build profile `tools/web.gdbuild` (committed): editor → Project → Tools → Engine Compilation Configuration Editor → Detect from Project (done headless via a throwaway plugin in a scratch copy that presses its buttons), minus `Script` and `ScrollBar`, then by hand: text server fallback on, advanced off, FreeType on, MSDF off, WOFF2/brotli off, Graphite off. Expect 3D, physics, navigation, XR off from detection
- [x] `tools/build_templates.sh`: scons in `~/work/source/godot`, `template_debug` (DBG panel) and `template_release`, zips from `bin/` → `build/templates/`. Flags:
  ```
  platform=web threads=no production=yes lto=full optimize=size_extra deprecated=no
  disable_advanced_gui=yes build_profile=<project>/tools/web.gdbuild
  modules_enabled_by_default=no module_gdscript_enabled=yes
  module_freetype_enabled=yes module_text_server_fb_enabled=yes
  ```
- [x] Smoke check without a browser: `tools/build_templates.sh smoke` builds a Linux `template_debug` with the same profile and flags (in a `fedora:43` podman container: no host C++ compiler; `x11=no wayland=no vulkan=no accesskit=no`); "Linux smoke" export preset including `tools/` → `.pck`; `tools/smoke_templates.sh` puts it next to the binary (templates refuse `--main-pack`) and runs m0–m8 + intro headless: all pass, no engine errors. Catches stripped classes the game still needs (not rendering)
- [x] Measure `index.wasm` raw and brotli vs the official template (table above)
- [x] `docs/tech.md`: flags, profile, template paths, rule "new engine class used → regenerate profile, rebuild templates"
- [ ] User: browser + iOS Safari test of the release build
- [ ] Optional: compressed delivery (`encode` in the Caddyfile; brotli-precompressed `.wasm`/`.pck` for the deploy host)

## Risks

- A class reached only indirectly (engine internals, by name as a string) gets stripped → runtime failure. Smoke check covers most; fix via the profile's `force_detect_classes`.
- Fallback text server: no ligatures or complex scripts. Fine for Silkscreen; no non-ASCII strings in shipped code or data.
- Build cost: full LTO needs ~12 GB RAM (27 GB here); ~15–30 min per web template.
