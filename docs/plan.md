# Plan

Prototype milestones for [pitch.md](pitch.md). Each ends with a web build playable from a fresh save in the local browser and iOS Safari.

## Every milestone

- Claude checks the Test list as far as it can by instrumenting Godot directly: headless scenario runs for logic, windowed screenshots for visuals. Claude never runs browser tests.
- The user runs the Test list in the local browser and iOS Safari, with the build served by Caddy over HTTPS (self-signed cert).
- Sprites are PNG files from the start, placeholders included, so M10 replaces files, not code.
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
- [x] Sim: deploy fee on arrival, stepped credits/s, salvage on death (now 20%; per-kill scrap removed)
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

## M2 · Enemy waves

Build: mechs grind down enemy waves for big credit bounties.

- [x] `data/enemies.json`: 3 types (Scrap Drones, Crawler Tanks, Junk Brute: count per wave, sprite); wave HP and bounty curves
- [x] Arms stat is `dps`; the sim drains the wave by the summed DPS of mechs on the field; wave state saved
- [x] Healthbar across the full width at the top of the battlefield: HP left / total, DPS
- [x] Enemies pop one by one as HP passes their share
- [x] Drained: credit bounty as a big disc burst, explosion and particles, next wave (next type, more HP) walks in from the right
- [x] Debug: kill wave

Test:
- The bar drains while mechs are alive and stops when the field is empty; DPS matches the mech count.
- Enemies thin out as the bar drains.
- A drained wave pays a bounty burst, explodes, and the next type walks in with more HP.
- Reload keeps the wave and its HP.

## M3 · Workers

Build: hire workers; the factory runs hands-off.

- [x] "+ WORKER" per segment, "+ YARD WORKER": credits, `base·growth^n` per station, fixed slot caps
- [x] A worker adds a chunk every few seconds, so bars visibly jump; yard workers add scrap chunks
- [x] Pause per line: no scrap consumed
- [x] Highlight the slowest segment (bottleneck)

Test:
- First worker affordable within a few minutes.
- Phone untouched for 2 min: mechs keep coming.
- Pause stops the scrap drain.
- Workers on the bottleneck move the highlight.

## M4 · Upgrades and lines

Build: spend credits in the upgrade menu, run several lines.

- [x] UPGRADES → tabbed overlay; unaffordable rows grey; cost `base·1.15^level`
- [x] `data/upgrades.json`: rows of tab, stat, delta per level, max level, base cost; the sim reads derived stats
- [x] Tabs: Segments (bar size, worker slots per type), Workers (chunk size, interval), Yard (scrap per tap, yard slots), Payout (step cap, interval, deploy fee), Salvage (40 → 90%), Lines
- [x] "+ UNLOCK LINE N" in the pane and in the Lines tab; new lines start with 3 empty pads

Test:
- One purchase per tab, each with a visible effect.
- Line 2 runs beside line 1, both feed the battlefield.
- Salvage stops at 90%.

## M5 · Tiers

Build: unlock better parts, apply them per segment, see mechs change.

- [x] Feedback from M2–M4 testing:
  - [x] Pause button at the front (left) of the assembly line, not the header's right end
  - [x] Worker hire button disappears when the segment's slots are full (no MAX button)
  - [x] Upgrade menu: one list, no tabs, sorted by current price (cheapest first); maxed rows at the bottom
  - [x] Segments centered in the line by count, no space kept for a 4th column; re-spaced when Plating appears
  - [x] Wave level damages mechs: they age faster, `1 + wave_damage·wave` (`enemies.json`), so higher waves shorten lifetime
  - [x] HUD scrap +/s turns red while any line is starved (a segment stalled on no scrap)
