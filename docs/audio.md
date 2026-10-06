# Audio

Sound design, tuning and the sound assignment. How it's built: [tech.md](tech.md) → Audio. Milestone: [plan.md](plan.md) M11.

## Goals

- Ambience that carries what the factory and the battlefield are doing, without getting on the nerves over a 30–60 min run
- Music: Juhani Junkala "Ending" (Retro Game Music Pack), now and then, never nonstop
- Sounds and mixing in `data/audio.json`, like the other tunables
- Mute toggle in the HUD, volume steps per bus in ⚙ → AUDIO

## Rules against annoyance

- Player actions (pile, station, battlefield taps, buys) sound at once, crisp, always (within voice caps); fast tapping (over ~4 taps/s) gets gradually quieter, down to −6 dB, back to full after a pause (`soften`)
- No onset clicks: every sound file starts with a 3 ms fade-in
- Automated activity (workers, deploys, shots, income) is quiet and thinned. More activity raises an ambience bed instead of adding more one-shots
- Only what's on screen: assembly only for stations inside the scroll pane, deploys only for visible lines, shots only from drawn mechs; areas scrolled out of view play quietly (`areas`)
- Variation: 2–4 files per frequent sound, random pick without direct repeat, pitch jitter
- Limits per sound: `cooldown` (plays inside it are dropped) and `voices` (max at once). The whole battlefield shares a budget (`groups.field` plays/s)
- Rewards stand out: wave clear, unlocks, fits are the loudest regular sounds and rare
- No repeating alarms: running out of scrap is a soft power-down, once per starved phase, ≥ 20 s apart
- The factory hum follows assemblies in the last 4 s, so pausing or starving lines audibly quiets the factory

## Tuning (`data/audio.json`)

- `sounds.<id>`: `files` (pack names without `.wav`, in `audio/sfx/`), `volume_db`, `file_db` (per-file offset, for uneven variants), `pitch` (± share), `pitch_base`, `cooldown` s, `voices`, `group`, `area`, `bus` (`ui`, `battle`, `factory`, `music`), `soften` (true: fast repeats get quieter)
- `groups.<name>`: max plays per second across all sounds of the group
- `soften`: `step_db` per play, `recover_db` per s, floor `min_db`; −1.5 / 6 / −6 → full up to 4 taps/s, then down to −6 dB (within ~1 s at 8 taps/s)
- `areas.<name>.hidden_db`: level of an area's beds and sounds when it's scrolled off screen; in between it follows the visible share; a pinned area is always in view. Areas: `field` (battlefield, −18), `factory` (lines, −15), `yard` (scrap pile, −15). Battlefield, lines and pile share one scroll pane, so scrolling crossfades the soundscape: wind + battle up top, factory hum in the middle, pile and yard crew at the bottom
- `beds.<id>`: looped on the `Ambience` bus; `drive` (`assembly_rate` per s, `mechs` drawn) / `full` = level, smoothed over `smooth` s; no drive = constant
- `music`: `volume_db`, `first_after` (s after the first mech, 0 = with it), `loops` (track repeats per play), `gap` [min, max] s between plays, `fade_in`, `fade_out`, `duck_db` (Ambience while music plays)
- `defaults`: first-run settings (`muted`, steps 0–`steps` per bus)
- `trim_db`: per bus, added to the step level. UI, battle, factory −24, ambience −12: the default step 4 plays where step 1 (sounds) and step 2 (ambience) of the old single SOUNDS row were, the baseline picked by ear; master +4, so its step 4 is 0 dB
- Levels were set from measured loudness (active RMS) toward a target per role: taps −17, buys −19, UI −22, assembly/deaths −23, busy (shots, pops, coins) −27, quiet −30, rewards −16, nuke −12 dBFS (before `trim_db`). Short hits (< 0.12 s) ~1.5 dB over their target, since they sound quieter at the same RMS. Tune by ear from there; a reload picks up changes
- Intensity pass (felt too intense overall): factory taps −3 dB with lighter files, buys −4 dB with shorter tails, Pipe Gun shots and coins −2 dB with longer cooldowns, yard crew −3 dB, battlefield budget 8 → 5/s; then factory taps +2 dB back (got lost under a busy factory/battlefield). Measured: −20–30 % plays/min (late game 680 → 480), ~2 sounds at once on average (was 2.7)

## Buses

- MASTER: everything (HUD mute and step 0 mute it)
- UI: every direct user interaction and nothing else: buttons, menus, buys, pause/resume, pile, station and battlefield taps
- BATTLE: battlefield (shots, enemy fire, pops, deaths, wave clear/bounty/arrival) + nuke sequence
- FACTORY: yard crew, assembly, deploys, stall, collapse, credit coins
- AMBIENCE: all beds (wind, battle rumble, factory hum); ducked under the music
- MUSIC: Ending, run card fanfare (`volume_db` −30: no −24 trim on this bus)

## Music

- Ending, 44.6 s: exactly 16 bars (256 sixteenths at ~86 BPM), ends on the grid, seam step no bigger than its own square-wave edges, so it loops seamlessly; no real ending, so it always fades out
- Starts with the first mech (`first_after` 0); each play loops the track `loops` (2) times, ~90 s, fading out over the last 4 s; then a random `gap` (4–7 min) before the next
- Stops (1 s fade) when the Nuclear Mech deploys; the run card ("THE WAR IS OVER") plays it 1.5 s after the fanfare; START AGAIN stops it and the new run's first mech starts it again
- Not saved: a reload starts the schedule over

