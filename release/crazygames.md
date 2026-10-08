# CrazyGames release

Checklist for publishing on crazygames.com. Status: live in Basic Launch since 2026-10-08 at https://www.crazygames.com/game/scrap-titans. Requirements read from their docs on 2026-10-05; re-check before submitting. Game state: `0.2.0-m20` ([M20](../docs/plan.md)); the live build is the no-ads one (`build/crazygames/`). Browser checks done except Android; the ads side of the SDK only against a fake backend.

## Why CrazyGames

- Poki rejected the developer application
- No exclusivity: "Publishing your game on other platforms doesn't affect your eligibility for revenue share on CrazyGames." (FAQ)
- No rule on AI-generated art in the requirements or quality guidelines; their FAQ lists creating art with AI tools. No ban, not a written permission: QA judges quality and originality
- No developer application: upload → QA → launch
- Portrait games welcome; HTML5 SDK v3, usable from Godot through `JavaScriptBridge`
- Ad revenue share, percentage not public; paid monthly from €100

## Launch stages

- Basic Launch: soft launch to a small share of players; SDK optional, ads off, no revenue. Wider rollout depends on play count, playtime, retention
  - Submitted for review on 2026-10-06 with the m19 build (no SDK, save in `user://`)
  - Live since 2026-10-08 with the m20 no-ads build (preset "CrazyGames"): https://www.crazygames.com/game/scrap-titans ← current stage
  - Real players from here on: every update has to load their saves
- Full Launch: second QA pass; SDK required, ads on

## Blockers for Basic Launch

- [x] Desktop legibility
  - Rule: text legible at `devicePixelRatio` 1 in 16:9 iframes
  - Before M18 the 360×640 column was fitted to the iframe height (0.72× at 821×462, 0.80× at 907×510): the font dropped strokes (`WAVE 4` garbled, `DMG/S` read `DNG/S`)
  - Now the column gets shorter instead, so nothing is below 1× from 462 px up; still pillarboxed, black bars beside it

    | Iframe | Column | Scale | Share of the width |
    |---|---|---|---|
    | 821×462 | 360×462 | 1.00× | 44 % |
    | 907×510 | 360×510 | 1.00× | 40 % |
    | 1077×606 | 360×606 | 1.00× | 33 % |
    | 1216×684 | 385×684 | 1.07× | 32 % |
    | 1280×720 (fullscreen) | 405×720 | 1.13× | 32 % |
    | 1366×768 (fullscreen) | 432×768 | 1.20× | 32 % |
    | 1536×864 (fullscreen) | 486×864 | 1.35× | 32 % |
    | 1920×1080 (fullscreen) | 607×1080 | 1.69× | 32 % |

  - Trade-off: at 462 high the pile is below the fold once the UPGRADES bar and UNLOCK LINE show (scroll or the pile pin); CREDITS scrolls there
- [x] Covers: `release/marketing/covers/` 1920×1080 (16:9), 800×1200 (2:3), 800×800 (1:1), from `tools/gen_covers.py`
  - Rules: title on each, same look across the three; no borders, no other text, no icons or store logos; not a plain screenshot; not blurry or pixelated
  - Upload form: no title or important element in the top left (labels cover it; marked about 40 % × 20 % on landscape, 40 % × 10 % on portrait) → titles moved below it
  - Pixel art at ×8: crisp, but their "pixelated" rule is a judgement call → look at them before submitting
- [x] Preview videos (the form requires both): `release/marketing/videos/landscape.mp4` 1920×1080, 17.9 s, 11 MB and `portrait.mp4` 1080×1620, 18.6 s, 12 MB, from `tools/make_videos.py`
  - Rules: 15–20 s (longer is cut), ≤ 50 MB, MP4 / MOV, 1080p landscape 16:9 and portrait 2:3, opens on the cover; no sound, cursor, black bars, black screen or logo transition, promo text, app icons; no fast-forwarding (they speed it up a little themselves)
  - Recorded play at 1× speed with cuts between stages: pile → first line and mech → a wave destroyed → three lines against a boss → nuke. Portrait = the whole screen; landscape = zoomed bands of it (the game itself is pillarboxed there) → their call whether that counts as representative
  - The in-game guide lines (TAP THE SCRAP PILE…) are in the first clips: game text, not promo text

