# Plan

Prototype milestones for [pitch.md](pitch.md). Each ends with a web build playable from a fresh save in the local browser and iOS Safari.

## Every milestone

- Claude checks the Test list as far as it can by instrumenting Godot directly: headless scenario runs for logic, windowed screenshots for visuals. Claude never runs browser tests.
- The user runs the Test list in the local browser and iOS Safari, with the build served by Caddy over HTTPS (self-signed cert).
- Sprites are PNG files from the start, placeholders included, so M8 replaces files, not code.
- Tunables live in JSON files in `data/` (not Resource files as the pitch says); tune by playing, with the debug panel from M1 on.
- Update [tech.md](tech.md) and tick the boxes below.

## M0 · Setup

Build: layout skeleton; tapping the pile raises scrap, and it survives a reload.

- [x] `git init`, ignore `build/`
- [x] GDScript with static types
- [x] Display: 360×640, stretch `canvas_items`, aspect `keep_width`, texture filter Nearest, pixel font. `keep_width` instead of the pitch's keep: desktop still gets a pillarboxed column, taller phones get a longer scroll pane.
- [x] `Main`: HUD, battlefield (fixed, ~25%), ScrollContainer → VBox (line 1 placeholder, scrapyard), fixed UPGRADES button; starts scrolled to the bottom
- [x] Autoloads: `GameState` (resources, fixed-step tick), `Save` (JSON in `user://`, `version` field)
- [x] Web export preset (thread support off, the default), `tools/export_web.sh` → `build/web/`
- [x] Caddy with a self-signed cert (`tls internal`) serves `build/web/` on localhost and the LAN IP, with `Cache-Control: no-cache`; browsers accept the cert warning
- [x] Instrumentation: `godot --headless -- --scenario <name>` drives the game (taps, fast-forward), prints state and exits non-zero on failure; windowed runs can save viewport screenshots
- [x] Start `docs/tech.md`

Test:
- Local browser: pillarboxed column.
- iPhone: layout fits, dragging scrolls the pane, rapid two-thumb taps on the pile all count.
- Reload keeps scrap.

## M1 · First mech

Build: build line 1, tap mechs through it, watch them earn on the battlefield.

- [x] `data/segments.json`: Frame (lifetime), Core (payout), Arms (kill rate) with build cost, bar size, scrap per mech, tiers (tier 1 only for now)
- [x] `data/economy.json` with the pitch defaults
- [x] Sim: bars bank work with no mech present; full bar + mech + scrap → pay, assemble 0.5 s, move on. One mech per segment; a mech waits while the next segment is busy, blocking upstream. Frame spawns mechs.
- [x] Sim: deploy fee on arrival, stepped credits/s, scrap per kill, 40% salvage on death
- [x] Line view: empty pads → build (scrap), tapping a segment fills its bar, belt moves mechs, stall icons (no scrap, blocked)
- [x] Battlefield stub: mechs slide in, stand, pop at end of life
- [x] Income discs instead of the pitch's floating numbers: credit/scrap discs burst from the source (mech, pile) and fly to the HUD counter, which pulses
- [x] HUD: credits, scrap, +/s, short suffixes (1.2K, 3.4M)
- [x] Save every few seconds and after purchases. On web, `user://` writes reach IndexedDB on the next frame and hidden tabs get no frames, so save-on-hide can't be relied on.
- [x] ⚙ → reset run (with confirm)
- [x] Debug panel (debug builds only): time scale ×1/×10/×100, +scrap, +credits

Test:
- Fresh game: line 1 with 3 empty pads, scrolled to the scrapyard.
- Pile → build Frame, Core, Arms → tap them → first mech on the battlefield within ~1 min, fee paid.
- It earns rising credits and scrap, explodes, pays salvage.
- Out of scrap: stall icon, line waits. Next segment busy: blocked icon.
- Reload mid-production restores the same state.

## M2 · Workers

Build: hire workers; the factory runs hands-off.

- [ ] "+ WORKER" per segment, "+ YARD WORKER": credits, `base·growth^n` per station, fixed slot caps
- [ ] A worker adds a chunk every few seconds, so bars visibly jump; yard workers add scrap chunks
- [ ] Pause per line: no scrap consumed
- [ ] Highlight the slowest segment (bottleneck)

Test:
- First worker affordable within a few minutes.
- Phone untouched for 2 min: mechs keep coming.
- Pause stops the scrap drain.
- Workers on the bottleneck move the highlight.

## M3 · Upgrades and lines

Build: spend credits in the upgrade menu, run several lines.

