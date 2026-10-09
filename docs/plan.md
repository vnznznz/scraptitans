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
- [x] Web export preset (thread support off, the default), `tools/export_web.py` → `build/web/`
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

- [x] Tune bot: player profiles (baseline, casual 1.5 taps/s, all taps on the battlefield, ⅓ on the battlefield, stops tapping at 10 min, never fits Arms tiers, never pauses) and per-run metrics (income by source, starved share, gaps between buys, share of station work from taps); `tune` checks the targets in the Test list
- [x] Battlefield tap scales with the factory: a tap deals `tap_damage` seconds of field DPS (floor: tier 1 Arms DPS, so it works on an empty field) instead of the pitch's share of wave HP; no per-tap bounty share; the Tap damage row raises the seconds
- [x] Pile tap scales with the yard: `scrap_per_tap` plus a share of yard scrap/s, so tapping the pile helps in scarce phases
- [x] Bounties are a real share of income: a bounty ≈ N s of payout at the expected clear time; `bounty_growth` ≥ `hp_growth`, so higher waves pay more per HP
- [x] Softer wave aging (`wave_damage`), so pushing waves with Arms pays off instead of shortening mech lives for nothing
- [x] Scrap cat and mouse: `scrap_per_mech` and `apply_cost` climb steeply from tier 3; each tier or line unlock makes scrap tight for a while, yard and salvage upgrades loosen it again; in tight phases pausing a line to save for a fit is worth it
- [x] Scrap per kill bounded (fixed scrap per enemy by wave band, not a share of wave HP) or dropped
- [x] Pacing and costs:
  - [x] A burst of buys after each line or tier unlock, then 30–90 s waits; never more than 2 min with nothing affordable
  - [x] Regular upgrade rows spread over the run: more levels, steeper growth; none maxed before ~20 min (now all by 11.4 min)
  - [x] Tier unlock costs on a smooth curve (now ×40 from tier 2 to 3); first tier fit within ~3 min
  - [x] Line unlocks spread out (lines 2 and 3 now arrive 1.5 min apart and income jumps ×16 in 4 min)
  - [x] Atomic Missile priced so the final wait is ≤ ~90 s (now 188 s with nothing to buy)
  - [x] ⬆ fits the highest unlocked tier in one tap, for the sum of the skipped apply costs, so a new line isn't 15 separate fits
- [x] Clarity:
  - [x] Station label is its type (FRAME, CORE, ARMS, PLATING) plus its stat icon (lifetime, credits, damage); the part name moves to the menu's tier row. Also stops long part names spilling into the pause strip
  - [x] Tier rows state the effect: part name as title, `PAY 8 → 16/S`, `LIFE 44 → 57 S`, `DMG 8 → 16` below
  - [x] No MAX anywhere: a full station hides hire and the fit button takes the row, showing its scrap price; nothing to buy → empty row. Same for yard hire. Maxed menu rows collapse into one `MAXED` footer
  - [x] Affordable vs not at a glance: affordable = lit button, price in the currency color; unaffordable = normal button, dim price, title stays readable
  - [x] Plain words: wave bar `WAVE 6` / `5 DMG/S` (the bar alone shows HP); menu rows `5 → 6` with level pips instead of `LV 4/9 5 > 6`; lines row `LINE 4`
  - [x] Pause strip hidden until the first NO_SCRAP stall; scrap use as a small meter instead of stacked digits
  - [x] Spare pane height goes to the battlefield (capped ~2× its height), lines sit at the bottom of the pane near the thumb; the battlefield shrinks back to 160 as lines are added
  - [x] UNLOCK LINE compact (one button row high) until affordable
  - [x] No UPGRADES badge at 0
  - [x] Discs fly behind HUD and wave bar text
  - [x] Intro guide after the reveal: one hint for tapping the battlefield, one for the first affordable upgrade

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

