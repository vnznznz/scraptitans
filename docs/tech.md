# Tech

## Stack
- Godot 4.7.2, GL Compatibility, GDScript (static types)
- Web export, no threads; custom export templates (see Web templates)

## Display
- Viewport 360×640, stretch `canvas_items`, aspect `keep_width`
- Texture filter Nearest (project default)
- Font: Silkscreen (OFL), `fonts/`; import antialiasing/hinting/subpixel off; size 16 everywhere (2× pixel grid), 8 is illegible
- Silkscreen covers ASCII + Latin-1 only (no `→`, `⬆`…); import `allow_system_fallback=false`, so desktop shows missing glyphs like the web build (no system fonts there)
- `fonts/silkscreen_condensed.tres`: glyph spacing −1, segment names only (82 px label, wraps; long single words spill into the gutter)
- Theme `ui/theme.tres`: buttons/panels are nine-patch PNGs from `art/ui/`; variations `LitButton` / `PriceButton` (disabled looks normal), `LitRow` / `PriceRow` (2 px side margins, station rows)
- Prices (`ui/price.gd`): `Price.setup(button, kind, row)` once, `Price.show(button, text, affordable)` per frame: affordable = lit (green) + price in the currency color; else disabled, normal face, dim price. Build, hire, fit, yard hire, menu rows, unlock line

