# Scrap Titans — Pitch (working title)

Idle/clicker for CrazyGames. Scrap in, combat mechs out. Pixel art, **everything in side view**, portrait mobile first. Target run: **30–60 min** from first tap to the nuke.

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
| **Scrap** | Pile taps, pile crew, salvage | Building stations, station tier upgrades, per-mech production cost |
| **Credits** | Deploy fee, battlefield payout, wave bounties | Workers, unlocking lines, unlocking upgrades in the menu |

## Assembly line

- Stations in belt order: **Frame** (legs + torso) → **Core** (head) → **Arms** (weapons). Later types: **Plate**, **Reactor**, **Thrusters**, **Shields**. N station types, data-driven.
- A line produces mechs once Frame + Core + Arms are built.
- Each station owns one stat:
  - **Frame** → lifetime.
  - **Core** → credit payout.
  - **Arms** → damage per second against the enemy wave, so bounty rate.
  - **Plate** → lifetime.
- **Work bar:** the only throughput gate. Fills from player taps (tap the station) and from the line's crew. It fills **even when no mech is present**, so work is banked. When full and a mech is waiting: deduct scrap, play the assembly animation (~0.5 s), attach the part, send the mech down the belt. Frame spawns the mech. The bar grows with the station's tier.
- A station holds one mech. If the next station is busy, the mech waits on the belt and blocks upstream.
- **Stalls must be visible:** bar full but no scrap (station flashes the scrap icon and waits), or downstream blocked.
- Stations are **connected by a conveyor belt**. The mech gains parts as it moves and walks off the right edge at the end.
- Throughput = slowest station.
- **Pause button per line** so the player can stop burning scrap while saving for a tier upgrade.
- More lines are **unlocked with credits**. Line N unlock cost follows the cost curve below.

## Workers

- **One crew per line.** The hire button under the line hires for credits, up to the line's cap (slots per station × built stations). Each chunk goes to the station with the emptiest bar, so the crew covers the bottleneck.
- A worker adds a **chunk of work every few seconds** (not continuous), so the bar visibly jumps. Yard workers add a chunk of scrap the same way.
- Cost formula: `cost = base * growth^n` where `n` = workers hired **on that line** (base 50, growth 1.1). Tune so the first worker arrives within the first few minutes.
- Slot caps are raised through the upgrade menu.

## Battlefield (nearly no UI)

- Mechs walk in from the left and fire at the enemy wave on the right. Enemies fire back. Better-equipped mechs stand in the front row, so upgrades show.
- No HP bars on mechs. Mech damage shows as smoke (3 intensities), then sparks, then explosion and debris. It follows remaining lifetime, not enemy fire.
- No combat sim beyond the wave: lifetime, payout and damage come from the stats; visuals play along.
- **Tapping the battlefield** (anywhere) hits the wave: a small share of its HP and the same share of its bounty as credits. The nearest enemy flashes. A cannon on top of the gate fires a shell at it for every tap; the cannon and its shells get bigger with the Harder hits upgrade.
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
- Run length target: 30–60 min active play.
- **While you were away:** the game stands still while its tab is hidden, the device sleeps or the game is closed. Coming back after a minute or more, a card pays for that time (at most 1 h) a quarter of what the factory made per second before: credits, and scrap after what the lines use. A factory that uses more scrap than it gets still pays a quarter of its scrap income, and never less than a pile tap every 2 s, so there is always scrap to collect. Nothing before the first mech.

## Upgrade menu (credits)

A fixed **UPGRADES** button opens a purchase menu: **one list, sorted by price**, cheapest first. Everything here costs credits. Rows the player can't afford are greyed.

