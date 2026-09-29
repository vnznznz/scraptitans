# Scrap Titans — Pitch (working title)

Idle/clicker for Poki.com. Scrap in, combat mechs out. Pixel art, **everything in side view**, portrait mobile first. Target run: **30–60 min** from first tap to the nuke.

## Core loop

1. Tap the **scrap pile** → scrap.
2. **Line 1 is unlocked from the start.** Build its segments with scrap. Each segment has a **work bar** filled by player taps or its workers. When the bar is full and a mech is waiting, the segment consumes scrap, plays a short assembly animation and the mech moves along the belt to the next segment.
3. After the last segment the mech **walks off the line** onto the **battlefield**. The player **receives a deploy fee** in credits.
4. On the battlefield it fires, kills enemies and takes fire. It earns **credits per second** (rising in steps while it lives) and **scrap per kill**.
5. The mech explodes. Lifetime depends on its parts. **Salvage** returns a share of its scrap cost.
6. Spend credits on workers, lines and unlocks; spend scrap on building, upgrading and operating segments.
7. Unlock and build the **Atomic Missile**. The nuke ends the run.

## Resources (only two)

| Resource | Source | Spent on |
|---|---|---|
| **Scrap** | Pile taps, yard workers, enemy kills, salvage | Building segments, segment tier upgrades, per-mech production cost |
| **Credits** | Deploy fee, battlefield payout | Workers, unlocking lines, unlocking upgrades in the menu |

## Assembly line

- Segments in belt order: **Frame** (legs + torso) → **Core** (head) → **Arms** (weapons). Later types: **Plating**, **Reactor**, **Thrusters**, **Shields**. N segment types, data-driven.
- A line produces mechs once Frame + Core + Arms are built.
- Each segment owns one stat:
  - **Frame** → lifetime.
  - **Core** → credit payout.
  - **Arms** → kill rate, so scrap income.
  - **Plating** → lifetime.
- **Work bar:** the only throughput gate. Fills from player taps (tap the segment) and from the segment's workers. It fills **even when no mech is present**, so work is banked. When full and a mech is waiting: deduct scrap, play the assembly animation (~0.5 s), attach the part, send the mech down the belt. Frame spawns the mech.
- A segment holds one mech. If the next segment is busy, the mech waits on the belt and blocks upstream.
- **Stalls must be visible:** bar full but no scrap (segment flashes the scrap icon and waits), or downstream blocked.
- Segments are **connected by a conveyor belt**. The mech gains parts as it moves and walks off the right edge at the end.
- Throughput = slowest segment. Show the bottleneck.
- **Pause button per line** so the player can stop burning scrap while saving for a tier upgrade.
- More lines are **unlocked with credits**. Line N unlock cost follows the cost curve below.

## Workers

- No pool. **"+ WORKER" on a station hires directly** for credits, up to the station's slot cap.
- A worker adds a **chunk of work every few seconds** (not continuous), so the bar visibly jumps. Yard workers add a chunk of scrap the same way.
- Cost formula: `cost = base * growth^n` where `n` = workers hired **on that station**, base and growth per station type (e.g. base 50, growth 1.35). Tune so the first worker per station arrives within the first few minutes.
- Slot caps are raised through the upgrade menu.

## Battlefield (cosmetic, nearly no UI)

- Mechs walk in from the left and fire at enemies on the right. Enemies fire back.
- No HP bars. Damage shows as smoke (3 intensities), then sparks, then explosion and debris.
- Kills are cosmetic: kill rate is derived from Arms tier and produces `+scrap` floaters and an enemy death pop.
- **Floating numbers** are the only UI: gold `+credits`, grey `+scrap`. They drift up and fade.
- No combat sim. Lifetime, payout and kill rate come from the stats; visuals play along.

## Floating numbers

- **Batch per source per second:** one floater per mech per second for credits, and one per second for scrap kills, summed.
- **Placement:** each mech owns a spawn column above its head. Floaters in a column stack upward with a fixed vertical gap; if the column is full the oldest fades faster. Columns of neighbouring mechs offset horizontally to avoid overlap. Global cap of ~12 visible floaters; above that, merge into the nearest column's total.
- Big numbers use short suffixes (1.2K, 3.4M).

## Economy defaults (tune later)

- **Payout while alive:** `rate = base_rate(Core) * step^min(floor(t / interval), cap)` with `step = 1.5`, `interval = 5 s`, `cap = 6`. The Payout upgrade chain raises `cap` and lowers `interval`. Bounded, so lifetime is strong but not the whole game.
- **Deploy fee:** paid to the player on arrival, scales with Core tier.
- **Scrap per kill:** `kill_rate(Arms) * scrap_per_kill(Arms tier)`.
- **Salvage:** 40% of the mech's scrap cost. Upgrades raise it, hard cap 90%.
- **Cost curve for credit purchases:** `cost = base * 1.15^level`.
- **Tier upgrades cost a fixed scrap amount** per tier (rising per tier, not per line). Cheap enough to feel good, expensive enough that pausing a line matters.
- Run length target: 30–60 min active play. No offline progress.

## Upgrade menu (credits)

A fixed **UPGRADES** button opens a tabbed purchase menu. Everything here costs credits. Rows the player can't afford are greyed.