## Layout
- `scenes/main.tscn`: `Hud` (48) / `Battlefield` (160–320) / `Scroll` → `Content` (lines, `UnlockLine`; alignment end, so lines sit at the bottom near the thumb) / `BottomBar` (100: `Scrapyard` left, `Upgrades` bottom-right); overlays `UpgradeMenu` (between HUD and bottom bar), `Flyers`, `Debug`, `Settings`, `Nuke` (topmost, blocks input)
- Battlefield height = spare pane height (pane − content min height), clamped 160..320 (`Main.FIELD_MAX` 2×), set each frame; shrinks back to 160 as lines are added
- Draw order by `z_index` (`Main`): discs 1, HUD + wave bar text 2 (discs pass behind text), menu 2 (later in tree, covers wave text; bg 75 % opaque, row panels 85 %), purchase discs (`Flyers.pay`) 3 so they fly over the menu, intro guide 3, Debug/Settings/Nuke 4
- Scrapyard always visible in the bottom bar; pile/workers/tap in child `Yard`, centered until reveal, then slides left (0.4 s): pile (tap), yard workers on both sides, hire button (icon + cost, hidden when full) above UPGRADES; pane starts at the top
- Views build their children in code; main adds one `LineView` per line, more on `line_added`
- UPGRADES button toggles the menu (reads CLOSE while open); badge = `GameState.affordable_upgrades()` (visible, unmaxed, unlocked, affordable rows): red with count; hidden at 0 and while the menu is open
- UNLOCK LINE (`+ LINE n  cost`): 220×32 while unaffordable, 300×44 and lit once affordable
- Intro guide (`scenes/intro_guide.gd`, above `Layout`, no input): yellow pulsing label + bobbing arrow, step derived from state: short on scrap for the next build / a station stalled NO_SCRAP → pile; affordable → that station's Build button; all built → first station at or past the mech (past it once assembling / part fitted) whose bar isn't full, no arrow when none
- After the reveal: nothing bought yet (`levels` empty) and an upgrade affordable → `UPGRADE AVAILABLE` on UPGRADES, then `BUY IT` on the cheapest affordable row (`UpgradeMenu.first_affordable()`); else mechs on the field and `field_taps` < 3 → `TAP THE BATTLEFIELD…` pointing down at the enemies (`Battlefield.hint_anchor()`); otherwise hidden
- Progressive reveal: UPGRADES, UNLOCK LINE, YARD WORKER (+ yard slots) hidden until `GameState.revealed()` (`mechs_built > 0`); pause strips hidden until `stalled_once` (first NO_SCRAP stall, saved)
- HUD columns: scrap (x 6) / mechs built + `mechs_per_min` (x 112, icon bumps on deploy) / credits (x 214), gear right
- Window/tab title `(N) Scrap Titans` while N upgrades are affordable (after reveal, before the nuke); `DisplayServer.window_set_title` = `document.title` on web (inside Poki's iframe it won't reach the tab)
- Upgrade menu: one list of unmaxed rows, re-sorted every frame by cost; maxed rows hidden, listed in a `MAXED` footer (tier rows by their part name); no MAX text anywhere
- Menu rows: title / effect, info button toggles the `desc` label. Tier row: next part name / `LIFE a » b S`, `PAY a » b/S` or `DMG a » b` (from its stat, `0` before a first unlock); final row: `ENDS THE WAR` / `NEEDS <part>`; lines row `LINE n`; other rows `a » b` + level pips (3 px, `Pips` in `upgrade_menu.gd`)
- Line: no header row; pause strip (24 px, one button from name row to belt: scrap icon, meter = line scrap use / gross scrap gain, ⏸/▶) left of the stations; segments centered by count in the rest (full width while the strip is hidden; step 84, 4 columns fit), re-laid out when a segment is appended or the strip appears; 136 px tall; paused → meter dimmed, machines dimmed; meter red while a station of the line is out of scrap
- Segment rows: header (type name, condensed, + stat icon: `life` / `credits` / `damage` by the tier's stat; PLATING spills 1 px into the gutter) / machine (tap; work bar overlays its top beam, hired workers stand inside behind the mech, empty slots not drawn) / belt / one button row (82 px): hire (worker icon + cost, condensed) while slots are free; ⬆ fit while a higher tier is unlocked: 20 px icon-only beside hire, or the whole row with its scrap price when the station is full; nothing to buy → empty row
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
- Tiers: `unlocked_tier(type)` = level of generated row `tier_<type>` (+ `final_<type>`), −1 for optional; `apply_tier` jumps a segment to the highest unlocked tier for the sum of the skipped `apply_cost`s (all or nothing); parts record the segment tier at attach time
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
- Stall icon: NO_SCRAP at once, BLOCKED only after 3 s of game time in that state (view-side timer); the first NO_SCRAP sets `stalled_once` (saved)
- `starved()`: any segment stalled NO_SCRAP → HUD scrap +/s red
- Wave: `wave`, `wave_hp`; drains by summed mech `dps`; ≤0 → bounty, `wave += 1`, full HP. `hp = base_hp·hp_growth^wave`, bounty likewise; `bounty_growth` > `hp_growth`, so later waves pay more per HP
- Wave enemies `Data.wave_enemies(wave)` (cached in `GameState.wave_enemies()`): type `types[wave % n]`, + next type from `mix_from`, + third from `mix_all_from`; count `type.count·(1 + count_growth·wave)/kinds`, scaled to ≤ `max_enemies`; variant `wave / variant_every` (fraction → that share already next variant), capped `variants − 1`; weight `type.weight·variant_tough^variant`; sorted by weight (weakest pops first)
- Battlefield tap `tap_wave()`: `tap_damage` seconds of `max(field_dps, tier 1 Arms dps)` as damage, no credits; counts `field_taps` (saved, intro hint); `_damage_wave` shared with DPS drain (kill scrap, clear)
- Pile tap `tap_scrap()` = `scrap_per_tap` + `tap_yard_share` (Pile tap row) · yard scrap/s (`yard_rate()`)
- `wave_alive()`: enemies whose cumulative weight share isn't drained yet. Each pop pays `kill_scrap`·`variant_scrap`^variant scrap (`enemy_killed`); a cleared wave pays the rest
- Stats: `GameState.stat(key)` = base + Σ delta·level, cached, cleared on purchase/load. Key `type.field` → `segments.json`, else `economy.json`. Salvage clamped to `salvage_cap`
- Upgrade cost `base_cost·growth^level`, growth = row `cost_growth` or `upgrade_cost_growth`; `lines` stat > line count → append `LineState`, emit `line_added`
- Nuke: a deployed mech with a `final` part sets `run_over` (sim stops, saved) and emits `nuke_launched`
- Signals: `purchased` (also pause, nuke; triggers save), `mech_deployed`, `mech_income`, `mech_died`, `wave_cleared`, `enemy_killed`, `line_added`, `segment_added`, `nuke_launched`

## Data
- Tunables only in `data/*.json`: `economy.json` (global stat bases), `segments.json` (`line_slots`, `types` → desc, worker cost/slots, tiers array with `bar_size`), `enemies.json` (HP/bounty curves, wave mix/growth/variants, `types`: count, weight, sprite, flying), `upgrades.json` (`rows`: id, name, desc, stat, delta, max_level, base_cost, optional `cost_growth`, unit `s`/`x`/`%`; rows on an optional type's stat hidden until it unlocks)
- Economy shape: tier unlocks ×12–17 per tier (frame 80 → 2.6M, types staggered ×1–1.7), fit `apply_cost` 30/300/2K/10K/40K, `scrap_per_mech` ×2–2.5 per tier from tier 2 (scrap tight after fits and new lines; yard rows and salvage loosen it); upgrade rows `upgrade_cost_growth` 2.3 over 10–20 levels (yard crew 1.8, pay raises 4); lines 500·13^n; Atomic Missile 3.2M, cheaper than the last Core/Plating tiers so the final wait stays short
- Tier/final row descs built by the menu from the type `desc` / final tier `desc`
- Tier unlock rows generated by `Data` from `segments.json` tiers (`unlock_cost`, `apply_cost`); a tier with `final: true` (Atomic Missile) gets its own row `final_<type>`, locked until the rest are unlocked, confirm dialog before buying
- New save fields read with `.get` defaults, so `version` stays 1

## Battlefield
- Wave bar at top (`WaveBar`): `WAVE n` left, `x DMG/S` right = `wave_dps()` (mech DPS + `tap_dps`); the bar alone shows HP
- Taller than 160: bg, enemies, mechs and fx live in `World` (Node2D), shifted down by the extra height; the sky above is filled with the bg's top color (`_draw`)
- Layers: `bg.png` (sky, ruins, ground), `smoke.png` tiled and drifting (`SMOKE_SPEED`), sky above filled with `Pal.NAVY`
- Enemies right side, y-sorted layer; air and ground each spread left→right in pop order, clamped inside the field; visible = `wave_alive()`; flyers bob; `enemy_<sprite>_<variant>.png`, sprites grow per variant (variant 5 brute = boss); shots `enemy_shot_<sprite>.png`
- `DamageFx` (`scenes/damage_fx.gd`): dark smoke plume ×3 / flames / sparks by remaining share; mechs (lifetime) and enemies (wave HP left) share it
- `Fx` (`scenes/fx.gd`, static): `explosion` (6-frame sheet, `big` 40 px), `hit`, `puff`, `trail`/`detach` (rocket smoke), `debris`, `sparks`
- Wave cleared: explosions on the survivors + center, sparks, bounty disc burst, shake, next wave walks in from the right
- Mechs: max 24 drawn (3 rows × 8 at y 156/141/126, back rows darker, drawn behind), rest simulated only; slots fill spread out (`FILL_ORDER`), ±3 px jitter; walk in with 4-frame cycle, fire every 0.8–1.6 s; enemies fire back, hit flashes the mech
- Shots by Arms tier: slug, bolt, 3-round tracer burst, arcing rocket with smoke trail + explosion, railgun beam (1×3 texture stretched); muzzle flash + 1 px arm recoil
- Nuclear Mech: own sprite (`nuclear.png`, 2×), own spot `NUKE_POS` (slot −1), walks slower; the others stop firing and step aside (`ASIDE`)
- Damage from `remaining()` (1 − wear/lifetime): smoke <40/25/15 % (flames from the third stage), sparks <8 %, death = big explosion + debris
- Income discs: per-second discs throttled to ~10/s overall; deploy 2–6 discs by log10(fee); popped enemy 2 scrap discs with kill scrap

## Nuke
- `Nuke` (`scenes/nuke.gd`, refs battlefield/scroll/content/scrapyard): Nuclear Mech walks in → missile launches from its silo (explosion, smoke trail) and arcs off-screen → white → yellow → orange flash, 8-frame mushroom (battlefield scorched, ground explosions), screen shake (whole `Layout`) → `shockwave.png` band sweeps the pane with auto-scroll, `collapse()` on each content child (lines → explosions, debris, rubble), then the yard (pile only) → run card (mushroom icon, `THE WAR IS OVER`, time/mechs/credits counting up, lit START AGAIN) = `Save.reset_run`
- Loaded with `run_over`: everything collapsed, card shown

## Income feedback
- No floating numbers. `Flyers.spawn(kind, global_pos, amount, count)` (`ui/flyers.gd`): disc bursts up, flies to `Hud.target(kind)`, `Hud.pulse(kind)` on arrival; max 48 in flight
- Disc color tier by `amount` / current gross rate (`Flyers.tier`): <2 s of income tier 1, <10 s tier 2, else tier 3; `disc_<kind>_<1..3>.png`; burst up, then a curved flight (quadratic bezier) to the counter
- Quiet discs: tier 1 scrap while gross scrap ≥ `QUIET_RATE` (30/s): ≤ 5/s, one disc, 6 px `_s` texture, fades to 35 %, no HUD pulse; pile taps always loud
- Spending: `Flyers.spend(kind, to, amount)`: disc leaves the HUD counter (icon `pulse_out`) and flies into the target; ≤6/s, dropped at the in-flight cap
- Purchases: `Flyers.pay(kind, button, amount)` after a successful buy (build, hire, fit tier, yard hire, upgrade rows, missile confirm, unlock line): 1 + log10(amount) discs (≤8, staggered 0.05 s), tier color by `amount` / income rate, not throttled; target = the button's center at purchase time
- Segment assembly start (`SegmentState.assemblies`, unsaved counter): 1 scrap disc HUD → tool head (only if the head is inside the scroll pane) + scrap bits and sparks falling onto the mech (`LineView.scrap_bits`, fx layer above belt mechs)
- Pile tap: 1 scrap disc, pile squashes + vibrates (±2 px); yard chunk: the worker runs into the pile, pile vibrates (±1 px), 1 scrap disc; mech: deploy 3 credits, per second 1 credit, salvage 2 scrap; bounty 8–20 credits

## Input
- Hand cursor on every button (via `Main` `node_added` hook → `Hover.button`; arrow while disabled) and tap area (`Hover.add`)
- Hover: theme `hover` style (`button_hover.png`), flat buttons and tap areas tint (`self_modulate`, tap area lights its `highlight`: machine, pile); all hover off on touchscreens (emulated mouse would leave it stuck)
- Battlefield: full-rect `TapArea` `FieldTap` → `tap_wave()`, nearest visible enemy flashes + puff; no discs (taps pay no credits)
- Taps: `TapArea` (`ui/tap_area.gd`): fires on `ScreenTouch` press (multi-touch) or real mouse press; ignores touch-emulated mouse; `MOUSE_FILTER_PASS` so drags reach `ScrollContainer`
- Buttons in the scroll pane use `MOUSE_FILTER_PASS`; scroll deadzone 8

## Art
- All sprites are PNGs in `art/`, generated by `tools/gen_art.py` (PIL); one palette (Endesga 32, `PALETTE`), 1 art px = 1 base px everywhere (no scaled sprites except particles and the beam); code colors from `Pal` (`ui/pal.gd`)
- Tier colors (all part types): rust, iron, steel, blue composite, gold titan, atomic green; each part tier also has its own shape
- Mechs: cell 40×48, feet at the bottom; frame silhouette grows with tier (torso 13→26 px, legs 8→15 px); `frame_<t>.png` = 4-frame walk sheet (160×48, body bobs on 1/3); `core|arms|plating_<t>.png` = 6 cells, one per frame tier (parts fit the torso), `MechView` picks `frame = frame tier`; layered by the type's `layer`; `art/mech/rig.json` (written by the generator): per frame tier `chest`, `top`, `muzzle[frame][arms]`, plus `nuke_muzzle` / `nuke_chest`, relative to the feet
- Nuclear Mech `mech/nuclear.png`: 4-frame sheet, 72×88 cells; Atomic Missile arms on the belt = shoulder missile
- Machines: `art/line/machine_<type>_<0..2>.png`, 80×56: 0 idle, 1–2 working (alternating at 11 fps while assembling); press (frame), glass dome (core), gun rack + robot arm (arms), plate rollers (plating); work bar overlays the top beam
- Pile `art/yard/pile_<1..3>.png` (same 112×64 canvas) by scrap stock in seconds of gross gain: <5 s, <30 s, more
- HUD icons 16×16 `art/ui/` (stat icons `life.png`, `damage.png`, credits reused; `nuke.png` card icon), discs 10×10 (+ 6×6 `_s`) `art/fx/disc_<kind>_<tier>.png`; buttons/panel 12×12 nine-patch, `button_lit.png` = affordable face
- Fx: `shot_1..4`, `beam`, `muzzle(_big)`, `hit`, `explosion(_big)` sheets, `mushroom.png` (8 frames, 168×156), `missile.png`, `shockwave.png`, `debris(_big)`, `puff`, `smoke_small`, `spark`
- Enemies `art/battlefield/enemy_<sprite>_<variant>.png` (5 body colors, bigger per variant), feet at bottom, facing left; workers 10×14 `art/line/worker.png`, `art/yard/worker.png`

## Commands
- Import: `godot --headless --path . --import`
- Scenario: `godot --headless --path . -- --scenario <m0..m9|intro|art>`; exit code 1 on failure (2 on unknown scenario or script parse error); `Instrument.click` scrolls the target into view first; windowed `m9 --shots <dir>` also saves tall-phone (360×780) and 2× (720×1280) shots
- Tuning: `godot --headless --path . -- --scenario tune [--profile <name>]`: bot runs (3 taps/s: pile while short on scrap or saving for a fit, else the emptiest station bar; builds, buys cheapest, fits tiers, pauses all lines while a fit isn't reachable in 60 s). Profiles: `baseline`, `casual` (1.5 taps/s), `field` / `third` (all / ⅓ of taps on the battlefield after the reveal), `quit10` (no taps after 10 min), `no_arms` (never fits Arms, except the missile), `no_pause`. Prints a summary row per profile (nuke min, bounty share of credits, NO_SCRAP share, phases ≥ 10 s (stalls < 30 s apart merge), longest wait between buys, first fit, final wait before the missile, first regular row maxed, tap share of scrap / of station work); per-minute economy + timeline for baseline or the named profile; checks the M9 targets
- Tuning now: baseline 37 min (casual 43, field 35, third 33.5, quit10 44, no_arms 44, no_pause 39); bounties 36 %; NO_SCRAP 10 % in 9 phases; longest wait 80 s; first fit 2.2 min; final wait 28 s; first row maxed 21 min
- Screenshots: `godot --path . -- --scenario shots --shots <dir>` (windowed)
- Art: `uv run --with pillow python3 tools/gen_art.py`, then import
- Art shots: `godot --path . -- --scenario art --shots <dir>` (windowed): full mixed-tier field at wave 27 with one hurt mech, 3 lines of high-tier stations, then the whole nuke sequence
- Templates: `tools/build_templates.sh [web|smoke]` → `build/templates/`; scons in `~/work/source/godot` (`GODOT_SRC`, at `4.7.2-stable`); web via emsdk 4.0.11 in `~/work/source/emsdk` (`EMSDK_DIR`), ~25 min for both; smoke = Linux `template_debug` in a `fedora:43` podman container (no host g++), `x11=no wayland=no vulkan=no accesskit=no` (vulkan=no: link error without x11/wayland)
- Template smoke: `tools/smoke_templates.sh [binary]` (default `build/templates/linux_smoke.x86_64`): "Linux smoke" preset (includes `tools/`) → `build/smoke/smoke.pck` next to the binary, runs m0–m9, intro, art headless (templates refuse `--main-pack`)
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
