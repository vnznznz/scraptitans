# Tech

## Stack
- Godot 4.7.2, GL Compatibility, GDScript (static types)
- Web export, no threads; custom export templates (see Web templates)

## Display
- Viewport 360×640, stretch `canvas_items`, aspect `keep_width`
- Texture filter Nearest (project default)
- Font: Silkscreen (OFL), `fonts/`; import antialiasing/hinting/subpixel off; size 16 everywhere (2× pixel grid), 8 is illegible
- Silkscreen covers ASCII + Latin-1 only (no `→`, `⬆`…); import `allow_system_fallback=false`, so desktop shows missing glyphs like the web build (no system fonts there)
- `fonts/silkscreen.tres` (theme default): spacing top −2 / bottom +1 → 20 px line box, caps (10 px) centered in it, so any label/button centered vertically looks centered
- `fonts/silkscreen_condensed.tres`: same spacing, glyph spacing −1, segment names only (82 px label, wraps; long single words spill into the gutter)
- Theme `ui/theme.tres`: buttons/panels are nine-patch PNGs from `art/ui/`; variations `LitButton` / `PriceButton` (disabled looks normal), `LitRow` / `PriceRow` (2 px side margins, station rows)
- Prices (`ui/price.gd`): `Price.setup(button, kind, row)` once: moves the button icon + a label into a centered `Price` HBox (icon left, gap 4 or the button's `h_separation` override; Godot centers text only in the space right of the icon); `Price.text/color(b)` read it; `Price.show(button, text, affordable)` per frame (also nudges the group 1 px down while pressed): affordable = lit (green) + price in the currency color; else disabled, normal face, dim price. Build, line hire, fit, yard hire, menu rows, unlock line

## Layout
- `scenes/main.tscn`: `Hud` (48) / `Battlefield` (160–320) / `Scroll` → `Content` (separation 0: lines stack flush; `UnlockGap` 8 + `UnlockLine`; alignment end, so lines sit at the bottom near the thumb) / `BottomBar` (100: `Scrapyard`); overlays `UpgradeMenu` (HUD to screen bottom), `Upgrades` (bottom-right, 114×42, after the menu in the tree + menu z, so it stays on top as CLOSE), `Flyers`, `Debug`, `Settings`, `Nuke` (topmost, blocks input)
- Battlefield height = spare pane height (pane − content min height), clamped 160..320 (`Main.FIELD_MAX` 2×), set each frame; shrinks back to 160 as lines are added
- Draw order by `z_index` (`Main`): discs 1, HUD + wave bar text 2 (discs pass behind text), menu 2 (later in tree, covers wave text; bg 75 % opaque, row panels 85 %), UPGRADES 2 (after the menu), purchase discs (`Flyers.pay`) 3 so they fly over the menu, intro guide 3, Debug/Settings/Nuke 4
- Scrapyard always visible in the bottom bar; pile/workers/tap in child `Yard`, centered until reveal, then slides left (0.4 s): pile (tap), yard workers on both sides, hire button (114×42, icon + cost, hidden when full) 4 px above UPGRADES; pane starts at the top
- Pile size sprite by scrap stock in seconds of yard worker output (`yard_rate()`), not gross gain (taps/salvage bursts shrank it)
- Pile squash (0.12 s, frame clock): a weaker hit never interrupts a running one; yard hits ≥ 0.2 s apart, taps ≥ 0.06 s, so a busy yard bounces instead of staying flattened
- Views build their children in code; main adds one `LineView` per line, more on `line_added`
- UPGRADES button toggles the menu (reads CLOSE while open); badge = `GameState.affordable_upgrades()` (visible, unmaxed, unlocked, affordable rows): red with count; hidden at 0 and while the menu is open
- Button heights: 44 main (build, menu buy, dialogs, big unlock), 42 bottom bar, 25 bar buttons (line hire, fit)
- UNLOCK LINE (`+ LINE n  cost`): 220×36 while unaffordable, 300×44 and lit once affordable
- Intro guide (`scenes/intro_guide.gd`, above `Layout`, no input): yellow pulsing label + bobbing arrow, step derived from state: short on scrap for the next build / a station stalled NO_SCRAP → pile; affordable → that station's Build button; all built → first station at or past the mech (past it once assembling / part fitted) whose bar isn't full, no arrow when none
- After the reveal: nothing bought yet (`levels` empty) and an upgrade affordable → `UPGRADE AVAILABLE` on UPGRADES, then `BUY IT` on the cheapest affordable row (`UpgradeMenu.first_affordable()`); else mechs on the field and `field_taps` < 3 → `TAP THE FIELD TO HIT THE WAVE` pointing down at the enemies (`Battlefield.hint_anchor()`); otherwise hidden
- Progressive reveal: UPGRADES, UNLOCK LINE, YARD WORKER (+ yard slots), line crew bars hidden until `GameState.revealed()` (`mechs_built > 0`); pause strips hidden until `stalled_once` (first NO_SCRAP stall, saved)
- HUD columns (`Hud.COLUMN_W` 91 from x 6, rate under the icon; widest rate `+99.9K/S` 90 px): scrap / mechs built + `mechs_per_min` (icon bumps on deploy) / credits; mute toggle + gear right (40 each, flat)
- Window/tab title `(N) Scrap Titans` while N upgrades are affordable (after reveal, before the nuke); `DisplayServer.window_set_title` = `document.title` on web (inside Poki's iframe it won't reach the tab)
- Upgrade menu: one list of unmaxed rows, re-sorted every frame by cost; maxed rows hidden, listed in a `MAXED` footer (tier rows by their part name); no MAX text anywhere; footer strip (`Footer` Panel, `FOOTER_H` 54, blocks the pile) under CLOSE, list ends 6 px above it
- Menu rows: title / effect, info button toggles the `desc` label. Tier row: next part name / `LIFE a » b S`, `PAY a » b/S` or `DMG a » b` (from its stat, `0` before a first unlock); final row: `ENDS THE WAR` / `NEEDS ALL PARTS`; lines row `LINE n`; other rows `a » b` + level pips (3 px, `Pips` in `upgrade_menu.gd`)
- Line: crew bar on top (26 px, after reveal): `CREW n/slots` left (dimmed at 0 slots), hire button (worker icon + cost, 120 px) flush right, hidden when full; pause strip (24 px, flat button from under the bar to the belt: scrap icon, meter = line scrap use / gross scrap gain, ⏸/▶) left of the stations; bar + strip drawn as one L frame (`_draw_frame`: SLATE_D fill, SLATE top/left light, INK inner edge); segments centered by count right of the strip (full width while it's hidden; step 84, 4 columns fit), re-laid out when a segment is appended, the strip or the bar appears; 115 px tall (89 before reveal); paused → meter dimmed, machines dimmed; meter red while a station of the line is out of scrap
- Segment rows (89 px): header 25 (type name, condensed, + stat icon: `life` / `credits` / `damage` by the tier's stat; PLATING spills 1 px into the gutter), replaced by the ⬆ fit button (82 px, scrap price) while a higher tier is unlocked / machine (tap; work bar overlays its top beam, the line's crew stands inside behind the mech, `LineState.station_workers`) / belt
- Settings overlay (⚙, `scenes/settings_overlay.gd`): modes SETTINGS (volume rows, CREDITS, RESET RUN, CLOSE) / CONFIRM (YES, RESET, CANCEL) / CREDITS (`CREDITS` const: gold headings, condensed lines, OPEN SOURCE LICENSES, BACK); URLs are plain text, no links out of the game (Poki)
- Licenses popup (Godot MIT + third-party notices, the in-game equivalent of shipping `COPYRIGHT.txt`): `SettingsOverlay.license_text()` from `Engine.get_license_text` / `get_copyright_info` / `get_license_info` (compiled into every build from the engine's `COPYRIGHT.txt`, so it matches the engine version), license paragraphs reflowed; built on first open (~120 ms desktop) as ~90 labels of ≤ 1200 chars in a ScrollContainer, so off-screen text isn't drawn
- DBG toggle top-left under the wave bar (hidden while the menu is open), panel opens downward: time scale, +scrap/credits, kill wave, +50 mechs
- Positions hardcoded in base pixels

## Autoloads
- `Data`: loads `data/*.json`
- `GameState`: sim; fixed tick 1/30 s × `time_scale`; frame delta clamped to 0.25 s (no offline progress); `advance(s)` for instrumentation
- `Save`: `user://save.json`, `version` 1; every 5 s, after purchases, on focus out/close
- `Instrument`: no-op unless `--scenario` user arg; `Sound.shutdown()` + 0.1 s before quitting (streams still playing at exit leak)
- `Sound`: audio (see Audio)

## Sim
- Naming: code "segment" = player-facing "station" (all UI text and the pitch say station)
- `sim/`: `LineState` → `SegmentState` → `MechState`; plain `RefCounted`, `to_dict`/`from_dict`
- Views never mutate state except through `GameState` methods; they read it every frame
- Segment types in `line_slots` order; `optional` types (Plating) are appended to every line once their tier 1 is unlocked; line complete = all non-optional built; last built segment deploys
- Tiers: `unlocked_tier(type)` = level of generated row `tier_<type>` (+ `final_<type>`), −1 for optional; `apply_tier` jumps a segment to `apply_target` for the sum of the skipped `apply_cost`s (all or nothing); `apply_target` = highest unlocked tier, capped at `top_tier` (best non-final) until `line_maxed` (every segment built and at `top_tier`), so the missile only fits on a fully upgraded line; parts record the segment tier at attach time
- Segment: work banks up to bar size; full bar + mech (Frame: free slot, line complete) + scrap → assemble; one mech per segment; `stall` NONE / NO_SCRAP / BLOCKED
- Line processed last → first each tick; paused line starts no assembly (mechs already done still move/deploy)
- Workers: per line `workers` (crew), `worker_t += dt·workers`, one chunk per `worker_interval` to the built station with the emptiest bar (by fraction; full bars skipped, chunk lost if all full). Shown spread round robin over built stations. Old saves: segment `workers` summed into the line. Yard workers same, add `yard_chunk` scrap. `chunks` (per segment) / `yard_chunks` counters (unsaved) drive the view hops
- Bar size = tier `bar_size` × stat `bar_mult` (grows with the segment's tier)
- Yard chunk = `yard_chunk` (Yard haul row) × `worker_chunk`; line crew cap = `worker_slots` (Crew size row) × built stations
- Hire cost `worker_base·worker_growth^n` (`economy.json`, 50·1.1^n), n = the line's crew
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

## Audio
- Design, rules, sound assignment: [audio.md](audio.md); tunables `data/audio.json` (`Data.audio`)
- Files: `audio/sfx/<pack file name>.wav` (converted with ffmpeg from `assets/__import`: mono 32 kHz, beds 22.05 kHz), `audio/music/ending.wav` (mono 32 kHz); `importer_defaults/wav` = QOA + mono; beds `edit/loop_mode=2` (Forward) in their `.import`
- Buses `Music`, `Sfx`, `Ambience` → `Master`, created in code (no `default_bus_layout.tres`, `AudioBusLayout` stays out of the build)
- `Sound.play(id, gain_db)`: dropped inside `cooldown`, at `voices`, over its `group`'s plays/s, or with the 16-player pool full; random file without direct repeat, `pitch` jitter × `pitch_base`, `volume_db` + `file_db[file]` + area gain; a player counts as busy until stream length / pitch (own clock, not `playing`)
- Areas: `Sound.presence[area]` 0..1 set by Main each frame from `Sound.visible_share(control)` (share of its height inside the viewport and every `ScrollContainer` above it): `field` = Battlefield, `factory` = Content, `yard` = Scrapyard; gain lerps `hidden_db` → 0 dB; applies to beds and sounds with an `area`. A single scroll pane later only needs these three controls
- Beds (bus Ambience, looped, started at boot): gain `clamp(drive / full)` smoothed over `smooth` s × area gain; `Sound.drives` set by Main: `assembly_rate` (assemblies in the last 4 s real time / 4: pausing or starving quiets the factory), `mechs` (drawn mechs)
- Music: armed `first_after` s after the reveal, then `gap` after each play; fade in/out on its own clock (playback position isn't reliable for web samples); ducks `Ambience`; `stop_music` on nuke launch and `Save.reset_run` (next run waits `first_after` again); run card plays it after 1.5 s (tween on the card, so a reload cancels it)
- Settings `user://settings.json` (`muted`, `music`/`sfx`/`ambience` steps 0–5), not in the run save; step → `linear_to_db((step / 5)²)`, 0 mutes the bus; HUD mute = `Master` mute; settings rows `-` pips `+`
- Buttons: `Sound.hook_button` via Main's node hook plays `click`, unless meta `silent` (buttons with their own sound: build, fit, hire, buy rows, unlock line, UPGRADES, pause, gear, settings close)
- On screen only: assembly when the tool head is inside the scroll pane (same check as the scrap disc), `mech_exit` when > half the line is visible; shots only from drawn mechs
- Nuke alarm repeats every 2.9 s while the Nuclear Mech walks in (the file doesn't loop)
- Web: sample playback (Godot default for web): no bus effects; music registered as a sample at boot (`register_stream_as_sample`, decode hitch), the rest on first play; hidden tab → `Master` muted via `visibilitychange` (`JavaScriptBridge`), since Web Audio loops play on without frames; audio starts on the first input; `Sound.ad_mute(on)` for Poki ads

## Data
- Tunables only in `data/*.json`: `economy.json` (global stat bases, line worker cost), `segments.json` (`line_slots`, `types` → desc, tiers array with `bar_size`), `enemies.json` (HP/bounty curves, wave mix/growth/variants, `types`: count, weight, sprite, flying), `upgrades.json` (`rows`: id, name, desc, stat, delta, max_level, base_cost, optional `cost_growth`, unit `s`/`x`/`%`; rows on an optional type's stat hidden until it unlocks)
- Economy shape: tier unlocks ×12–17 per tier (frame 80 → 1.95M, types staggered ×1–1.7; each type's top tier and the missile ×0.75 since the missile waits for all of them), fit `apply_cost` 30/300/2K/10K/40K, `scrap_per_mech` ×2–2.5 per tier from tier 2, tiers 3–4 ×1.12 (mid game scrap-tight: pausing gets fits sooner); Lean build (`scrap_mult`, −6 %/level ×8, from 25K credits, growth 2) and yard/salvage/kill rows loosen the late game, so never pausing isn't stuck; salvage cap 60 %; upgrade rows `upgrade_cost_growth` 2.3 over 8–20 levels (yard crew 1.8, pay raises 4); lines 500·13^n; Atomic Missile 2.4M, bought after the last Core/Plating tiers (3.3M)
- Part scrap cost = tier `scrap_per_mech` × `scrap_mult` (`SegmentState.scrap_cost()`)
- Tier/final row descs built by the menu from the type `desc` / final tier `desc`
- Tier unlock rows generated by `Data` from `segments.json` tiers (`unlock_cost`, `apply_cost`); a tier with `final: true` (Atomic Missile) gets its own row `final_<type>`, locked (`upgrade_locked`) until every `tier_*` row is maxed, no confirm: effect `ENDS THE WAR`, desc starts "Ends the war"
- New save fields read with `.get` defaults, so `version` stays 1

## Battlefield
- Wave bar at top (`WaveBar`): `WAVE n` left, `x DMG/S` right = `wave_dps()` (mech DPS + `tap_dps`); the bar alone shows HP
- Taller than 160: bg, enemies, mechs and fx live in `World` (Node2D), shifted down by the extra height; the sky above is filled with the bg's top color (`_draw`)
- Layers: `bg.png` (sky, ruins, ground), `smoke.png` tiled and drifting (`SMOKE_SPEED`), sky above filled with `Pal.NAVY`
- Enemies right side, y-sorted layer; air and ground each spread left→right in pop order, clamped inside the field; visible = `wave_alive()`; flyers bob; `enemy_<sprite>_<variant>.png`, sprites grow per variant (variant 5 brute = boss); shots `enemy_shot_<sprite>.png`
- `DamageFx` (`scenes/damage_fx.gd`): dark smoke plume ×3 / flames / sparks by remaining share; mechs (lifetime) and enemies (wave HP left) share it
- `Fx` (`scenes/fx.gd`, static): `explosion` (6-frame sheet, `big` 40 px), `hit`, `puff`, `trail`/`detach` (rocket smoke), `debris`, `sparks`
- Wave cleared: explosions on the survivors + center, sparks, bounty disc burst, shake, next wave walks in from the right
- Mechs: max 24 drawn (3 rows × 8 at y 156/141/126, back rows darker, drawn behind), rest simulated only; slots fill spread out (`FILL_ORDER`), ±3 px jitter; `Battlefield.score` = Σ(part tier + 1): a better undrawn mech replaces the weakest drawn one (fades out), and a stronger mech behind a weaker one swaps slots with it (strict, so equals never shuffle; not during the nuke), so the best stand in the front row; walk 64 px/s (anim ×1.6), also diagonally between rows; 4-frame cycle, fire every 0.8–1.6 s; enemies fire back, hit flashes the mech
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
- Purchases: `Flyers.pay(kind, button, amount)` after a successful buy (build, hire, fit tier, yard hire, upgrade rows, unlock line): 1 + log10(amount) discs (≤8, staggered 0.05 s), tier color by `amount` / income rate, not throttled; target = the button's center at purchase time
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
- Scenario: `godot --headless --path . -- --scenario <m0..m9|intro|ui|art|audio>`; exit code 1 on failure (2 on unknown scenario or script parse error); `Instrument.click` scrolls the target into view first; windowed `m9 --shots <dir>` also saves tall-phone (360×780) and 2× (720×1280) shots
- Audio check: `--scenario audio` (windowed `--shots` for `audio_hud`, `audio_settings`): files load, beds loop, code and `audio.json` use the same ids (editor only: exported scripts are binary), taps/buys/menu sounds, mute + volume steps + settings file, area gain, busy field (3 lines, 50 mechs, ×10) within the field budget and voice caps, beds follow drives, music schedule/duck/fades, reset run stops music
- UI check: `--scenario ui` (windowed `--shots` for `ui_lines`, `ui_menu`, `ui_menu_end`, `ui_credits`, `ui_licenses`): caps centered in the font line box, every visible price group centered in its button (±1 px), bottom bar buttons, menu to the bottom, footer, CLOSE clickable over the menu
- Tuning: `godot --headless --path . -- --scenario tune [--profile <name>]`: bot runs (3 taps/s: pile while short on scrap or saving for a fit, else the emptiest station bar; builds, buys cheapest, fits tiers, pauses all lines while a fit isn't reachable in 60 s of net scrap but is within 30 s of gross). Profiles: `baseline`, `casual` (1.5 taps/s), `field` / `third` (all / ⅓ of taps on the battlefield after the reveal), `quit10` (no taps after 10 min), `no_arms` (never fits Arms, except the missile), `no_pause`. Prints a summary row per profile (nuke min, bounty share of credits, NO_SCRAP share, phases ≥ 10 s (stalls < 30 s apart merge), longest wait between buys, first fit, final wait before the missile, first regular row maxed, tap share of scrap / of station work); per-minute economy + timeline for baseline or the named profile; checks the M9 targets
- Pause checks: pausing gets some L1 fit ≥ 60 s sooner than never pausing; never pausing ends within 10 % of baseline with no wait between buys > 150 s
- Tuning now: baseline 40.7 min (casual 45.9, field 37.9, third 35.7, quit10 49.6, no_arms 44.7, no_pause 42.0, longest wait 68 s); pausing gets the L1 Railgun 168 s sooner; bounties 33 %; NO_SCRAP 14 % in 9 phases; longest wait 68 s; first fit 2.2 min; final wait 36 s; first row maxed 22 min
- Screenshots: `godot --path . -- --scenario shots --shots <dir>` (windowed)
- Art: `uv run --with pillow python3 tools/gen_art.py`, then import
- Art shots: `godot --path . -- --scenario art --shots <dir>` (windowed): full mixed-tier field at wave 27 with one hurt mech, 3 lines of high-tier stations, then the whole nuke sequence
- Templates: `tools/build_templates.sh [web|smoke]` → `build/templates/`; scons in `~/work/source/godot` (`GODOT_SRC`, at `4.7.2-stable`); web via emsdk 4.0.11 in `~/work/source/emsdk` (`EMSDK_DIR`), ~25 min for both; smoke = Linux `template_debug` in a `fedora:43` podman container (no host g++), `x11=no wayland=no vulkan=no accesskit=no` (vulkan=no: link error without x11/wayland)
- Template smoke: `tools/smoke_templates.sh [binary]` (default `build/templates/linux_smoke.x86_64`): "Linux smoke" preset (includes `tools/`) → `build/smoke/smoke.pck` next to the binary, runs m0–m9, intro, ui, art, audio headless (templates refuse `--main-pack`); the templates have no regex module, so scenarios can't use `RegEx`
- Web build: `tools/export_web.sh [debug|release]` → `build/web/`; debug build has the DBG panel; `build/.gdignore` keeps the editor from importing the exported PNGs
- Deploy: `tools/deploy_web.sh` → release build, `lftp` FTPS mirror (`--delete`, temp file + rename per file, `index.html` put last) via `www161.your-server.de` to `https://distco.de/games/scraptitans/`; credentials in gitignored `tools/deploy.env` (`FTP_HOST/USER/PASS/DIR`, FTP user chrooted to the game folder, so `FTP_DIR=/`); `FTP_VERIFY_CERT=false` if the host cert doesn't match
- Serve: `tools/serve_web.sh` → Caddy, `tls internal` (cert generated on the fly, untrusted: accept the browser warning), `https://localhost:8443`, `https://<lan-ip>:8443`, `Cache-Control: no-cache`; `LAN_IP` overrides detection

## Web templates
- Web preset uses `build/templates/web_{debug,release}.zip` (not in git: run `tools/build_templates.sh` first); release wasm 13.0 MB (brotli 2.67 MB) vs official 39.5 MB (7.1 MB); pck 1.9 MB (brotli 1.6 MB, mostly QOA audio)
- Profile `tools/web.gdbuild`: editor "Detect from Project" output minus `Script`, `ScrollBar` (kept to be safe) + fallback text server, advanced off, no brotli/graphite; `AudioStream`, `AudioStreamPlayer` removed from `disabled_classes` by hand for audio (a disabled class disables its subclasses, `is_class_enabled` follows `super_type`)
- Flags: `threads=no production=yes lto=full optimize=size_extra deprecated=no disable_advanced_gui=yes modules_enabled_by_default=no` + gdscript, freetype, text_server_fb
- Textures: `lossless_compression/force_png` (default stores WebP, which would need the webp module); an editor opened before the setting keeps importing WebP until restarted → textures fail to load on web (scripts preloading them fail to compile). `export_web.sh` fails on WebP in the pack; fix: delete the WebP `.ctex` + `.md5` in `.godot/imported`, reimport
- No svg module: default theme icons blank (game theme covers all used)
- `javascript_eval` on (default): `JavaScriptBridge` for Poki
- Disabled classes are still created lazily from C++ (`initialize_class`); only script/name access and unreferenced code go
- Game starts using a new engine class/format → re-detect profile, rebuild templates, smoke

## Web gotchas
- Secure context required (HTTPS or localhost)
- `user://` → IndexedDB synced on the next frame; hidden tabs get no frames → save-on-hide unreliable
