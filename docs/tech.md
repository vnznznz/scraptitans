# Tech

## Stack
- Godot 4.7.2, GL Compatibility, GDScript (static types)
- Web export, no threads; custom export templates (see Web templates)

## Display
- Viewport 360×640, stretch `canvas_items`, aspect `keep_width`
- Texture filter Nearest (project default)
- Font: Silkscreen (OFL), `fonts/`; import antialiasing/hinting/subpixel off; size 16 everywhere (2× pixel grid), 8 is illegible
- `fonts/silkscreen_condensed.tres`: glyph spacing −1, segment names only (82 px label, wraps; long single words spill into the gutter)
- Theme `ui/theme.tres`: buttons/panels are nine-patch PNGs from `art/ui/`

## Layout
- `scenes/main.tscn`: `Hud` (48) / `Battlefield` (160) / `Scroll` → `Content` (lines, `UnlockLine`) / `BottomBar` (100: `Scrapyard` left, `Upgrades` bottom-right); overlays `UpgradeMenu` (between HUD and bottom bar), `Flyers`, `Debug`, `Settings`, `Nuke` (topmost, blocks input)
- Scrapyard always visible in the bottom bar; pile/workers/tap in child `Yard`, centered until reveal, then slides left (0.4 s): pile (tap), yard workers on both sides, hire button (icon + cost, MAX + disabled when full) above UPGRADES; pane starts at the top
- Views build their children in code; main adds one `LineView` per line, more on `line_added`
- UPGRADES button toggles the menu (reads CLOSE while open); badge = `GameState.affordable_upgrades()` (visible, unmaxed, unlocked, affordable rows): red with count, grey "0" when none; hidden only while the menu is open
- Intro guide (`scenes/intro_guide.gd`, above `Layout`, no input): yellow pulsing label + bobbing arrow, step derived from state (unsaved): short on scrap for the next build / a station stalled NO_SCRAP → pile; affordable → that station's Build button; all built → first station at or past the mech (past it once assembling / part fitted) whose bar isn't full, no arrow when none; hidden once `revealed()`
- Progressive reveal: UPGRADES, UNLOCK LINE, YARD WORKER (+ yard slots) hidden until `GameState.revealed()` (`mechs_built > 0`)
- HUD columns: scrap (x 6) / mechs built + `mechs_per_min` (x 112, icon bumps on deploy) / credits (x 214), gear right
- Window/tab title `(N) Scrap Titans` while N upgrades are affordable (after reveal, before the nuke); `DisplayServer.window_set_title` = `document.title` on web (inside Poki's iframe it won't reach the tab)
- Upgrade menu: one list, re-sorted every frame (unmaxed by cost, maxed last); each row: title / effect, info button toggles the `desc` label
- Line: no header row; pause strip (24 px, one button from name row to belt: scrap icon, line scrap use/s as upright stacked digits `Fmt.whole`, ⏸/▶) left of the stations; segments centered by count in the rest (step 84, 4 columns fit), re-laid out when a segment is appended; 136 px tall; paused → usage dimmed, machines dimmed; usage red while a station of the line is out of scrap
- Segment rows: name / machine (tap; work bar overlays its top beam, hired workers stand inside behind the mech, empty slots not drawn) / belt / one fixed button row, never hidden or resized on built stations: hire (56 px, worker icon + cost; MAX + disabled when full) + ⬆ apply-tier (24 px, icon only; enabled when a higher tier is unlocked and affordable, dim green while short on scrap, faint when none); row spans 82 px (2 px gap at step 84); fit cost shown in the tier row desc
- DBG toggle bottom-left just above the bottom bar, panel opens upward: time scale, +scrap/credits, kill wave, +50 mechs
- Positions hardcoded in base pixels

## Autoloads
- `Data`: loads `data/*.json`
- `GameState`: sim; fixed tick 1/30 s × `time_scale`; frame delta clamped to 0.25 s (no offline progress); `advance(s)` for instrumentation
- `Save`: `user://save.json`, `version` 1; every 5 s, after purchases, on focus out/close
- `Instrument`: no-op unless `--scenario` user arg