- [x] One palette and pixel scale for everything
- [x] Mechs: parts per tier, walk cycle, firing, Nuclear Mech; the silhouette grows with Frame tier (Atomic Colossus visibly bigger than Scrap Frame), so tiers read by shape, not only color
- [x] Factory: one machine silhouette per station type (e.g. press, dome, gun rack, plate roller) instead of one gantry with a colored tool head; idle and working; empty pad, belt tile, scrap pile fill states, stall icon, workers
- [x] Battlefield: enemies, smoke, sparks, explosion, debris, background layers, bullet variations, tracers
- [x] Battlefield crowd: smoke starts later (< 40% life, now < 75%, so ~¾ of mechs smoke) and lighter, so a hurt mech stands out among 24; drawn mechs spread wider instead of one blob. Built: few mechs smoke now, so the plume is dark and joined by flames below 15%; rows 15 px apart, slots fill spread out
- [x] Enemies escalate at later waves in size and count (boss-size brutes), not only in color
- [x] Nuke: missile, flash, mushroom cloud, shockwave, factory debris, camera shake; the Nuclear Mech is 2× size and the other mechs stop and step aside, so it reads within a second; run card with more character
- [x] A pass over the flying discs animations (late-game scrap discs quieter: fewer, smaller, fading)
- [x] A pass over layout alignment, button sizes
- [x] Unify UI style
- [x] Tighter lines (136 → 120 px): one crew per line (hire under the belt, chunks to the emptiest bar), ⬆ fit in the station header; pile no longer stays flattened or shrinks under heavy activity
- [x] Crew bar on top of each line, L frame with the pause strip, lines stack flush (115 px, no gaps)
- [x] Battlefield: better-equipped mechs take the front row and stay drawn past 24; mechs walk in faster
- [x] Atomic Missile: unlock needs every other part tier; fit needs a fully upgraded line
- [x] Rebalance: Lean build row (less scrap per part), more scrap row levels, scrap-tight mid game where pausing pays, top tiers cheaper; never pausing finishes in time; terse descriptions

Test:
- Every sprite reads at phone size; part tiers are distinguishable at a glance.
- Station types are told apart without their labels.
- In a full field (24 mechs) a hurt mech and the Nuclear Mech are spotted at a glance.

## M11 · Audio

Build: ambience that carries the factory and the battlefield, sounds for every action, the Ending track now and then. Design and assignment in [audio.md](audio.md).

- [x] 64 sounds from the pack + Ending in `audio/` (mono, 32 kHz; beds 22.05 kHz, looped), QOA import
- [x] `data/audio.json`: sounds (files, volume, per-file offsets, pitch jitter, cooldown, voices, group, area), beds, music schedule, areas, settings defaults
- [x] `Sound` autoload: buses, player pool, limits, beds driven by factory activity and drawn mechs, area presence (ready for one scroll pane), music schedule with fades and ducking, settings file, hidden-tab mute, `ad_mute`
- [x] Hooks: pile, yard, stations, assembly per type, deploy, stall, pause, shots per Arms tier, enemy fire per type, pops, deaths, wave clear + bounty, wave arrival, coins, buys, menus, clicks, nuke sequence, run card
- [x] HUD mute toggle, settings volume rows (MUSIC / SOUNDS / AMBIENCE)
- [x] Build profile: audio classes on; templates rebuilt; smoke passes (incl. `audio`)
- [x] `--scenario audio`
- [x] Fix on the way: 45 art textures were imported as WebP (editor open during the M10 reimport) → broke the stripped template; reimported as PNG

Test (browser + iPhone):
- First tap starts the sound; mute toggle works and survives a reload
- 10 min of play: factory and battlefield audible as ambience, nothing grates; taps feel crisp
- A full field (DBG +50 mechs) sounds like a steady battle, not a wall of noise
- Pausing all lines quiets the factory hum
- Ending starts with the first mech, plays twice through (~90 s), fades in and out, returns minutes later; the run card plays it, START AGAIN stops it
- Tab switch: silence while hidden, sound back on return
- Volume rows change their bus; 0 silences it
- iPhone: ring/silent switch off, or Web Audio stays silent

## M12 · One pane

Build: battlefield, lines and scrapyard in one scroll pane; the soundscape follows the view; a consistent frame and button style.

- [x] One scroll pane: battlefield / lines / scrapyard; UPGRADES full width at the bottom (badge inside); menu ends above it
- [x] Pixel-art scroll bar right of the pane (groove, thumb with grip, press/drag, wheel); lines, field and yard 340 wide (4 stations flush, headers kept inside and apart)
- [x] Pins: battlefield (top) and scrapyard (bottom) pin their area in place while in view; lit quick-access button that scrolls there while away; intro guide points at an away pin; the nuke unpins both
- [x] Scrapyard section: crew bar like a line's (`YARD CREW`, hire flush right), pile centered on a ground strip
- [x] Soundscape: areas crossfade with the scroll (field / lines / yard presence), hidden levels −18 / −15 / −15 dB; discs from a scrolled-away source start at the pane edge
- [x] Consistency pass: buttons flush with a frame share its outline row (crew bar hire, fit, build), pins 2 px off the panels, gaps around UNLOCK LINE, pixel `VScrollBar` theme (licenses), menu rows fit (pips under the effect; the buy buttons were clipped), guide arrows stop at a button's top edge
- [x] `--scenario pane`

Test (browser + phone):
- Scroll the pane by drag and by the scroll bar thumb; the thumb follows
- Scroll to the lines: the yard pin lights up; tap it → pane scrolls to the pile; the field pin lights up; tap it → back to the battlefield
- Pin the battlefield and the pile: both stay while the lines scroll between them; unpin → they scroll again
- Scroll away from the battlefield: wind and shots fade; at the pile the factory hum fades too
- 3+ lines with 4 stations: headers readable, nothing clipped at the scroll bar
- Nuke with areas pinned: the sequence still sweeps from the battlefield down to the pile