- [x] Tiers in `data/segments.json`: 6 × Frame/Core/Arms/Plating (part name, stat, scrap per mech, apply cost)
- [x] Tier rows in the upgrade list: unlock the next tier per type (credits, global); Atomic Missile row visible and locked
- [x] Segment tier button applies the next unlocked tier for scrap; ⬆ jumps to that type's tier row
- [x] Plating on the `[+]` pad after Arms, unlocked by its tier 1 row (the pitch doesn't say how Plating unlocks)
- [x] Layered mech sprites by part tier; an applied tier affects parts attached afterwards

Test:
- Unlock Frame tier 2, pause to save scrap, apply → new mechs look different and live longer, scrap per mech rises.
- ⬆ opens the menu on the right row.
- Unlock Plating, build it on line 1 → mechs live longer.
- Pause sits at the line's left; a full segment shows no hire button; the upgrade list is cheapest first.
- Line segments are centered; with Plating built, all four fit.
- Mechs die sooner on later waves.
- Empty the scrap with a running line → scrap +/s turns red; refill → normal.

## M6 · Battlefield

Build: the battlefield reads without UI.

- [x] Mechs walk in (4 frames), hold a slot, fire with muzzle flash at the wave; enemies fire back
- [x] Damage by remaining lifetime: smoke ×3 → sparks → explosion + debris
- [x] Income discs scale with amount (more or bigger discs for bigger payouts), readable at 50 mechs
- [x] Draw at most N mechs (the pitch doesn't cap it); the rest are simulated only
- [x] Debug: spawn 50 mechs

Test:
- 2 min of play shows who fires, who's hurt and what each mech earns.
- 50 mechs: discs stay readable, 60 fps on the iPhone.

## M7 · Nuke

Build: a run can be finished and restarted.

- [x] Atomic Missile unlock asks "This ends everything. Unlock?"
- [x] Applied to an Arms segment (scrap), that line's next mech is the Nuclear Mech
- [x] Sequence: fire, missile arcs off-screen, white flash, mushroom cloud, shockwave sweeps down the pane with auto-scroll, factory collapses to debris, scrap pile remains
- [x] Run stats card (time, mechs built, credits earned) → Start again = fresh save
- [x] Input locked during the sequence; the save marks the run as over

Test:
- With debug resources, the nuke is reachable in a few minutes and plays through to the card.
- Reload after launch shows the card, not the old run.
- Start again gives a fresh game.

## M8 · Layout, upgrades and tuning

Build: a cleaner screen, a reworked upgrade set, a tuned run.

- [x] Layout pass: fewer buttons per segment (no ⬆ jump button; hire and apply tier share one row), segments visually shorter
- [x] Remove the bottleneck highlight (orange pulsing box)
- [x] Progressive reveal: UNLOCK LINE, YARD WORKER and UPGRADES hidden until line 1 has deployed its first mech
- [x] HUD: scrap left, credits right
- [x] Scrap +/s is net: scrap spent by the lines counts against it
- [x] Salvage starts at 0%, upgrades raise it to 40% (cap)
- [x] Payout starts flat (no steps); upgrades add steps and shorten the interval
- [x] Work bar size grows with the segment's tier (`bar_size` per tier), so max workers don't fill it instantly
- [x] Upgrade pass: clearer names, drop low-impact rows, more yard slot levels; each row has an info button with a plain description (`desc` in `upgrades.json`)
- [x] Late-game upgrade: scrap per enemy killed (each enemy pop pays scrap)
- [x] Waves: more enemies per wave, mixed types in later waves, colored variants (tinted, tougher) as waves climb
- [x] Battlefield enemies smoke and spark as the wave's HP drops
- [x] Income discs: three color tiers by payout size instead of scaled discs, for credits and scrap
- [x] Tune: first worker within a few minutes, nuke at 30–60 min

Test:
- Fresh game shows only the pile and line 1 pads; the other buttons appear after the first mech deploys.
- A segment has at most one row of buttons; a line takes visibly less height than in M7; no orange bottleneck box.
- Scrap left, credits right; scrap +/s drops (or goes negative) while lines consume scrap.
- First mechs pay no salvage and flat credits/s; buying the upgrades changes both; salvage stops at 40%.
- Applying a tier grows the bar; max workers no longer fill it every chunk.
- Every upgrade row's info button explains it.
- Later waves mix enemy types and show tinted variants; damaged enemies smoke.
- Big payouts fly as a different disc color.
- With the scrap-per-kill upgrade, each popped enemy sends scrap discs.
- 3 fresh players reach the nuke in 30–60 min.

## M9 · Balance and clarity

Build: taps, battlefield and scrap matter for the whole run; steadier pacing; a screen that explains itself. Fixes from the M8 critique (tune bot with player profiles, screenshots at 2× and tall phone).

- [ ] Tune bot: player profiles (baseline, casual 1.5 taps/s, all taps on the battlefield, ⅓ on the battlefield, stops tapping at 10 min, never fits Arms tiers, never pauses) and per-run metrics (income by source, starved share, gaps between buys, share of station work from taps); `tune` checks the targets in the Test list
- [ ] Battlefield tap scales with the factory: a tap deals `tap_damage` seconds of field DPS (floor: tier 1 Arms DPS, so it works on an empty field) instead of the pitch's share of wave HP; no per-tap bounty share; the Tap damage row raises the seconds
- [ ] Pile tap scales with the yard: `scrap_per_tap` plus a share of yard scrap/s, so tapping the pile helps in scarce phases
- [ ] Bounties are a real share of income: a bounty ≈ N s of payout at the expected clear time; `bounty_growth` ≥ `hp_growth`, so higher waves pay more per HP
- [ ] Softer wave aging (`wave_damage`), so pushing waves with Arms pays off instead of shortening mech lives for nothing
- [ ] Scrap cat and mouse: `scrap_per_mech` and `apply_cost` climb steeply from tier 3; each tier or line unlock makes scrap tight for a while, yard and salvage upgrades loosen it again; in tight phases pausing a line to save for a fit is worth it
- [ ] Scrap per kill bounded (fixed scrap per enemy by wave band, not a share of wave HP) or dropped
- [ ] Pacing and costs:
  - [ ] A burst of buys after each line or tier unlock, then 30–90 s waits; never more than 2 min with nothing affordable
  - [ ] Regular upgrade rows spread over the run: more levels, steeper growth; none maxed before ~20 min (now all by 11.4 min)
  - [ ] Tier unlock costs on a smooth curve (now ×40 from tier 2 to 3); first tier fit within ~3 min
  - [ ] Line unlocks spread out (lines 2 and 3 now arrive 1.5 min apart and income jumps ×16 in 4 min)
  - [ ] Atomic Missile priced so the final wait is ≤ ~90 s (now 188 s with nothing to buy)
  - [ ] ⬆ fits the highest unlocked tier in one tap, for the sum of the skipped apply costs, so a new line isn't 15 separate fits
- [ ] Clarity:
  - [ ] Station label is its type (FRAME, CORE, ARMS, PLATING) plus its stat icon (lifetime, credits, damage); the part name moves to the menu's tier row. Also stops long part names spilling into the pause strip
  - [ ] Tier rows state the effect: part name as title, `PAY 8 → 16/S`, `LIFE 44 → 57 S`, `DMG 8 → 16` below
  - [ ] No MAX anywhere: a full station hides hire and the fit button takes the row, showing its scrap price; nothing to buy → empty row. Same for yard hire. Maxed menu rows collapse into one `MAXED` footer
  - [ ] Affordable vs not at a glance: affordable = lit button, price in the currency color; unaffordable = normal button, dim price, title stays readable
  - [ ] Plain words: wave bar `WAVE 6` / `5 DMG/S` (the bar alone shows HP); menu rows `5 → 6` with level pips instead of `LV 4/9 5 > 6`; lines row `LINE 4`
  - [ ] Pause strip hidden until the first NO_SCRAP stall; scrap use as a small meter instead of stacked digits
  - [ ] Spare pane height goes to the battlefield (capped ~2× its height), lines sit at the bottom of the pane near the thumb; the battlefield shrinks back to 160 as lines are added
  - [ ] UNLOCK LINE compact (one button row high) until affordable
  - [ ] No UPGRADES badge at 0
  - [ ] Discs fly behind HUD and wave bar text
  - [ ] Intro guide after the reveal: one hint for tapping the battlefield, one for the first affordable upgrade

Test:
- All tune profiles reach the nuke in 30–60 min; the all-battlefield-taps bot is within ~20% of the baseline, not 5× faster.
- Stopping taps at minute 10 costs ≥ 10% more run time.
- Bounties are 25–40% of credits over a run; the Arms-fitting bot beats the no-Arms bot.
- Scrap is short (a station stalled NO_SCRAP) for 5–15% of the run, spread over ≥ 3 phases; the pausing bot beats the never-pausing bot.
- Every 5 min window has buys; longest stretch with nothing affordable ≤ 2 min; first tier fit ≤ 3 min; final wait ≤ 90 s.
- A new player can tell what each station does from the line alone; every tier row states its effect; the fit button shows its price; no MAX anywhere.
- Fresh game on a tall phone: no big empty band between the line and the bottom bar.
- 3 fresh players reach the nuke in 30–60 min.

## M10 · Art

Build: release candidate. Claude refines the placeholder art.

- [ ] One palette and pixel scale for everything
- [ ] Mechs: parts per tier, walk cycle, firing, Nuclear Mech; the silhouette grows with Frame tier (Atomic Colossus visibly bigger than Scrap Frame), so tiers read by shape, not only color
- [ ] Factory: one machine silhouette per station type (e.g. press, dome, gun rack, plate roller) instead of one gantry with a colored tool head; idle and working; empty pad, belt tile, scrap pile fill states, stall icon, workers
- [ ] Battlefield: enemies, smoke, sparks, explosion, debris, background layers, bullet variations, tracers
- [ ] Battlefield crowd: smoke starts later (< 40% life, now < 75%, so ~¾ of mechs smoke) and lighter, so a hurt mech stands out among 24; drawn mechs spread wider instead of one blob
- [ ] Enemies escalate at later waves in size and count (boss-size brutes), not only in color
- [ ] Nuke: missile, flash, mushroom cloud, shockwave, factory debris, camera shake; the Nuclear Mech is 2× size and the other mechs stop and step aside, so it reads within a second; run card with more character
- a pass over the flying discs animations (late-game scrap discs quieter: fewer, smaller, fading)
- a pass over layout alignment, button sizes
- unify UI style

Test:
- Every sprite reads at phone size; part tiers are distinguishable at a glance.
- Station types are told apart without their labels.
- In a full field (24 mechs) a hurt mech and the Nuclear Mech are spotted at a glance.

## M11 · Poki

Build: Poki integration.

- [ ] `html/head_include` loads the Poki SDK; `Poki` autoload wraps it via `JavaScriptBridge`, no-op off web
- [ ] `gameLoadingFinished`; `gameplayStart` on first tap and when menus close, `gameplayStop` while the menu or end card is open
- [ ] `commercialBreak` before Start again; game paused during ads
- [ ] Rewarded: 2× payout for 5 min (HUD timer, saved), fill all work bars

Test:
- SDK calls fire in order (log them); rewards only on success.
- Game still runs with the SDK blocked (ad blocker).

## Not in the prototype

Audio and a full tutorial (neither is in the pitch; only the intro guide label), Reactor/Thrusters/Shields (no stats yet), prestige, offline progress, desktop layout.