## Submission form

- Category: Clicker. Tags (max 5): Idle, Incremental, Robot, Pixel, Management
- Marketing creatives URL: `https://distco.de/games/scraptitans/marketing/` (`release/marketing/`, uploaded by `tools/deploy_web.py`): covers, videos, screenshots, cover layers
- Description (no HTML; headings and lists through the editor):

  ```
  Scrap Titans is a pixel-art idle clicker about turning a pile of scrap into an army of combat mechs. Tap the pile, build an assembly line and send your machines to the front. Every enemy wave you break pays for a bigger factory, until you can build the one weapon that ends the war.

  How to play
  - Tap the scrap pile to dig up scrap and build the Frame, Core and Arms stations of your first line.
  - Tap a station to work on it, or hire a crew to do the work for you. A finished mech walks off the line and onto the battlefield.
  - Mechs shoot at the enemy wave and earn credits for every second they survive. A destroyed wave pays a bounty.
  - Spend credits on crews, upgrades and up to five assembly lines. Spend scrap on better parts, from Scrap Frames and Pipe Guns to Titan Chassis and Railguns.
  - Unlock the Atomic Missile, fit it on a fully upgraded line and launch the nuke to win the war.

  Features
  - A whole factory and its battlefield on one screen
  - Six tiers of parts that change how your mechs look and fight
  - Drones, tanks, brutes and a boss every fifth wave
  - A war takes 30 to 60 minutes, and every war you win starts a bigger one
  - Plays with one thumb on a phone or with the mouse on desktop
  ```

- Controls:

  ```
  - Left click or tap the scrap pile: dig up scrap
  - Left click or tap a station: work on its mech
  - Left click or tap the battlefield: hit the enemy wave
  - Left click or tap the buttons: build stations, hire crews, fit better parts, buy upgrades
  - Mouse wheel, swipe or the scroll bar on the right: move between the battlefield, the assembly lines and the pile
  - Pins at the ends of the scroll bar: keep the battlefield or the pile on screen
  ```

## Should fix before submitting

