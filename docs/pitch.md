# Scrap Titans — Pitch (working title)

Idle/clicker for Poki.com. Scrap in, combat mechs out. Pixel art, **everything in side view**, portrait mobile first. Target run: **30–60 min** from first tap to the nuke.

## Core loop

1. Tap the **scrap pile** → scrap.
2. **Line 1 is unlocked from the start.** Build its stations with scrap. Each station has a **work bar** filled by player taps or its workers. When the bar is full and a mech is waiting, the station consumes scrap, plays a short assembly animation and the mech moves along the belt to the next station.
3. After the last station the mech **walks off the line** onto the **battlefield**. The player **receives a deploy fee** in credits.
4. On the battlefield it fires at the current **enemy wave** and takes fire. It earns **credits per second** (rising in steps while it lives), and its damage drains the wave's healthbar. A drained wave pays a big **credit bounty**.
5. The mech explodes. Lifetime depends on its parts. **Salvage** returns a share of its scrap cost. Mechs pay no scrap while alive.
6. Spend credits on workers, lines and unlocks; spend scrap on building, upgrading and operating stations.
7. Unlock and build the **Atomic Missile**. The nuke ends the run.

## Resources (only two)

| Resource | Source | Spent on |
|---|---|---|
| **Scrap** | Pile taps, yard workers, salvage | Building stations, station tier upgrades, per-mech production cost |
| **Credits** | Deploy fee, battlefield payout, wave bounties | Workers, unlocking lines, unlocking upgrades in the menu |

## Assembly line

- Stations in belt order: **Frame** (legs + torso) → **Core** (head) → **Arms** (weapons). Later types: **Plating**, **Reactor**, **Thrusters**, **Shields**. N station types, data-driven.
- A line produces mechs once Frame + Core + Arms are built.
- Each station owns one stat:
  - **Frame** → lifetime.
  - **Core** → credit payout.
  - **Arms** → damage per second against the enemy wave, so bounty rate.
  - **Plating** → lifetime.
- **Work bar:** the only throughput gate. Fills from player taps (tap the station) and from the station's workers. It fills **even when no mech is present**, so work is banked. When full and a mech is waiting: deduct scrap, play the assembly animation (~0.5 s), attach the part, send the mech down the belt. Frame spawns the mech. The bar grows with the station's tier.
- A station holds one mech. If the next station is busy, the mech waits on the belt and blocks upstream.
- **Stalls must be visible:** bar full but no scrap (station flashes the scrap icon and waits), or downstream blocked.
- Stations are **connected by a conveyor belt**. The mech gains parts as it moves and walks off the right edge at the end.
- Throughput = slowest station.
- **Pause button per line** so the player can stop burning scrap while saving for a tier upgrade.
- More lines are **unlocked with credits**. Line N unlock cost follows the cost curve below.

## Workers

- No pool. **"+ WORKER" on a station hires directly** for credits, up to the station's slot cap.
- A worker adds a **chunk of work every few seconds** (not continuous), so the bar visibly jumps. Yard workers add a chunk of scrap the same way.
- Cost formula: `cost = base * growth^n` where `n` = workers hired **on that station**, base and growth per station type (e.g. base 50, growth 1.35). Tune so the first worker per station arrives within the first few minutes.
- Slot caps are raised through the upgrade menu.

## Battlefield (nearly no UI)

- Mechs walk in from the left and fire at the enemy wave on the right. Enemies fire back.
- No HP bars on mechs. Mech damage shows as smoke (3 intensities), then sparks, then explosion and debris. It follows remaining lifetime, not enemy fire.
- No combat sim beyond the wave: lifetime, payout and damage come from the stats; visuals play along.
- **Tapping the battlefield** (anywhere) hits the wave: a small share of its HP and the same share of its bounty as credits. The nearest enemy flashes.
- Later waves hit harder: mechs age faster the higher the wave, so they die sooner.

## Enemy waves