## M13 · Staged start

Build: a new run starts with the scrap pile alone; every part appears when it can first be used and eases in; the battlefield stays attached to the HUD.

- [x] Battlefield fixed at 160 right under the HUD (no stretched sky); spare height becomes a gap between battlefield and factory, factory + yard stay at the bottom
- [x] Pile alone, centered; HUD scrap only
- [x] At the first station's price: line 1 fades in with all three pads, the yard slides down to the bottom
- [x] First mech: battlefield slides down from under the HUD, scroll bar slides in, HUD mechs + credits fade in
- [x] On first affordability: yard crew bar, line crew bars, UPGRADES bar (rises from the bottom), UNLOCK LINE; pause strip slides in at the first stall; nothing snaps
- [x] `GameState.seen` saved; old saves with a mech built show everything; START AGAIN returns to the pile alone
- [x] `--scenario progression`

Test (browser + phone):
- New game: only the pile, centered; tap it 10× → the line fades in while the pile slides down, smoothly
- First mech: the battlefield slides in from under the HUD as the mech walks onto it; HUD fills in
- 40 / 50 / 60 / 500 credits: yard crew, line crew, UPGRADES, UNLOCK LINE appear one by one and stay after spending
- Reload mid-run: everything already seen is there at once, no animation
- START AGAIN after the nuke: back to the pile alone

## M15 · Battlefield progression

Build: the battlefield shows what each line contributes and keeps changing until the nuke; an EFFECTS setting keeps it light on phones. Done before M20.

- [x] Mechs remember their line; a gate per line on the left edge: door opens on a deploy, drawn mechs walk out of it, lamp shows producing / paused / out of scrap / incomplete
- [x] DPS strip under the wave bar: damage share per line in the gate colours, taps white
- [x] Factory lines tagged with their number in the same colour on the crew bar, from 2 lines on
- [x] Front line advances on every cleared wave (further late in the run) through outskirts → burning city → industry → enemy fortress; sky dusk → night → red
- [x] Crowd of silhouettes for undrawn mechs (up to 150) behind the front rows, one node for all; a freed front slot takes the first crowd mech
- [x] Artillery strikes stand in for undrawn mechs; a boss on every 5th wave
- [x] EFFECTS setting LOW / MED / HIGH (drawn rows, crowd, damage smoke, debris, artillery), MED by default on phones, steps down by itself below 40 fps
- [x] Mech views re-synced only when the field changes, in one pass (6.3 → 0.6 ms per frame at 170 mechs)
- [x] `--scenario field`, `--scenario field_perf`

Later: sounds for artillery and crowd deaths; the boss as a real, tougher enemy in the sim (now drawn only).

Test (browser + phone):
- Unlock line 2: a second door appears with a puff; both crew bars get a number tag (1 cyan, 2 pink); line 2's mechs walk out of door 2; the strip under the wave bar gets a pink part
- Pause a line: its lamp turns grey; starve it: the lamp blinks red
- Clear waves: the ground scrolls while the army marches in place; city, industry and fortress pass over the run; the sky turns to night, then red
- Late game: a dense crowd behind the front rows, artillery explosions on the enemies, a boss on WAVE 5, 10, 15 (BOSS on the wave bar)
- Settings → EFFECTS -: fewer rows drawn, a thinner crowd and none on LOW, no artillery on LOW; a reload keeps the level
- Phone, late game (100+ mechs): smooth; if not, EFFECTS steps down by itself within ~15 s

## M16 · Words

Build: every name and description is easy to read and uses the same words for the same things. Done before M20.

- [x] One word per thing in all player text (Words table in the pitch): pile (not yard), station (not pad), line crew, field, fee
- [x] Upgrade rows: names say what gets better (Scrap magnet, Crew per station, Bigger shovels, Harder hits, …); every effect line labelled (`WORKERS 2 » 3`, `EVERY 2S » 1.9S`, `UP TO X1 » X1.5`); plain info text
- [x] Station descriptions say what the part is; tier rows say how to fit (or, for Plating, how to build); Plating rows `LIFE +a » +b S`
- [x] Parts: Autocannon, Lead Armor
- [x] Fix: the pile tap row had no effect (tap read the base share); retuned: base share 15 → 10 %, +1 %/level (was +4 %), baseline 38.7 min, all tune checks pass
- [x] `--scenario ui`: rows fit one level before their cap

Test:
- Open the menu early, mid and late in a run: each row's name and effect line make sense without the info button; the info text agrees
- Buy Scrap magnet with a pile crew: pile taps give visibly more scrap