## Sound assignment

Picked by measurement, not by ear (loudness, envelope, brightness, noisiness, pitch direction for all 6009 pack files, spectrograms of the shortlists), then approved by listening. Listening page with alternatives: `assets/__import/audition.html` (git-ignored, next to the pack).

Factory
- `pile_tap`: short_contact_sound_33, 97, 100, 126; noisy 0.13–0.18 s crunches, cut below 200 Hz (17–21 % of their energy was a thump)
- `yard_hit`: same set, −10 dB below the tap, pitch 0.85
- `station_tap`: sounds_impact8, impact4, impact14; light metallic ticks (≤ 13 % energy below 250 Hz), unlike the pile; impact5 dropped (32 %: a thump)
- `assemble_frame`: piledriver; `assemble_core`: machine_activates3; `assemble_arms`: wpn_reload; `assemble_plate`: machine_big_97
- `mech_exit`: platform_launched
- `stall`: machine_shutdown
- `pause` / `resume`: pause2_in / pause2_out
- Bed `factory`: escalator_loop (4 s low rumble with a roller pulse)

Battlefield
- Bed `field`: windy1(loop) (32 s soft gusts), softened: low-pass 2.5 kHz, gusts compressed (swell over the floor 25 → 13 dB); bed `battle`: shuttle(loop) (distant rumble)
- `shot_pipe` (Pipe Gun): weapon_singleshot2, 22, 7; `shot_bolt` (Bolt Cannon): weapon_shotgun1, weapon_singleshot8; `shot_burst` (Autocannon): wpn_machinegun_loop2, loop5 (3 pulses = the 3-round burst); `shot_rocket` (Rocket Pod): wpn_missilelaunch, `rocket_hit`: exp_shortest_soft1, soft7; `shot_beam` (Railgun): wpn_laser6
- `enemy_shot_drone`: wpn_laser8; `enemy_shot_crawler`: laser; `enemy_shot_brute`: wpn_cannon4
- `field_tap`: sounds_impact12, sounds_impact11, damage_hit1, 5, 7, 10 (Simple Damage Sounds: short noisy hits with a falling sweep, like the impacts; the gated chiptune blips left out)
- `enemy_pop`: exp_shortest_soft2, 5, 6, 8; `enemy_pop_big`: exp_short_soft4 (the "soft" explosions decay smoothly; the "hard" ones are bit-crushed and harsh)
- `mech_death`: exp_short_soft3, soft11
- `wave_clear`: exp_cluster5, then `bounty`: coin_cluster4 (0.3 s later); `wave_arrive`: turn_enemy (0.6 s after)

Income, buys, UI
- `coin` (credit disc lands): coin_single3, single5, ≥ 0.25 s apart; `coin_big` (tier 3 disc): coin_double1; scrap discs silent
- `build`: machine_activates1; `fit`: upgrade_30; `hire`: gain_ability; `buy_upgrade`: upgrade_19; `buy_tier`: upgrade_long_14; `unlock_line`: positive_complex10; the last three cut to 0.35 / 0.5 / 0.8 s with a fade-out (were 0.68 / 0.92 / 1.32 s)
- `menu_open` / `menu_close`: ui_menu_open / ui_menu_close (UPGRADES, settings); `click`: menu_click_mini (every other button)

Nuke
- `nuke_alarm`: alarm_scifi_dramatic, every 2.9 s while the Nuclear Mech walks in
- `nuke_launch`: wpn_missile2
- `nuke_blast` + `nuke_rumble`: exp_long5 + dark Impact at the flash
- `shockwave` + `shockwave_boom`: sweep3 + noisy_low_boom when the sweep starts
- `collapse`: exp_cluster1, machine_destroyed, per line and the yard
- `run_card`: fanfare5, then the Ending music

Not used on purpose: robot/cyborg death screams (too comic ×50 deaths), alarm loops outside the nuke, `lazer_current(loop)` (piercing buzz), coin counter, speech.

## Size

- 70 files, 1.6 MB imported (QOA); pck 305 KB → 1.9 MB (1.6 MB brotli). The wind bed is the biggest file (32 s, ~280 KB)
- Web decodes every sample to 48 kHz stereo float: ~49 MB of `AudioBuffer`s (music 17, wind 12). If the iPhone struggles: cut the wind to a ~10 s loop, then drop it

## License

- Sounds and music: SubspaceAudio (https://subspaceaudio.itch.io/), CC BY 4.0; music by Juhani Junkala. Credited in ⚙ → CREDITS with the changes made (mixed to mono; faded, trimmed, filtered). New pack files → keep the credits in sync

## Open

Rest of the intensity plan, after listening to the first pass:
- Bright battle sounds (shots, pops, deaths: 25–44 % of the energy above 4 kHz, most files ~4 %): bake a low-pass ~6 kHz, then re-level everything by K-weighted loudness (plain RMS rates bright files 2–3 dB too low)
- Nuke sounds −3 dB; if it's still too much overall, the ui/battle/factory trims −3 dB
- Yard crew: the 1 s cooldown barely thins it (60 → 54/min, workers swing ~1/s); 2 s if it nags