- [x] `user-select: none` on `body` (+ `-webkit-`, `-moz-`, `-ms-`): asked for against selection / magnifier on touch; via `html/head_include`
- [x] Boot splash and icon: title plate on the page colour, game icon (were Godot's defaults)
- [x] Safe areas: games run fullscreen in the CrazyGames app; the HUD and the UPGRADES bar move inside `env(safe-area-inset-*)`. Layout checked with a set inset; the real insets only show in their app → check on a notched phone after upload
- [x] iOS and low-memory Android run at device pixel ratio 1: 390 wide = 1.08×, legible in a desktop shot; the browser's upscale may blur it → checked on an iPhone (if soft: `image-rendering: pixelated` on the canvas, same head include)
- [x] Upload a release build: `tools/export_web.py release` (the default `debug` has the DBG panel)
- [x] Submission form: orientation portrait (the site asks players to rotate)
- [x] Browser checks (user): Chrome, Edge, Safari / iOS, a 4 GB Chromebook if one is at hand. Games that don't run smoothly there are disabled on Chromium OS, likewise on Safari
- [ ] Android browsers: not checked yet (incl. low-memory Android at device pixel ratio 1)

## Already fine

- Size: release build 15 MB, 9 files (wasm 13.0 MB, pck 1.9 MB). Limits: initial download ≤ 50 MB (≤ 20 MB for the mobile homepage), total ≤ 250 MB (50 MB without SDK), ≤ 1500 files
- No threads → no cross-origin isolation headers needed in their iframe
- Relative paths only
- English; no external links (credits URLs are plain text), ads, login, cross-promotion, custom fullscreen button
- PEGI 12 (own judgement): machines against machines, cartoon nuke
- Lands in gameplay: no menu, guide arrow on the pile (Full Launch rule: at most one click)
- Sim on a fixed 1/30 s tick: same speed at any refresh rate
- Audio: starts on the first input, HUD mute, hidden tab muted
- DBG panel removed from release builds
- No personal data collected → no privacy notice needed

## Full Launch

- [x] CrazyGames SDK ([M20](../docs/plan.md)): own wrapper over the HTML5 SDK v3 through `JavaScriptBridge` (their Godot addon is no longer in the asset library); upload `build/crazygames/` from `tools/export_web.py release CrazyGames` (no ads, Basic Launch: their upload check rejects a build that requests ads) or `build/crazygames_ads/` from `release CrazyGamesAds` (Full Launch), not `build/web/`
- [ ] First run against the real SDK (nothing of it has run in a browser yet): `tools/serve_web.py` with `WEB_ROOT=build/crazygames_ads` on localhost (demo ads), then their QA tool; the M20 test list in the plan
- [ ] Unknown until then: whether `sdk.data.getItem` / `game.settings` / `user.addAuthListener` behave as their docs say; an ads build in Basic Launch only learns of it from the first ad error, so one reward button press there does nothing before the ad UI hides
- [x] Gameplay start / stop events (required), loading start / stop (optional)
- [x] Ads only through the SDK; the game must work with an ad blocker; `Sound.ad_mute` exists; `game.settings.muteAudio` has to mute the game
- [x] Save through the Data module: 1 MB limit (save ≈ 15 KB), localStorage for guests; Progress Save toggle in the submission flow, else the module is disabled
- IndexedDB (`user://`) in their iframe: persistence across game updates and on Safari not verified

## Leaderboards

Read from their docs on 2026-10-08. Wanted: total mechs built and wars won. Not possible as asked, nothing built.

- Invited games only; the docs don't say how to get invited or at which launch stage → ask support / Discord
- One leaderboard per game
- Weekly seasons, Monday to Monday, reset at 9:00 UTC; no all-time board. Trophies for the top 3 and the top 1 / 5 / 10 %
- Rendered by CrazyGames (sidebar drawer, game page widget, profile awards; global, country, friends); no call to read scores → no in-game board
- Extra visibility: sidebar page, homepage carousels, widgets
- Portal config: guide text (≤ 50 characters), metric label (`POINTS`, `XP`, `KDA`, `MINUTES`), sorting, min / max score, cooldown in seconds, incremental flag
- Client submission: score AES-GCM encrypted with the portal's key (12 byte IV + ciphertext, base64), then `CrazyGames.SDK.user.submitScore({ encryptedScore, score })`. The key ships in the build → only min / max and the cooldown limit cheating
- Testing: only in the portal's preview tool; the response always reports success, a rejected score doesn't show
- Unknown: whether the incremental flag takes a running total or a delta, and what the weekly reset does to a lifetime total; whether guests can submit (`submitScore` is in the `user` module)
- Pick: mechs built (moves constantly, suits a weekly race), guide "Build as many mechs as you can". Wars won is a point per 30–60 min, mostly ties → stays the HUD counter
- Needs: `GameState.mechs_built` resets every war → a saved lifetime counter (seeded from `mechs_built` in old saves) and one per week; `submit_score` in `autoload/crazy_games.gd`; submitted on a timer above the cooldown and on a war won

## Engagement risks

Not requirements; they decide whether Basic Launch leads to a wider rollout. All deliberate prototype cuts.

- Hidden tab: no frames → the sim stands still (delta clamped to 0.25 s); idle players on desktop tab away → since M21 the away card pays a quarter of the factory's output for that time (≤ 1 h; in the repo, not in the live build yet)
- One 30–60 min run; START AGAIN keeps the wars won (bigger numbers, a bigger pile, M19), but no new content → little to come back for
- Desktop: a third to under half of the iframe, reads as a phone port
- Name: an itch.io jam game "Scrap Titans" exists; none found on CrazyGames (web search only)
- The cover drives clicks on a portal

## Re-check

```
godot --headless --path . -- --scenario desktop
godot --path . --display-driver x11 -- --scenario desktop --shots <dir>
```

- Resizes the window to every frame size above: column size, scale ≥ 1, UPGRADES on the bottom edge; overlays at 462; a set safe area
- Shots are the viewport's picture, not the frame's: a stretched picture (QA tool at m19: base height set inside `size_changed`) doesn't show there → look at the frame sizes in their QA tool
- Scenarios overwrite the desktop save (`~/.local/share/godot/app_userdata/Scrap Titans/save.json`, `settings.json`): back up first
- `--display-driver x11`: with the default driver a window that isn't visible ran at 1 fps and the scenario never finished; x11 runs stalled now and then too, retry

## Other platforms

All non-exclusive, can run alongside. Terms from third-party guides, news and search snippets (2026-10-08), not the platforms' own agreements → read those before committing.

Order:

1. itch.io, now: no gate, SDK or review, `build/web/` as is; AI allowed with mandatory disclosure (AI Generated tag + Graphics / Code sub-tags, untagged pages dropped from browse); no ad revenue, but a page of our own and written feedback. A jam game "Scrap Titans" exists there → distinct URL and cover
2. Playgama, after a week or two of CrazyGames numbers: one SDK (Bridge, Godot plugin in the asset library) for their portal, Yandex Games, GameDistribution, VK, Telegram and more; courts AI-built games; share reported as 70–80 % (sources disagree). A second backend behind the calls of `autoload/crazy_games.gd`, or their plugin
   - Why wait: every ad portal ranks on the same retention numbers (see Engagement risks) → weak numbers mean fixing the game first, not more SDKs

Ranked lower:

- Yandex Games directly: large mobile audience; requirements allow pre-generated AI assets; own SDK, 3–5 working days of moderation; localisation rules and payout to non-Russian developers not checked. Reachable through Playgama
- GameDistribution directly: open submissions, dashboard review; 33 % of net revenue, paid monthly from €50; no AI policy found. Reachable through Playgama
- GamePix, GameMonetize: about 45 %, own SDK each, smaller reach
- Y8: paid through an own AdSense account or by manual invoice
- Newgrounds: AI art banned in the Art Portal, game rules not confirmed → avoid

## Sources

- [Requirements overview](https://docs.crazygames.com/requirements/intro/)
- [Gameplay requirements](https://docs.crazygames.com/requirements/gameplay/) (iframe sizes)
- [Technical requirements](https://docs.crazygames.com/requirements/technical/)
- [Quality guidelines](https://docs.crazygames.com/requirements/quality/)
- [Game covers](https://docs.crazygames.com/requirements/game-covers/)
- [FAQ](https://docs.crazygames.com/faq/) (exclusivity, AI tools, portrait, payout)
- [Data module](https://docs.crazygames.com/sdk/data/)
- [Leaderboards](https://docs.crazygames.com/sdk/leaderboards/), [Leaderboards SDK](https://docs.crazygames.com/sdk/leaderboards-client/), [Leaderboard API](https://docs.crazygames.com/sdk/leaderboard-api/)
- [Playgama: CrazyGames policy on AI generated games](https://playgama.com/blog/?p=15221)
- [Playgama: the same HTML5 game on several portals](https://playgama.com/blog/?p=14160)
- [Playgama Bridge in the Godot asset library](https://godotengine.org/asset-library/asset/edit/13681)
- [Yandex Games requirements](https://yandex.com/dev/games/doc/en/concepts/requirements)
- [Cinevva: web game monetization](https://app.cinevva.com/guides/web-game-monetization)
- [Cinevva: best places to publish a web game in 2026](https://app.cinevva.com/guides/publish-web-game)
- [GamingOnLinux: itch.io AI disclosure](https://gamingonlinux.com/2024/11/itchio-store-now-requires-ai-generated-content-disclosures-for-assets)
- [Scrap Titans on itch.io](https://aabattery65021.itch.io/scrap-titans)