- **Tiers:** unlock the next tier of each station type (global). The **Atomic Missile** is the last unlock and is visible, locked, from the start.
- **Crew per station:** more workers per station on every line.
- **Faster crews, Lighter work:** shorter chunk interval, lighter work bars (all stations).
- **Harder hits:** field taps hit harder.
- **Pile:** Scrap magnet (pile taps grab a share of the pile crew's output), Pile crew size, Bigger shovels (scrap per worker trip).
- **Pay:** Pay raises (step cap), Faster raises (step interval), Higher fees (deploy fee).
- **Salvage:** 0% → 60%.
- **Cheaper parts (mid game on):** every part costs less scrap, so late lines don't starve without pausing.
- **Enemy scrap (late game):** each enemy destroyed pays scrap.
- **New line:** unlock line 2, 3, …

Every row: a name that says what gets better, an effect line `LABEL a » b` (`WORKERS 2 » 3`, `EVERY 2S » 1.9S`), and an info button with a plain description. Tapping the station body only fills the work bar.

## Words

One word per thing, in every label, row, info text and guide line:

| Thing | Word | Not |
|---|---|---|
| Scrap source | pile, pile crew | yard |
| Machine on a line | station | pad, segment |
| A line's workers | line crew | station crew |
| Combat area | field | battlefield |
| Mech stats | LIFE, PAY, DMG | lifetime |
| Credits on deploy | fee | bonus |
| Better part on a station | fit (arrow button) | — |
| Nukes launched so far | wars won | prestige, level |

## Station tiers (scrap, per station, per line)

- A tier is **unlocked once with credits** in the menu, then **applied per station on each line for a fixed scrap price** by tapping the station's tier button. Simple, satisfying click.
- A tier name **is the name of the part it produces**. A new game starts with a Frame that produces **Scrap Frames**.
- Upgrading swaps the part sprite for every mech built afterwards and raises the station's per-mech scrap cost.

| Tier | Frame | Core | Arms | Plate |
|---|---|---|---|---|
| 1 | Scrap Frame | Junk Brain | Pipe Gun | Tin Sheets |
| 2 | Bolted Frame | Relay Box | Bolt Cannon | Boiler Plate |
| 3 | Steel Walker | Tube Core | Autocannon | Steel Plates |
| 4 | Composite Strider | Silicon Mind | Rocket Pod | Ceramic Armor |
| 5 | Titan Chassis | Quantum Core | Railgun | Reactive Armor |
| 6 | Atomic Colossus | Doom Core | **Atomic Missile** | Lead Armor |

## Endgame: the nuke

- The **Atomic Missile** is the final unlock in the menu, locked until every other part tier is unlocked. No confirmation: its row reads "Ends the war" and its info text says so.
- It can only be fitted on the Arms station of a **fully upgraded line**: every station built and carrying its best part.
- Applying it to an Arms station (scrap) turns that line's next mech into the **Nuclear Mech**.
- **Sequence:**
  1. The Nuclear Mech walks onto the battlefield and fires. The missile arcs off-screen.
  2. White flash, mushroom cloud expanding from the battlefield.
  3. A shockwave sweeps down the scroll pane, auto-scrolling with it. Lines, belts, stations and workers collapse into debris.
  4. Only the **scrap pile** remains. "Start again" prompt.
- START AGAIN starts the next war and counts a **war won** (below).
- Run card: time, mechs built, credits earned, wars won `n » n+1` and what the next war brings.

## Wars won (prestige)

- **START AGAIN** after the nuke adds 1 to **wars won**, kept for good. In the settings, RESET RUN restarts the current war (it keeps the count and adds nothing) and RESET SAVE starts from nothing, wars won included; both ask first.
- **Every war is bigger than the last.** Per war won, ×2: every cost in scrap and credits (stations, parts, fits, crews, upgrades, lines), every fee, payout and bounty, mech damage, enemy HP and scrap per kill. A run keeps its shape; the numbers grow.
- **The pile grows faster:** ×2.2 per war won for pile taps and the pile crew. Scrap gets easier war by war (short on scrap for 10 % of the first run, 7 % after one war won, 1 % after five, never after ten), so runs shorten from ~39 to ~29 min.
- Why pay and enemies scale with the costs: tiers, lines and crews cost credits, and credits come from mechs, not from the pile. With only the pile ahead of rising costs the bot needs 46 min after one war won, 80 after three and doesn't finish in 90 after five.
- **The pile shows it**, and only the pile: bigger and made of better scrap with every war won, one look per count from 0 to 10 (rust, then iron, steel, composite, gold, atomic). Its size no longer follows the scrap stock. Past 10 only the numbers grow.
- **HUD:** a nuclear disc with the count, from the first war won. START AGAIN sends that disc from the button to the HUD, the count goes up, then the next war starts.

## Screen layout (portrait)

```
┌──────────────────────────────┐
│ HUD: scrap mechs credits ☢3 ⚙│  fixed; ☢ = wars won
├───────────────────────────┬──┤
│ BATTLEFIELD (~25%)        │P │  pin P: fixed on top while pinned
│ ▓▓▓▓▓▓▓░░░ 1.2K/3K 45 DPS │  │  wave healthbar, tap = hit the wave
│  mechs →  smoke ✸  ← enemy│  │
│┌ LINE CREW 5/9 [+w 67]    │▐ │  one scroll pane, pixel scroll bar
││ FRAME [⬆ 2K] ARMS PLATE│▐ │  crew bar + pause strip form an L
││[▓▓▓]=[▓▓░]=[░░░]=[+ ]→   │  │  work bar = machine top,
│⏸ [ww ]  [w  ]  [ww ]      │  │  crew inside, belt, mech exits →
│┌ LINE CREW 3/9 ...        │  │  next line flush below
│  [ + UNLOCK LINE 2 · cr ] │  │
│ PILE CREW 2/4   [+w  40]  │  │  pile crew bar
│ w⛏ [SCRAP PILE] ⛏w        │P │  pin P: fixed at the bottom while pinned
├───────────────────────────┴──┤
│ [          UPGRADES     (3)] │  thumb zone → menu
└──────────────────────────────┘
```

- Battlefield, lines and scrapyard share **one scroll pane**, with a pixel-art scroll bar beside it. Its two pins (battlefield top, scrapyard bottom) fix their area to the top / bottom of the pane while it's in view; while it's scrolled away the pin lights up as a quick-access button that scrolls there.
- What's in view sets the soundscape: scrolled-away areas fade to a low level.
- The battlefield sits right under the HUD; factory and scrapyard stay at the bottom near the thumb; spare height is a gap between battlefield and factory.
- UPGRADES spans the bottom.
- **Staged start**, nothing shown before it can be used, everything eases in and stays:
  1. A new game (and START AGAIN: "only scrap remains") shows only the scrap pile, centered; the HUD shows only scrap.
  2. Once the pile has paid for the first station, line 1 fades in with all three pads while the scrapyard slides down to the bottom.
  3. The first mech deployed: the battlefield slides down from under the HUD (the mech walks onto it), with the scroll bar and the HUD's mechs and credits.
  4. Each purchase appears the first time it's affordable: pile crew, station crew, UPGRADES, UNLOCK LINE; pause strips at the first stall (from the start once a war is won).
- Desktop layout is out of scope for v1: the portrait column is pillarboxed and never scaled below 1× (in a short frame it gets shorter).

## Tech (Godot 4)

- **Rendering:** Compatibility renderer, for web export.
- **Pixel art:** base viewport 360×640 (or 720×1280 at 2×), `stretch mode = canvas_items`, keep aspect, texture filter **Nearest**.
- **Data:** station types, tiers, upgrades and mech parts as `Resource` files. New station types are data only.
- **Scene structure:** `Main` (HUD, `ScrollContainer` → `VBox` → `Battlefield` + `AssemblyLine` × N + `Scrapyard`, scroll bar with pins, fixed `UpgradeButton`, `UpgradeMenu` overlay). `AssemblyLine` owns `Segment` nodes, the belt and mechs in transit. `Battlefield` owns active mechs, the enemy wave and its healthbar, and effects. A top-level `Flyers` layer draws income discs.
- **Simulation:** one tick in a central autoload (`GameState`), separate from visuals. Workers fire on timers, not per frame.
- **Save:** JSON in `user://` (IndexedDB on web). Save on change and on hide, with its time and the output rates for the away card.
- **CrazyGames:** CrazyGames SDK via `JavaScriptBridge`, in a build of its own. Gameplay start/stop, midgame ad on START AGAIN, save through their data module, their mute setting.
- **Ads, all optional:** in the UPGRADES menu a rewarded video doubles all scrap for 5 min, or buys the next level of one of the three cheapest upgrades the player can't afford (never the Atomic Missile); one 3 min cooldown for both. On the away card a rewarded video doubles the payout. A banner only inside the open UPGRADES menu, never over the live game. No ad UI at all where ads aren't available.
- **Input:** mouse and touch, one-thumb reachable. Touch targets ≥ 44 px at display scale.

## Art list (side view)

- Mech parts per tier (see table): frame, core, arms, plate. Layered sprites so combinations vary for free.
- Nuclear Mech, missile launch, flash, mushroom cloud, shockwave, flattened-factory debris.
- Mech walk cycle (4 frames), firing, muzzle flash, smoke ×3, explosion, debris.
- Enemies: 3 types (Scrap Drone, Crawler Tank, Junk Brute) with a death pop; wave explosion and particles.
- Wave healthbar, credit and scrap discs.
- Station machines: gantry + tool per station type, idle and working states. Empty slot pad.
- Belt tile (animated), scrap pile (one look per war won, 0–10), stall icon.
- Worker: idle, shovel, carry.
- Battlefield background layers.