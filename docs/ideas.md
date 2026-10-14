# Ideas for the numbers

What could lift the CrazyGames numbers ([feedback.md](feedback.md), Numbers; thresholds in [crazygames.md](../release/crazygames.md), Launch stages). Nothing here is decided; what gets picked moves to [plan.md](plan.md) as a milestone.

## Where we stand (2026-10-14)

Basic Launch result: mobile and tablet 9/15, will be enabled; desktop 8/15, below requirements → mobile first.

| | Mobile | Score, next at | Desktop | Score, next at |
|---|---|---|---|---|
| Playtime | 9m00s | 4, 5 at 12m51s | 12m23s | 3, 4 at 12m28s |
| Day 1 return | 3.91 % | 3, 4 at 4.71 % | 3.50 % | 3, 4 at 5.91 % |
| Conversion | 32.47 % | 2, 3 at 34.72 % | 51.51 % | 2, 3 at 58.06 % |

Reading the daily charts (about 55 mobile plays a day, so each day is noisy):
- Mobile playtime went from 6 min (m20) to 9–13 min (m22): the gate, the away card and the faster start help once someone plays
- Mobile conversion stayed at 26–39 % through both builds: the M22 first-minute changes (first mech at 17 s, field from the first frame) did not reach the players who leave. They leave before the first mech, or the first look isn't what they clicked for
- Day 1 return is a handful of players; 11 % for the mobile players of 10-12 shows it can move
- Conversion is the weakest score on both devices
- Each upload shows as a marker on the daily charts → one change set per upload, read 4–5 days after it

## Minimal: data, tuning, one small scene each (a day or less)

Mobile:
- Two free mechs on the field at the start of a war, short-lived: the first frame is the cover (mechs against drones), not a pile. The first station still costs scrap
- First guide line on the field: `TAP THE DRONES`. The cannon is the best tap in the game and pays credits; the pile comes second
- Rate in the HUD: `CREDITS 1.2K +38/s`; a buy that lifts it pops the delta
- A fallen gate costs the mechs on the field and refills the wave, the war goes on. The restart from the pile is a natural place to close the tab
- Daily crate: the first visit on a new day opens a supply crate (credits and scrap scaled to the war, more on a streak); `COME BACK TOMORROW FOR A SUPPLY CRATE` on the away card and the nuke card
- Away: `away_max` 1 h → 8 h with credits capped at a multiple of the next purchase the player can't afford (the M23 QA note: uncapped, one hour already paid for the missile)
- Gameplay crash 0.61 % on mobile, 0 on desktop: look for a WebGL context loss or memory on iOS while measuring phone heat (M23)

Desktop:
- Hold the mouse button = taps at a fixed rate on what's under it; Space taps too
- Covers: CTR bottom 20 % on both devices (desktop 0.7 %, mobile 1.7 %); a second cover try is an Art tab upload, no build

## Bigger: new systems on the current game (days each)

Mobile:
- Cold open, done properly: line 1 built, a mech walks out at 0 s, wave 1 dies at about 20 s with its bounty burst, first buy at 30 s; the pile and the stations come in as the next steps. Something new every 10 s for the first 90 s, checked in `tune`
- Supply crate drop every 2–5 min on the field; tapped within 10 s = a frenzy (×7 scrap for 30 s) or a free fit. The field becomes the screen to watch
- Three missions on screen (`BUILD 10 MECHS`, `CLEAR WAVE 6`), a reward each, the next goal never more than a minute away
- Kills feed the pile: wrecks fly from destroyed enemies to the pile and raise its rate. Field taps shoot and harvest, mechs fight and feed the factory; the two halves of the screen become one loop
- Hold to work: hold a thumb on the pile or a station = steady taps (upgradeable rate). Less mashing, longer phone sessions
- Boss every fifth wave with a timer (fail = one wave back) and an ability bar in thumb reach: airstrike, 10 s overdrive, gate shield, each on a cooldown
- Bulk fits: one fit for every line at once, ×10 crew hires (corvus: late fits cost too much clicking and scrap)
- War one in 10–15 min instead of 30–40: the nuke inside the first session, offered as a choice once affordable, with what the next war brings next to it

Desktop:
- The black bars hold what the phone has no room for: the upgrade list docked on the right, always open; missions and the war's figures on the left. The column stays the phone layout

## Very big: a different game around the same factory (weeks)

Mobile:
- Fronts instead of wipes: the nuke clears a front, the factory stays; each front brings new enemies, a boss, a new look; each war won is a pick of one of three permanent perks, then new station types (Reactor, Thrusters, Shields from the pitch). A campaign of days instead of a 40 min run, which is what day 1 and day 7 return measure
- Real idle: the factory runs while away (computed, not simulated), hours at full rate and upgradeable, the economy retuned for days. In the genre the return card is the product; ours pays a quarter of one hour
- The field as the game: mechs placed or merged on the field (two of a tier into the next), lanes the wave comes down; the factory supplies them. Merge and lane defence lead the portal charts; the factory alone is a spreadsheet to most phone players
- Mech codex: every part combination seen gets a card, collection shown in %; bosses drop blueprints for rare parts. A reason to come back that isn't a number

Desktop:
- A real landscape layout: the field across the top at full width, lines side by side below, the pile and the upgrade list beside them. Only once mobile is on track: desktop was below requirements and gets no traffic from CrazyGames until it is judged again

## Order

1. Minimal plus the cold open → [plan.md](plan.md) M24, one upload with the funnel; covers and videos days later as their own Art tab step
2. Bigger → M25 (supply drop, missions, hold to work, MAX everything) and M26 (war one in 10–15 min, wrecks to the pile, bosses, abilities; desktop panels only if desktop is re-judged), one upload each
3. Decide on a very big one from M24's read (M25's first item): fronts with perks is the one that answers day 1 return

Open:
- A funnel (first tap, first mech, wave 1, minute 1 / 3 / 5 / 10, gate fallen, nuke) would show where the 68 % leave; allowed: their docs recommend a third-party analytics service (ByteBrew), a privacy notice only if personal data beyond their SDK events is collected (checked 2026-10-14; → M24, anonymous)
- What desktop's "below requirements" means from here: judged again after updates, or never shown → ask their support (→ M24 support mail)

## Genre reference

Not measured: Cookie Clicker, AdVenture Capitalist, Clicker Heroes, Tap Titans, Egg Inc, Idle Miner Tycoon; portal clickers Capybara Clicker, Planet Clicker, Idle Breakout, Mr. Mine.

| Genre staple | Here |
|---|---|
| Offline progress is the product: hours at full rate, upgradeable, "you earned X" is the first thing on return | 1 h at 25 %, the sim stands still |
| Prestige is a choice with a preview ("reset now for +340 %") and a currency spent on a tree | The nuke is forced, ends the run; wars won = ×2 everything, no choice |
| The whole shop visible from the start, greyed, the next unlock one scroll away | Staged start hides what's coming until affordable |
| A random short-lived clickable (golden cookie) every few minutes | Nothing random ever happens |
| ×10 / ×100 / MAX buys, managers that buy for you | One tap per fit per station per line |
| The rate (credits/s) is the hero number, its jumps are celebrated | HUD shows stocks, not the rate |
| The first session contains the first prestige | First nuke at 30–40 min |
| Boss with a timer every n stages, fail = one stage back | The gate: lose = the war starts over |
| Decisions: which path, which build | Always the cheapest row |