- **Tiers tab:** unlock the next tier of each segment type (global). The **Atomic Missile** is the last unlock in the list and is visible, locked, from the start.
- **Segments tab:** smaller work bar, more worker slots, per segment type.
- **Workers tab:** bigger work chunks, shorter chunk interval.
- **Yard tab:** scrap per tap, yard slots.
- **Payout tab:** step cap, step interval, deploy fee.
- **Salvage tab:** 40% → 90%.
- **Lines tab:** unlock line 2, 3, …

Each segment has a small ⬆ icon that jumps to its tier row. Tapping the segment body only fills the work bar.

## Segment tiers (scrap, per segment, per line)

- A tier is **unlocked once with credits** in the menu, then **applied per segment on each line for a fixed scrap price** by tapping the segment's tier button. Simple, satisfying click.
- A tier name **is the name of the part it produces**. A new game starts with a Frame that produces **Scrap Frames**.
- Upgrading swaps the part sprite for every mech built afterwards and raises the segment's per-mech scrap cost.

| Tier | Frame | Core | Arms | Plating |
|---|---|---|---|---|
| 1 | Scrap Frame | Junk Brain | Pipe Gun | Tin Sheets |
| 2 | Bolted Frame | Relay Box | Bolt Cannon | Boiler Plate |
| 3 | Steel Walker | Tube Core | Autocannon | Steel Plating |
| 4 | Composite Strider | Silicon Mind | Rocket Pod | Ceramic Armor |
| 5 | Titan Chassis | Quantum Core | Railgun | Reactive Armor |
| 6 | Atomic Colossus | Doom Core | **Atomic Missile** | Lead-Lined Hull |

## Endgame: the nuke

- The **Atomic Missile** is the final unlock in the menu. Unlocking it (credits) shows a confirmation: "This ends everything. Unlock?"
- Applying it to an Arms segment (scrap) turns that line's next mech into the **Nuclear Mech**.
- **Sequence:**
  1. The Nuclear Mech walks onto the battlefield and fires. The missile arcs off-screen.
  2. White flash, mushroom cloud expanding from the battlefield.
  3. A shockwave sweeps down the scroll pane, auto-scrolling with it. Lines, belts, segments and workers collapse into debris.
  4. Only the **scrap pile** remains. "Start again" prompt.
- Start again = fresh save. No prestige or carry-over for now; keep the save format open for it.
- Optional run-stats card: time, mechs built, credits earned.

## Screen layout (portrait)

```
┌──────────────────────────────┐
│ HUD: credits +/s  scrap +/s ⚙│  fixed
├──────────────────────────────┤
│ BATTLEFIELD (fixed, ~25%)    │  fixed, visuals only
│  mechs →  smoke  ✸   ← enemy │  floating +cr / +scrap
├──────────────────────────────┤
│ ▼ ScrollContainer (vertical) │
│ LINE 1                  ⏸    │  pause = stop burning scrap
│ [FRAME]=[CORE]=[ARMS]=[+ ]→  │  belt connects segments,
│  work ▓▓▓░ (tap / workers)   │  mech moves along, exits →
│  tier ⬆  +worker             │  tier = apply unlocked tier (scrap)
│ [ + UNLOCK LINE 2 · credits ]│
│ SCRAPYARD                    │
│  workers ⛏  [ SCRAP PILE ]  □│  tap pile, empty slot pad
│ [+ YARD WORKER] [BUY SLOT]   │
├──────────────────────────────┤
│        [ ⬆ UPGRADES ]        │  fixed, thumb zone → menu
└──────────────────────────────┘
```

- Lines and the scrapyard share **one scroll pane**. The scrapyard sits at the bottom; a new game starts scrolled to it.
- A new game shows line 1 with three empty segment slots to build, plus the scrapyard.
- Desktop layout is out of scope for v1 (letterbox the portrait column).

## Tech (Godot 4)

- **Rendering:** Compatibility renderer, for web export.
- **Pixel art:** base viewport 360×640 (or 720×1280 at 2×), `stretch mode = canvas_items`, keep aspect, texture filter **Nearest**.
- **Data:** segment types, tiers, upgrades and mech parts as `Resource` files. New segment types are data only.
- **Scene structure:** `Main` (HUD, `Battlefield`, `ScrollContainer` → `VBox` → `AssemblyLine` × N + `Scrapyard`, fixed `UpgradeButton`, `UpgradeMenu` overlay). `AssemblyLine` owns `Segment` nodes, the belt and mechs in transit. `Battlefield` owns active mechs, enemies, effects and the floater manager.
- **Simulation:** one tick in a central autoload (`GameState`), separate from visuals. Workers fire on timers, not per frame.
- **Save:** JSON in `user://` (IndexedDB on web). Save on change and on hide. No offline progress.
- **Poki:** Poki SDK via `JavaScriptBridge`. Gameplay start/stop, commercial break on run end, rewarded ads: 2× payout for 5 min, fill all work bars.
- **Input:** mouse and touch, one-thumb reachable. Touch targets ≥ 44 px at display scale.

## Art list (side view)

- Mech parts per tier (see table): frame, core, arms, plating. Layered sprites so combinations vary for free.
- Nuclear Mech, missile launch, flash, mushroom cloud, shockwave, flattened-factory debris.
- Mech walk cycle (4 frames), firing, muzzle flash, smoke ×3, explosion, debris.
- Enemies: 2–3 silhouette types with a death pop.
- Segment machines: gantry + tool per segment type, idle and working states. Empty slot pad.
- Belt tile (animated), scrap pile (fill states), stall icon.
- Worker: idle, shovel, carry.
- Battlefield background layers.