- One **wave** at a time: a set of enemies standing on the right (one type early, mixed later).
- The wave has one **healthbar**, full layout width, at the top of the battlefield. It shows HP left / total and the current **damage per second** (sum of the Arms DPS of all mechs on the field).
- The bar drains slowly while mechs are alive and stops when the field is empty.
- **Drained:** big **credit bounty** (disc burst), explosion animation and particle effects, then the next wave walks in from the right.
- Each wave has more HP and a bigger bounty than the last. Wave types cycle; later waves mix types and bring colored, tougher variants.
- Enemies smoke and spark as the wave's HP drops.
- Three enemy types to start (placeholder names): **Scrap Drones** (small, flying, many), **Crawler Tanks** (medium), **Junk Brute** (one big walker). Data-driven, more types later.
- Individual enemies pop as the bar passes their share of the wave's HP, so the set thins out as it drains.

## Income discs

- No floating numbers. Every gain launches small **discs**: gold for credits, grey for scrap. Three color tiers per resource mark bigger payouts.
- A disc bursts up from its source (mech, pile, wave), then flies into the matching HUD counter, which pulses on arrival. Bursting up first keeps it clear of the thumb on the pile.
- Counts: pile tap 1 scrap; mech deployed 3 credits; each second alive 1 credit; salvage 2 scrap; wave bounty a big burst.
- Cap on discs in flight. Big numbers in the HUD use short suffixes (1.2K, 3.4M).

## Economy defaults (tune later)

- **Payout while alive:** `rate = base_rate(Core) * step^min(floor(t / interval), cap)` with `step = 1.5`, `interval = 5 s`. `cap` starts at 0 (flat payout); the Payout upgrade chain raises `cap` and lowers `interval`. Bounded, so lifetime is strong but not the whole game.
- **Deploy fee:** paid to the player on arrival, scales with Core tier.
- **Wave HP and bounty:** `hp = base_hp * hp_growth^wave`, `bounty = base_bounty * bounty_growth^wave`. DPS = sum of Arms DPS on the field.
- **Salvage:** starts at 0% of the mech's scrap cost. Upgrades raise it, hard cap 40%.
- **Cost curve for credit purchases:** `cost = base * 1.4^level`; lines ×8 per line.
- **Tier upgrades cost a fixed scrap amount** per tier (rising per tier, not per line). Cheap enough to feel good, expensive enough that pausing a line matters.
- Run length target: 30–60 min active play. No offline progress.

## Upgrade menu (credits)

A fixed **UPGRADES** button opens a purchase menu: **one list, sorted by price**, cheapest first. Everything here costs credits. Rows the player can't afford are greyed.

- **Tiers:** unlock the next tier of each station type (global). The **Atomic Missile** is the last unlock and is visible, locked, from the start.
- **Crew:** more worker slots on every station.
- **Workers:** shorter chunk interval, lighter work bars (all stations).
- **Tap damage:** battlefield taps hit harder.
- **Yard:** scrap per tap, yard slots, yard haul (scrap per worker trip).
- **Payout:** step cap, step interval, deploy fee.
- **Salvage:** 0% → 40%.
- **Scrap per kill (late game):** each enemy destroyed pays scrap.
- **Lines:** unlock line 2, 3, …

Every row has an info button with a plain description. Tapping the station body only fills the work bar.

## Station tiers (scrap, per station, per line)

- A tier is **unlocked once with credits** in the menu, then **applied per station on each line for a fixed scrap price** by tapping the station's tier button. Simple, satisfying click.
- A tier name **is the name of the part it produces**. A new game starts with a Frame that produces **Scrap Frames**.
- Upgrading swaps the part sprite for every mech built afterwards and raises the station's per-mech scrap cost.

| Tier | Frame | Core | Arms | Plating |
|---|---|---|---|---|
| 1 | Scrap Frame | Junk Brain | Pipe Gun | Tin Sheets |
| 2 | Bolted Frame | Relay Box | Bolt Cannon | Boiler Plate |
| 3 | Steel Walker | Tube Core | Auto Cannon | Steel Plating |
| 4 | Composite Strider | Silicon Mind | Rocket Pod | Ceramic Armor |
| 5 | Titan Chassis | Quantum Core | Railgun | Reactive Armor |
| 6 | Atomic Colossus | Doom Core | **Atomic Missile** | Lead-Lined Hull |

## Endgame: the nuke