- [ ] UPGRADES → tabbed overlay; unaffordable rows grey; cost `base·1.15^level`
- [ ] `data/upgrades.json`: rows of tab, stat, delta per level, max level, base cost; the sim reads derived stats
- [ ] Tabs: Segments (bar size, worker slots per type), Workers (chunk size, interval), Yard (scrap per tap, yard slots), Payout (step cap, interval, deploy fee), Salvage (40 → 90%), Lines
- [ ] "+ UNLOCK LINE N" in the pane and in the Lines tab; new lines start with 3 empty pads

Test:
- One purchase per tab, each with a visible effect.
- Line 2 runs beside line 1, both feed the battlefield.
- Salvage stops at 90%.

## M4 · Tiers

Build: unlock better parts, apply them per segment, see mechs change.

- [ ] Tiers in `data/segments.json`: 6 × Frame/Core/Arms/Plating (part name, stat, scrap per mech, apply cost)
- [ ] Tiers tab: unlock the next tier per type (credits, global); Atomic Missile row visible and locked
- [ ] Segment tier button applies the next unlocked tier for scrap; ⬆ jumps to that type's tier row
- [ ] Plating on the `[+]` pad after Arms, unlocked by its tier 1 row (the pitch doesn't say how Plating unlocks)
- [ ] Layered mech sprites by part tier; an applied tier affects parts attached afterwards

Test:
- Unlock Frame tier 2, pause to save scrap, apply → new mechs look different and live longer, scrap per mech rises.
- ⬆ opens the menu on the right row.
- Unlock Plating, build it on line 1 → mechs live longer.

## M5 · Battlefield

Build: the battlefield reads without UI.

- [ ] Mechs walk in (4 frames), hold a slot, fire with muzzle flash; 2–3 enemy types fire back and pop at the mech's kill rate
- [ ] Damage by remaining lifetime: smoke ×3 → sparks → explosion + debris
- [ ] Income discs scale with amount (more or bigger discs for bigger payouts), readable at 50 mechs
- [ ] Draw at most N mechs (the pitch doesn't cap it); the rest are simulated only
- [ ] Debug: spawn 50 mechs

Test:
- 2 min of play shows who fires, who's hurt and what each mech earns.
- 50 mechs: discs stay readable, 60 fps on the iPhone.

## M6 · Nuke

Build: a run can be finished and restarted.

- [ ] Atomic Missile unlock asks "This ends everything. Unlock?"
- [ ] Applied to an Arms segment (scrap), that line's next mech is the Nuclear Mech
- [ ] Sequence: fire, missile arcs off-screen, white flash, mushroom cloud, shockwave sweeps down the pane with auto-scroll, factory collapses to debris, scrap pile remains
- [ ] Run stats card (time, mechs built, credits earned) → Start again = fresh save
- [ ] Input locked during the sequence; the save marks the run as over

Test:
- With debug resources, the nuke is reachable in a few minutes and plays through to the card.
- Reload after launch shows the card, not the old run.
- Start again gives a fresh game.

## M7 · Poki and tuning

Build: Poki integration, tuned run.

- [ ] `html/head_include` loads the Poki SDK; `Poki` autoload wraps it via `JavaScriptBridge`, no-op off web
- [ ] `gameLoadingFinished`; `gameplayStart` on first tap and when menus close, `gameplayStop` while the menu or end card is open
- [ ] `commercialBreak` before Start again; game paused during ads
- [ ] Rewarded: 2× payout for 5 min (HUD timer, saved), fill all work bars
- [ ] Tune: first worker within a few minutes, nuke at 30–60 min

Test:
- SDK calls fire in order (log them); rewards only on success.
- Game still runs with the SDK blocked (ad blocker).
- 3 fresh players reach the nuke in 30–60 min.

## M8 · Art

Build: release candidate. Claude refines the placeholder art.

- [ ] One palette and pixel scale for everything
- [ ] Mechs: parts per tier, walk cycle, firing, Nuclear Mech
- [ ] Factory: segment machines (idle, working), empty pad, belt tile, scrap pile fill states, stall icon, workers
- [ ] Battlefield: enemies, smoke, sparks, explosion, debris, background layers
- [ ] Nuke: missile, flash, mushroom cloud, shockwave, factory debris

Test:
- Every sprite reads at phone size; part tiers are distinguishable at a glance.

## Not in the prototype

Audio and tutorial (neither is in the pitch), Reactor/Thrusters/Shields (no stats yet), prestige, offline progress, desktop layout.