## M17 · Graphics consistency

Build: one look for every price, frame edge and overlay; stations and the pile show what was bought for them. Done before M20.

- [x] Prices: every purchase button reads what · currency icon · price (coin on hire, nut on fit, UNLOCK LINE's coin at its price); white price on the lit face; one hire glyph
- [x] Crew bars: line tag 16×20 and centered, tag digit / crew text / hire price on the same rows; hire and fit share the rail's and the pause strip's edge; L frame corner closed
- [x] Stations: pad as wide as the build button; stat icons at one distance from the name; headers end before the rail; crews never cross behind the mech
- [x] Intro guide: label on a plate, centered on its arrow; `BUY IT` beside the arrow, clear of row text and prices
- [x] Upgrade menu: nearly opaque; scroll thumb in the right margin; 4 px pips, unlit ones readable
- [x] Rail pins: away pins light, not green (green = affordable)
- [x] Pile floor like the factory backdrop; wave bar inset 6 like the panels; white badge count; build version
- [x] Station tiers: machine tool in the part's tier colour, tier lamps, more hardware at tiers 3 and 5; flash + puff on a fit
- [x] Station upgrade rows: free crew slots as floor marks, flywheel (Lighter work), worker tools (Faster crews)
- [x] Pile upgrade rows: bigger shovel, then wheelbarrow (Bigger shovels); magnet crane over the pile (Scrap magnet)
- [x] Fix: the pile changed size after a few taps on a new game (without a crew the stock was measured against 1 scrap/s) and every 10–30 s later; its size now follows the stock smoothed over 8 s and only shrinks under half a size's threshold
- [x] Pile redrawn: a heap of junk (plates, girders, pipes, gears, tires, barrels, mech heads) lit from the top left over darker pieces behind, with an outline against the page; 5 sizes that differ only by their outer pieces, so it grows and shrinks in small steps
- [x] Field: one big gate for all lines instead of a door per line (no line plates, numbers or lamps); its shutter rolls up on a deploy; mech slots closer together, none on the gate
- [x] Field: with all slots taken, new mechs still walk out of the gate: a mech that fades after a few steps and a small shadow that walks into the crowd; one every 0.25 s at most, so a steady flow late in the run

Test (browser + phone):
- Every button that costs something shows a coin or a nut left of its price; affordable prices are white on green and easy to read
- Line tags sit centered in their crew bar; no doubled outlines where hire meets the scroll bar or fit meets the pause strip
- New game: no guide text on top of other text; `BUY IT` sits beside its arrow
- Open the menu: the factory no longer shows through; a thumb on the right shows the list position
- Scroll away from the field or the pile: its pin turns light, not green
- Fit a tier: the station flashes and its tool takes the new part's colour; one more tier lamp is lit
- Buy Crew per station: one more floor mark per station; Lighter work: a flywheel appears and spins while assembling; Faster crews: workers hold a better tool
- Buy Bigger shovels and Scrap magnet: pile workers get bigger shovels, later wheelbarrows; a magnet hangs over the pile and grows
- Field: one big gate on the left edge; on a deploy its shutter rolls up, the mech walks out, the shutter closes; with 2+ lines still one gate; full field: no mech stands on the gate
- Late game (field full, several lines): mechs and small shadows keep coming out of the gate, evenly spaced, the shadows join the crowd; none on EFFECTS LOW

## M18 · CrazyGames basic launch

Build: the game meets CrazyGames' Basic Launch requirements ([crazygames.md](../release/crazygames.md)): readable in their desktop frames, covers, shell and branding fixes. SDK and ads stay in M20. Done before M20.

- [x] Desktop: never scaled below 1×. In a frame shorter than 640 px the column gets shorter instead (base height = frame height, 462–640, still pillarboxed); from 640 up as now
- [x] Short column (462): CREDITS fits (its text scrolls; title and BACK were cut off); settings, audio, menu and run card stay inside
- [x] Covers 1920×1080, 800×1200, 800×800: the game's sprites at whole-number scale plus the title, by script → `release/marketing/covers/`; `release/.gdignore` keeps them out of the pack
- [x] Boot splash: title on the page colour instead of the Godot logo; game icon instead of the Godot icon
- [x] Web shell: `user-select: none` on `body` via `html/head_include`
- [x] Safe areas: HUD and UPGRADES bar move inside `env(safe-area-inset-*)`, read through `JavaScriptBridge`
- [x] `--scenario desktop` (windowed `--shots`): at every CrazyGames frame size scale ≥ 1 and UPGRADES on the bottom edge; at 462 every overlay inside the viewport; insets move the HUD and the bar
- [x] Preview videos 1920×1080 and 1080×1620 from recorded play, screenshots and cover layers → `release/marketing/`, deployed next to the game (`tools/make_videos.py`, `tools/deploy_web.py`); cover titles out of the top left label area
- [x] Docs: `tech.md` (display, shell, splash), pitch (desktop line), `CLAUDE.md` (CrazyGames, release doc), M14 (now M20) becomes the CrazyGames SDK milestone; tick `release/crazygames.md`

Test (browser + phone):
- Desktop browser resized to about 907×510 and 821×462: all text sharp and readable, column centered; the pile is reachable by scrolling or its pin; CREDITS and AUDIO fit
- Tall window or fullscreen: looks as before
- Loading: title splash, no Godot logo; the tab icon is the game's
- Phone: a long press selects nothing and shows no magnifier; layout as before
- Covers: title legible at thumbnail size (about 200 px wide)
- After upload (release build, orientation portrait): Chrome, Edge, Safari; on an iPhone the text is sharp (if soft: `image-rendering: pixelated` on the canvas); in the CrazyGames app on a notched phone the HUD and UPGRADES are clear of the notch and home bar
- A 4 GB Chromebook, if one is at hand: runs smoothly

## M19 · Wars won

Build: prestige. Every nuke counts as a war won; the next war is bigger and the pile grows faster than the costs. Only the pile changes its look.

- [x] Wars won: +1 on START AGAIN after the nuke, saved with the run but not reset by a new game; RESET RUN keeps the count and adds nothing; old saves start at 0
- [x] Per war won ×2 (`prestige_scale`): scrap and credit costs, fees, payouts, bounties, mech damage, enemy HP, scrap per kill; ×2.2 (`prestige_pile`): pile taps and pile crew. First war unchanged
- [x] Menu rows, disc counts and disc tiers follow the scale; rates and scaled rows stay short (`+12K/S`, `LOAD 15K » 21K`)
- [x] Tune profiles `wars1` / `wars5` / `wars10`: each run shorter and less often short on scrap than the one before, none under 25 min, damage up with the scale
- [x] HUD: nuclear disc + wars won from the first one, between credits and the mute button; columns and buttons make room
- [x] Run card: `WARS WON n » n+1`, what the next war brings; START AGAIN sends a nuclear disc from the button to the HUD counter, then the next war starts
- [x] DBG: +1 war won, 0 wars won
- [x] Pile: size and style by wars won, 11 looks (0–10); its size no longer follows the scrap stock
- [x] `--scenario prestige` (windowed `--shots`): scaling, save, HUD, run card, disc, menu rows at 10 wars won, pile looks
- [x] Settings: RESET opens a submenu with RESET RUN (wars won kept) and RESET SAVE (everything, wars won too); each asks in a popup before it does anything
- [x] Settings: the effects row reads VISUAL EFFECTS
- [x] Fix: a line's top light line stopped at the pause strip while the crew bar was shown
- [x] Fix: after a war won the pause strip could stay hidden for a whole run (it waited for the first out-of-scrap stall, which the bigger pile prevents); now it is there from the start once a war is won
- [x] Pause strip: scrap gauge in a recessed well, pause as a raised key under it that stays sunken and shows play while paused; the meter no longer runs into the pause glyph; well, key, crew bar and line edges on one pixel grid with shared ink lines

Test (browser + phone):
- Finish a run, START AGAIN: a nuclear disc flies from the button to the top bar, a count of 1 appears next to the credits, the new game starts with only the pile and that count
- The second run: prices, pay and enemy HP doubled, a pile tap gives 2.2 scrap; the run feels a little easier on scrap, not shorter by half
- The pile looks bigger and less rusty after each war won; nothing else looks different
- Top bar with large numbers (DBG ×100, a few wars won): rates, the count and the mute button never touch
- Settings → RESET → RESET RUN → YES: the war restarts, the count stays; RESET SAVE → YES: the count is gone too; CANCEL on either popup changes nothing

## M20 · CrazyGames SDK

Build: what CrazyGames asks for Full Launch ([crazygames.md](../release/crazygames.md)): their SDK for ads, save and mute, in a build of its own. The game plays the same when the SDK or the ads are missing. Was M14. The m19 build (no SDK) is in Basic Launch review, so its players' saves have to survive this update.

- [x] Rename Plating → Plate everywhere: station name, ids (`plate`, `tier_plate`), art and sound file names, generator, scenarios, docs, the pitch's words; part Steel Plating → Steel Plates; the header fits beside a fit button (was `10.0KLATING`)
- [x] Save import: `Save.VERSION` 2; a version 1 save loads with `plating` → `plate` in station types, mech parts and upgrade levels
- [x] Build variants: export preset "CrazyGames" (feature tag `crazygames`, SDK script in its `html/head_include`) beside "Web" (own site: no SDK, no ad UI); ads only in preset "CrazyGamesAds" (adds feature tag `ads`), since the Basic Launch upload rejects builds with ads; `tools/export_web.py <mode> <preset>`; CrazyGames build without the `DISTCO.DE` credits line (their terms 10.2b: no promotion of own sites)
- [x] `CrazyGames` autoload over `window.CrazyGames.SDK` (HTML5 SDK v3) via `JavaScriptBridge`; their Godot addon is gone from the asset library; `init` awaited at boot with a timeout; backends: SDK (environment `crazygames` or `local`), none (no tag, script blocked, environment `disabled`, init failed), fake (scenarios: scripted ad results, mute setting, data store)
- [x] Errors: every SDK call ends in a result, never an exception; code + message logged; nothing leaves the game paused, muted or input-blocked (ad request without `adStarted` / `adError` in 10 s counts as failed)
- [x] Availability, read at boot and kept current: video ads (off in Basic Launch `adsDisabledBasicLaunch`, with an ad blocker), banners (also off in their mobile app), data module (off without the Progress Save toggle). Ad UI hidden while off (a reward button without effect is forbidden); ad blocker: reward buttons disabled, `BLOCKED BY AD BLOCKER`
- [x] Game events: `loadingStart` in the shell, `loadingStop` at the first frame; `gameplayStart` on the first tap and when the last overlay closes; `gameplayStop` while the UPGRADES menu, settings, run card or an ad is open, not on focus loss; `happytime` at the nuke
- [x] Ad break: input blocked from the request (dim + spinner); sim frozen and `Sound.ad_mute` from `adStarted` to `adFinished` / `adError`
- [x] Midgame ad on START AGAIN, before the next war starts (the only break in a run; never on a navigation button); any error → carry on at once
- [x] Reward: SCRAP ×2 for 5 min of game time (pile taps, pile crew, salvage, enemy scrap): a fixed row at the top of the UPGRADES menu with a video-icon button; HUD timer at the scrap rate; saved
- [x] Reward: free upgrade. The three cheapest rows the player can't afford get a video-icon button beside the price (the price stays readable, the icon is not on the green face), at most three icons in the menu; the ad buys the next level of that row, one level per ad; never on locked rows or the Atomic Missile
- [x] Rewards: after a reward a cooldown in game time for both (3 min to start, set by tuning): no video icons on the rows until it is over, the scrap row shows the time left (boost, then cooldown); reward only on `adFinished` with a disc burst; nothing on `adError`, no cooldown either; never two ads for one reward
- [x] Banner in the UPGRADES menu only (their rules: none during play, none over game content): a slot at the top of the menu, the screen area of the covered battlefield; DOM container over the canvas from the slot's rect in CSS px, responsive request (320×50 fits the 360 column at 1×); slot set when the menu opens (banners on and ≥ 30 s since the last request), request once the menu has been open 1 s, cleared on close and before a video ad; the layout never moves while the menu is open (failed request = empty slot); 8 px clear of CLOSE and buy buttons; CLOSE is never held back
- [x] Mute: `game.settings.muteAudio` and its change listener mute like the HUD button and win over it (button shown muted, disabled while the site mutes)
- [x] Save: Data module (key `save`, ≈ 15 KB of 1 MB) when on, `user://` otherwise and on data errors; empty module on first run → take over the `user://` save (Basic Launch players); sign-in / sign-out → reload the run from the module; RESET SAVE clears both; settings (audio, effects) stay per device in `user://settings.json`
- [x] Guide, easier to see: label at full opacity all the time (the pulse took it down to 50 %), the pulse moves to the arrow; plate with a yellow frame; the target itself lit while the guide points at it (the hover highlight of the pile, station or button)
- [x] Guide, clear of the thumb: label and arrow above the target (the hand comes up from the bottom edge and covers what is below the finger): `BUILD THE … STATION` and `TAP STATIONS TO BUILD A MECH` move from below to above, off the station names; thumb zone = from the last touch down to the bottom edge, wider toward the nearer side edge: a label that would land in it goes to the far side of its target; mouse: above, no zone; `BUY IT` stays left of its button
- [x] `--scenario intro`: every guide line at full opacity, on screen, off its target and off station names; after a tap on each target the next label is outside the thumb zone
- [x] Balance: tune profile `ads` (bot takes the scrap boost and the dearest of the three offered upgrades whenever the cooldown is over): no run under 25 min, also at `wars5`; sets the cooldown
- [x] `--scenario sdk` with the fake backend: ad break pauses, mutes and resumes on finish, error and timeout; rewards only on finish, one level per ad; video icons on the three cheapest unaffordable rows only, none on locked rows or the missile, none during the cooldown, hidden / disabled by availability; midgame only on START AGAIN; gameplay events in order; banner slot rect, request delay, clear on close; site mute; save round trip, version 1 import, take-over, sign-in reload, reset; "Web" build path = no ad UI
- [x] `tools/make_videos.py` again (Plate header, new guide in the first clips) → new videos and screenshots for the Full Launch upload
- [x] Build `0.2.0-m20`; docs: `tech.md`, pitch (ads, words), `crazygames.md` (Full Launch list, Progress Save toggle, QA steps)

Test (browser):
- `tools/serve_web.py` with `WEB_ROOT=build/crazygames_ads` at `https://localhost:8443` (SDK `local` environment, demo ads; the LAN address is `disabled` = no ad UI): the scrap boost and a free upgrade level arrive after the demo ad and not when it fails; at most three video icons, on the cheapest rows you can't afford, gone for the cooldown after an ad; sound and factory stop during an ad and come back; START AGAIN shows an ad, then the next war
- Ad blocker on: the game loads and plays; reward buttons disabled with the notice; START AGAIN goes straight on
- CrazyGames QA tool: gameplay / loading events in their log; site mute button mutes; banner only inside the open UPGRADES menu, gone on CLOSE, rows don't jump when it arrives, never under a finger on CLOSE or a buy button; phone and 907×510 desktop frame
- A save from the m19 build: loads, the Plate station and its mechs are there
- New game on a phone, one thumb: every guide line is readable while the thumb rests where it last tapped; nothing to read is under the hand; the lit target is obvious at arm's length
- Progress Save: play, reload → run is back; signed in on a second device → same run; RESET SAVE → gone on both
- Own site build: no SDK request in the network tab, no ad UI, credits with `DISTCO.DE`

## M21 · While you were away

Build: coming back to the game pays for the time away, so tabbing away or closing it isn't lost time ([crazygames.md](../release/crazygames.md), engagement risks).

- [x] Time away: real time without a frame (hidden tab, sleeping device) or between the last save and the next load; from 1 min, capped at 1 h; an ad break doesn't count
- [x] Payout: 25 % of the factory's credits and net scrap per second (average of the last minute) for that time; net scrap ≤ 0 → a quarter of the gross scrap income, at least a pile tap every 2 s; nothing before the first mech or after the nuke; the sim itself stands still as before
- [x] Card `WHILE YOU WERE AWAY`: time, scrap, credits, COLLECT with a disc burst to the HUD; uncollected payouts are saved and add up to the cap
- [x] Ad: video button `X2` beside COLLECT, only in builds with video ads (`ads` tag, no ad blocker); doubles only after a finished ad
- [x] DBG: 10 MIN AWAY / 2 H AWAY
- [x] `--scenario away`; build `0.2.0-m21`; docs: pitch, `tech.md`

Test (browser):
- Play past the first mech, switch to another tab for 2 min, come back: the card shows about 2 min with scrap and credits; COLLECT sends discs to the top bar and both counters jump by the amounts
- Under a minute away: no card
- Close the tab, open the game 5 min later: the card is there; reload without collecting: still there
- All lines running with the scrap rate red or negative, then away: the card still pays scrap
- DBG → 2 H AWAY: `1 H (MAX)`
- `build/crazygames_ads`: `X2` beside COLLECT; after the demo ad both amounts arrive doubled; a failed ad leaves the card as it was; the ad itself never produces a second card
- `build/crazygames` and `build/web`: COLLECT alone

## M22 · First-day numbers

Build: the weak numbers of the first day on CrazyGames ([feedback.md](feedback.md), Numbers) get better: more players past the first minute, longer mobile sessions, more desktop clicks. Their targets ([crazygames.md](../release/crazygames.md), Launch stages): conversion 80 %+ (ours 42 %), playtime 10+ min (mobile 6m36s, desktop 17m12s), day 1 return 10–15 % (no data yet). Basic Launch is judged from 7 days live and 500 plays, about 2026-10-14 → one upload at the end of the milestone (updates are approved automatically).

- [x] First minute, measured: `--scenario tune` prints per profile the time of the first station, first mech, first wave cleared, first buy and the longest stretch of the first 5 min with nothing new; the bot follows the guide before the first mech
- [x] First minute, shortened: stations for 3 / 5 / 7 scrap (were 10 / 15 / 20), first pile hire 25 credits (was 40) → first mech after 17 s at 3 taps/s (was 28 s) and 32 s for a slow tapper (was 53 s), first buy after 36 / 53 s (was 57 / 97 s); checked in `tune` (≤ 20 / 35 s and ≤ 45 / 60 s). 15 s for a slow tapper would need a free first mech: not done, the first mech is what teaches tapping the stations
- [x] First screen: the battlefield and the scroll bar are there from the start, the pile centered under them (M13 showed the pile alone), with the first wave walking toward the gate; the rest still appears stage by stage
- [x] Gate under attack: whenever no mech is on the field the wave walks to the gate (20 s) and attacks it; health bar and `GATE UNDER ATTACK` under the wave bar; the gate falls after 2.5 min of attack in total (first 5 min and a 40 s walk: halved and doubled after playing it); mechs walking out push the wave back (4 s) and the gate repairs 1 s of damage per 2 s while they hold the field; a cleared wave starts from its post; the sim stands still while away, so no damage then
- [x] Gate fallen: the gate blows up, card `THE GATE HAS FALLEN` with time and mechs, TRY AGAIN starts the war again from the pile; wars won and settings stay, no reward; counts as no gameplay for the SDK; DBG: GATE 20 S LEFT
- [x] Gate state saved (old saves: full health); `--scenario gate`; no tune profile loses the gate; the field-only bot gets to 99 of the 150 s, a slow tapper to 12 s, the rest to 0
- [x] Pile taps throw particles (scrap bits from the tapped spot): 2 → 12 bits, faster and wider with the scrap a tap gives on a log scale, scaled to a single war (smallest on the first tap of a war, full with every pile upgrade maxed; the wars won multiplier doesn't count, so every war runs through the whole range); big bits from 60 %, sparks from 85 %; fewer by VISUAL EFFECTS level
- [x] Phone stays awake while the game is in front: `navigator.wakeLock` through `JavaScriptBridge`, asked again when the tab comes back; silent where it is refused (their iframe may not allow it)
- [x] Minutes 4–8, where the average mobile session ends: the longest wait between buys there is 12 s (13 s for a slow tapper), so nothing to tune; figure and check (≤ 30 s) in `tune`
- [x] Landscape cover, shown on desktop (CTR 0.6 % against 2.1 % on mobile): the mechs and the fight fill the picture: every mech tier and the Nuclear Mech against the whole wave, title top centre (picked from two candidates; the title sign stays its size: smaller it can't be read at 200 px); `tools/gen_covers.py`, cover layers and the marketing page with it
- [x] Landscape video: opens on the new cover, then a full field in a mid-game fight instead of the pile; both videos and the screenshots recorded again with the new start (`tools/make_videos.py`)
- [x] Simple performance pass: `--scenario perf` (late run: 5 lines, 170 mechs, per-part cost): 0.9 ms of script and scene time per frame, 0.95 ms with the menu open (was 1.2: the menu rewrote and sorted every row each frame, now only on a change); nothing else redone without a change worth cutting; `field_perf` as before. The warm iPhone is [M23](#m23--phone-heat)
- [x] Build `0.2.0-m22`, saves from m20 and m21 load (save version unchanged; the gate's three keys default to a whole gate); docs: `tech.md`, pitch (start, gate, losing), `crazygames.md`
- [x] Upload `build/crazygames` (the user, 2026-10-09: `0.2.0-m22+128.145e523`; first live build with the M21 away card, which pays for a locked phone and a hidden tab); cover and videos go up in the Art tab after it
- [ ] A row in [feedback.md](feedback.md) a few days after the upload: conversion, playtime and CTR by device, day 1 return

Test (browser):
- New game on a phone: the enemy column walks toward the gate before the first tap; the first mech walks out after about 20 s of steady tapping; no stretch in the first minute where nothing can be done
- New game left alone: the column reaches the gate and attacks it, its health bar drains; a mech sent out stops it and the bar climbs back; left alone to the end, the game over card comes and the war starts again with the wars won kept
- All lines paused late in a war until the field is empty: the column comes back to the gate
- Pile taps: a few bits fly on the first taps, clearly more late in a war; after START AGAIN they are small again and grow at the same pace
- Phone left untouched with the game open for 2 min: the screen stays on (own site build; on CrazyGames if their frame allows it)
- A save from the live build mid-run: loads, everything seen is there
- Developer portal, Art tab: the new landscape cover and video are the ones shown on desktop

## M23 · Phone heat

Build: an iPhone 16e no longer gets warm while playing. After M22; heat can only be judged on the phone, so every step is a build the user tries.

- [ ] Measure on the phone: Safari Web Inspector timeline (CPU, GPU, frame rate) in a late run; canvas size in device pixels
- [ ] Candidates, one at a time: canvas rendered at a whole multiple of the base size instead of the device's full pixel ratio (3× on the 16e: about 1170×2532 for a 360-wide pixel game), scaled up by the browser with nearest-neighbour; lower frame rate; particle and crowd counts on phones
- [ ] Keep what cools the phone without a visible loss; docs: `tech.md`

Test (browser):
- iPhone, 15 min into a run with three lines: the phone stays cool to the touch, the game looks and scrolls as before
- Desktop and Android: pixels as sharp as before

## Not in the prototype

A full tutorial (not in the pitch; only the intro guide label), Reactor/Thrusters/Shields (no stats yet), more lines or tiers for later wars, a sim that runs on while away (the away card pays a share instead), desktop layout.