- The **Atomic Missile** is the final unlock in the menu. Unlocking it (credits) shows a confirmation: "This ends everything. Unlock?"
- Applying it to an Arms station (scrap) turns that line's next mech into the **Nuclear Mech**.
- **Sequence:**
  1. The Nuclear Mech walks onto the battlefield and fires. The missile arcs off-screen.
  2. White flash, mushroom cloud expanding from the battlefield.
  3. A shockwave sweeps down the scroll pane, auto-scrolling with it. Lines, belts, stations and workers collapse into debris.
  4. Only the **scrap pile** remains. "Start again" prompt.
- Start again = fresh save. No prestige or carry-over for now; keep the save format open for it.
- Optional run-stats card: time, mechs built, credits earned.

## Screen layout (portrait)

```
┌──────────────────────────────┐
│ HUD: scrap +/s  credits +/s ⚙│  fixed
├──────────────────────────────┤
│ BATTLEFIELD (fixed, ~25%)    │  fixed, tap = hit the wave
│ ▓▓▓▓▓▓▓▓░░░ 1.2K/3K  45 DPS  │  wave healthbar, full width
│  mechs →  smoke  ✸   ← enemy │  discs fly to the HUD
├──────────────────────────────┤
│ ▼ ScrollContainer (vertical) │
│   FRAME  CORE   ARMS  PLATING│  station names
│1 [▓▓▓▓]=[▓▓░░]=[░░░]=[+ ]→   │  pause strip, work bar = machine top,
│⏸ [ww  ]  [w  ]  [ww ]        │  workers inside, belt, mech exits →
│  [+w][⬆] [+w]   [+w]         │  hire + apply tier share one row
│ [ + UNLOCK LINE 2 · credits ]│
├──────────────────────────────┤
│ w⛏ [SCRAP PILE] ⛏w  [+YARD W]│  fixed, always visible
│                     [UPGRADES]│  thumb zone → menu
└──────────────────────────────┘
```

- Lines share **one scroll pane**. The scrapyard is fixed in the bottom bar beside UPGRADES; it starts centered and slides left when the other buttons unlock.
- A new game shows line 1 with three empty station pads to build, plus the scrapyard.
- Desktop layout is out of scope for v1 (letterbox the portrait column).

## Tech (Godot 4)

- **Rendering:** Compatibility renderer, for web export.
- **Pixel art:** base viewport 360×640 (or 720×1280 at 2×), `stretch mode = canvas_items`, keep aspect, texture filter **Nearest**.
- **Data:** station types, tiers, upgrades and mech parts as `Resource` files. New station types are data only.
- **Scene structure:** `Main` (HUD, `Battlefield`, `ScrollContainer` → `VBox` → `AssemblyLine` × N + `Scrapyard`, fixed `UpgradeButton`, `UpgradeMenu` overlay). `AssemblyLine` owns `Segment` nodes, the belt and mechs in transit. `Battlefield` owns active mechs, the enemy wave and its healthbar, and effects. A top-level `Flyers` layer draws income discs.
- **Simulation:** one tick in a central autoload (`GameState`), separate from visuals. Workers fire on timers, not per frame.
- **Save:** JSON in `user://` (IndexedDB on web). Save on change and on hide. No offline progress.
- **Poki:** Poki SDK via `JavaScriptBridge`. Gameplay start/stop, commercial break on run end, rewarded ads: 2× payout for 5 min, fill all work bars.
- **Input:** mouse and touch, one-thumb reachable. Touch targets ≥ 44 px at display scale.

## Art list (side view)

- Mech parts per tier (see table): frame, core, arms, plating. Layered sprites so combinations vary for free.
- Nuclear Mech, missile launch, flash, mushroom cloud, shockwave, flattened-factory debris.
- Mech walk cycle (4 frames), firing, muzzle flash, smoke ×3, explosion, debris.
- Enemies: 3 types (Scrap Drone, Crawler Tank, Junk Brute) with a death pop; wave explosion and particles.
- Wave healthbar, credit and scrap discs.
- Station machines: gantry + tool per station type, idle and working states. Empty slot pad.
- Belt tile (animated), scrap pile (fill states), stall icon.
- Worker: idle, shovel, carry.
- Battlefield background layers.