## Sim
- Naming: code "segment" = player-facing "station" (all UI text and the pitch say station)
- `sim/`: `LineState` → `SegmentState` → `MechState`; plain `RefCounted`, `to_dict`/`from_dict`
- Views never mutate state except through `GameState` methods; they read it every frame
- Segment types in `line_slots` order; `optional` types (Plating) are appended to every line once their tier 1 is unlocked; line complete = all non-optional built; last built segment deploys
- Tiers: `unlocked_tier(type)` = level of generated row `tier_<type>` (+ `final_<type>`), −1 for optional; `apply_tier` bumps a segment one tier for `apply_cost` scrap; parts record the segment tier at attach time
- Segment: work banks up to bar size; full bar + mech (Frame: free slot, line complete) + scrap → assemble; one mech per segment; `stall` NONE / NO_SCRAP / BLOCKED
- Line processed last → first each tick; paused line starts no assembly (mechs already done still move/deploy)
- Workers: per segment `workers`, `worker_t += dt·workers`, one chunk per `worker_interval` (round robin, so the bar jumps); no chunk while the bar is full. Yard workers same, add `yard_chunk` scrap. `chunks` / `yard_chunks` counters (unsaved) drive the view hops
- Bar size = tier `bar_size` × stat `bar_mult` (grows with the segment's tier)
- Yard chunk = `yard_chunk` (Yard haul row) × `worker_chunk`; worker slots: one global stat `worker_slots` (Crew size row)
- Hire cost `worker_base·worker_growth^n` per station; caps from stats
- Deploy sums part tier stats (`lifetime`, `credits_per_sec`, `deploy_fee`, `dps`)
- Field mech: payout `base·step^min(floor(age/interval), cap)` by `age`; death by `wear`, which grows `1 + wave_damage·wave` per s; income batched to `mech_income` once per second, salvage on death
- Payout `cap` starts 0 (flat), Pay raises add steps
- `mechs_per_min`: deploys in the last 60 one-second samples (unsaved)
- Per-line scrap use: assembly costs → `LineState.use_scrap`, sampled each second with the global rates → `scrap_used_rate` (5 s window, unsaved); `LineState.starved()`
- Rates over 5 s: `credits_rate`; `tap_dps` (battlefield tap damage); `scrap_rate` net (assembly spend subtracts; HUD); `scrap_gain_rate` gross (disc tiers)
- Stall icon: NO_SCRAP at once, BLOCKED only after 3 s of game time in that state (view-side timer)
- `starved()`: any segment stalled NO_SCRAP → HUD scrap +/s red
- Wave: `wave`, `wave_hp`; drains by summed mech `dps`; ≤0 → bounty, `wave += 1`, full HP. `hp = base_hp·hp_growth^wave`, bounty likewise
- Wave enemies `Data.wave_enemies(wave)` (cached in `GameState.wave_enemies()`): type `types[wave % n]`, + next type from `mix_from`, + third from `mix_all_from`; count `type.count·(1 + count_growth·wave)/kinds`, scaled to ≤ `max_enemies`; variant `wave / variant_every` (fraction → that share already next variant), capped `variants − 1`; weight `type.weight·variant_tough^variant`; sorted by weight (weakest pops first)
- Battlefield tap `tap_wave()`: `tap_damage` share of max HP as damage, same share of the bounty as credits; `_damage_wave` shared with DPS drain (kill scrap, clear)
- `wave_alive()`: enemies whose cumulative weight share isn't drained yet. Each pop pays `kill_scrap`·max HP·weight share scrap (`enemy_killed`); a cleared wave pays the rest
- Stats: `GameState.stat(key)` = base + Σ delta·level, cached, cleared on purchase/load. Key `type.field` → `segments.json`, else `economy.json`. Salvage clamped to `salvage_cap`
- Upgrade cost `base_cost·growth^level`, growth = row `cost_growth` or `upgrade_cost_growth`; `lines` stat > line count → append `LineState`, emit `line_added`
- Nuke: a deployed mech with a `final` part sets `run_over` (sim stops, saved) and emits `nuke_launched`
- Signals: `purchased` (also pause, nuke; triggers save), `mech_deployed`, `mech_income`, `mech_died`, `wave_cleared`, `enemy_killed`, `line_added`, `segment_added`, `nuke_launched`

## Data
- Tunables only in `data/*.json`: `economy.json` (global stat bases), `segments.json` (`line_slots`, `types` → desc, worker cost/slots, tiers array with `bar_size`), `enemies.json` (HP/bounty curves, wave mix/growth/variants, `types`: count, weight, sprite, flying), `upgrades.json` (`rows`: id, name, desc, stat, delta, max_level, base_cost, optional `cost_growth`, unit `s`/`x`/`%`; rows on an optional type's stat hidden until it unlocks)
- Tier/final row descs built by the menu from the type `desc` / final tier `desc`
- Tier unlock rows generated by `Data` from `segments.json` tiers (`unlock_cost`, `apply_cost`); a tier with `final: true` (Atomic Missile) gets its own row `final_<type>`, locked until the rest are unlocked, confirm dialog before buying
- New save fields read with `.get` defaults, so `version` stays 1

## Battlefield
- Wave bar at top (`WaveBar`): `W<n> hp/max` left, `DPS` right = `wave_dps()` (mech DPS + `tap_dps`)
- Enemies right side, y-sorted layer; air and ground each spread left→right in pop order; visible = `wave_alive()`; flyers bob; `enemy_<sprite>_<variant>.png`
- `DamageFx` (`scenes/damage_fx.gd`): smoke ×3 / sparks by remaining share; mechs (lifetime) and enemies (wave HP left) share it
- Wave cleared: puffs, `CPUParticles2D` sparks, bounty disc burst, shake, next wave walks in from the right
- Mechs: max 24 drawn (3 rows × 8, back rows darker, drawn behind), rest simulated only; walk in with 4-frame cycle, fire bullets + muzzle flash every 0.8–1.6 s; enemies fire back, hit flashes the mech
- Damage from `remaining()` (1 − wear/lifetime): smoke <75/50/30 %, sparks <15 %, death = puff + debris particles
- Income discs: per-second discs throttled to ~10/s overall; deploy 2–6 discs by log10(fee); popped enemy 2 scrap discs with kill scrap

## Nuke
- `Nuke` (`scenes/nuke.gd`, refs battlefield/scroll/content/scrapyard): mech walks in → missile arcs off-screen → white flash + mushroom (battlefield scorched) → shockwave band sweeps the pane with auto-scroll, `collapse()` on each content child (lines → rubble + debris), then the yard (pile only) → run stats card → START AGAIN = `Save.reset_run`
- Loaded with `run_over`: everything collapsed, card shown

## Income feedback
- No floating numbers. `Flyers.spawn(kind, global_pos, amount, count)` (`ui/flyers.gd`): disc bursts up, flies to `Hud.target(kind)`, `Hud.pulse(kind)` on arrival; max 48 in flight
- Disc color tier by `amount` / current gross rate (`Flyers.tier`): <2 s of income tier 1, <10 s tier 2, else tier 3; `disc_<kind>_<1..3>.png`
- Spending: `Flyers.spend(kind, to, amount)`: disc leaves the HUD counter (icon `pulse_out`) and flies into the target; ≤6/s, dropped at the in-flight cap
- Purchases: `Flyers.pay(kind, button, amount)` after a successful buy (build, hire, fit tier, yard hire, upgrade rows, missile confirm, unlock line): 1 + log10(amount) discs (≤8, staggered 0.05 s), tier color by `amount` / income rate, not throttled; target = the button's center at purchase time
- Segment assembly start (`SegmentState.assemblies`, unsaved counter): 1 scrap disc HUD → tool head (only if the head is inside the scroll pane) + scrap bits and sparks falling onto the mech (`LineView.scrap_bits`, fx layer above belt mechs)
- Pile tap: 1 scrap disc, pile squashes + vibrates (±2 px); yard chunk: the worker runs into the pile, pile vibrates (±1 px), 1 scrap disc; mech: deploy 3 credits, per second 1 credit, salvage 2 scrap; bounty 8–20 credits

## Input
- Hand cursor on every button (via `Main` `node_added` hook → `Hover.button`; arrow while disabled) and tap area (`Hover.add`)
- Hover: theme `hover` style (`button_hover.png`), flat buttons and tap areas tint (`self_modulate`, tap area lights its `highlight`: machine, pile); all hover off on touchscreens (emulated mouse would leave it stuck)
- Battlefield: full-rect `TapArea` `FieldTap` → `tap_wave()`, nearest visible enemy flashes + puff; one credit disc per whole credit the HUD counter gains (≤5, none under 1) bursts from the tap point
- Taps: `TapArea` (`ui/tap_area.gd`): fires on `ScreenTouch` press (multi-touch) or real mouse press; ignores touch-emulated mouse; `MOUSE_FILTER_PASS` so drags reach `ScrollContainer`
- Buttons in the scroll pane use `MOUSE_FILTER_PASS`; scroll deadzone 8

## Art
- All sprites are PNGs in `art/`, generated by `tools/gen_placeholders.py` (PIL)
- Mech parts: 24×32 canvas, feet at bottom, layered by the type's `layer` (child order, not z_index); `art/mech/<type>_<tier>.png`, 6 tiers; frame is a 4-frame walk sheet (96×32), other parts bob on frames 1/3; Atomic Missile arms = the Nuclear Mech look
- Machines: `art/line/machine_<type>.png`, 80×56
- HUD icons 16×16 `art/ui/`, discs 10×10 `art/fx/disc_<kind>_<tier>.png`
- Enemies `art/battlefield/enemy_<sprite>_<variant>.png` (5 body colors), feet at bottom; workers 10×14 `art/line/worker.png`, `art/yard/worker.png`

## Commands
- Import: `godot --headless --path . --import`
- Scenario: `godot --headless --path . -- --scenario <m0..m8|intro>`; exit code 1 on failure; `Instrument.click` scrolls the target into view first
- Tuning: `godot --headless --path . -- --scenario tune`: bot plays a run (3 taps/s, builds, buys cheapest, applies tiers, pauses lines to save for applies); prints per-minute economy + purchase timeline; checks first worker < 4 min, nuke 30–60 min. Now: first worker 1.4 min, nuke ~33 min (1.5 taps/s: 2.5 / 36 min); the bot never taps the battlefield
- Screenshots: `godot --path . -- --scenario shots --shots <dir>` (windowed)
- Placeholders: `uv run --with pillow python3 tools/gen_placeholders.py`
- Templates: `tools/build_templates.sh [web|smoke]` → `build/templates/`; scons in `~/work/source/godot` (`GODOT_SRC`, at `4.7.2-stable`); web via emsdk 4.0.11 in `~/work/source/emsdk` (`EMSDK_DIR`), ~25 min for both; smoke = Linux `template_debug` in a `fedora:43` podman container (no host g++), `x11=no wayland=no vulkan=no accesskit=no` (vulkan=no: link error without x11/wayland)
- Template smoke: `tools/smoke_templates.sh [binary]` (default `build/templates/linux_smoke.x86_64`): "Linux smoke" preset (includes `tools/`) → `build/smoke/smoke.pck` next to the binary, runs m0–m8 + intro headless (templates refuse `--main-pack`)
- Web build: `tools/export_web.sh [debug|release]` → `build/web/`; debug build has the DBG panel; `build/.gdignore` keeps the editor from importing the exported PNGs
- Deploy: `tools/deploy_web.sh` → release build, `lftp` FTPS mirror (`--delete`, temp file + rename per file, `index.html` put last) via `www161.your-server.de` to `https://distco.de/games/scraptitans/`; credentials in gitignored `tools/deploy.env` (`FTP_HOST/USER/PASS/DIR`, FTP user chrooted to the game folder, so `FTP_DIR=/`); `FTP_VERIFY_CERT=false` if the host cert doesn't match
- Serve: `tools/serve_web.sh` → Caddy, `tls internal` (cert generated on the fly, untrusted: accept the browser warning), `https://localhost:8443`, `https://<lan-ip>:8443`, `Cache-Control: no-cache`; `LAN_IP` overrides detection

## Web templates
- Web preset uses `build/templates/web_{debug,release}.zip` (not in git: run `tools/build_templates.sh` first); release wasm 12.9 MB (brotli 2.6 MB) vs official 39.5 MB (7.1 MB)
- Profile `tools/web.gdbuild`: editor "Detect from Project" output minus `Script`, `ScrollBar` (kept to be safe) + fallback text server, advanced off, no brotli/graphite
- Flags: `threads=no production=yes lto=full optimize=size_extra deprecated=no disable_advanced_gui=yes modules_enabled_by_default=no` + gdscript, freetype, text_server_fb
- Textures: `lossless_compression/force_png` (default stores WebP, which would need the webp module)
- No svg module: default theme icons blank (game theme covers all used)
- `javascript_eval` on (default): `JavaScriptBridge` for Poki
- Disabled classes are still created lazily from C++ (`initialize_class`); only script/name access and unreferenced code go
- Game starts using a new engine class/format → re-detect profile, rebuild templates, smoke

## Web gotchas
- Secure context required (HTTPS or localhost)
- `user://` → IndexedDB synced on the next frame; hidden tabs get no frames → save-on-hide unreliable
