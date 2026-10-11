# Player feedback

Feedback on the live build (https://www.crazygames.com/game/scrap-titans), newest first. One entry per thing said or seen, not per person.

## How to log

- Log what was said or measured, in the player's words where possible; the reading of it goes in Notes
- Build = the version from settings (`0.2.0-m20+102.bb5dfcc`), or `live` with the date if unknown
- Source: `cg-comment` (game page), `cg-qa` (their QA / review mails), `cg-stats` (developer portal numbers), `playtest` (someone watched playing), `direct` (told to me, with the name), `own` (own play on the live build)
- Kind: `bug`, `confusing`, `balance`, `wish`, `praise`, `number`
- Status: `new` → `planned` (with the plan.md milestone) / `done` (with the commit) / `no` (with the reason in Notes)
- Same thing again: add the date and source to the existing entry's Notes instead of a new row; three sources on one entry is a reason to plan it

## Open

| Date | Build | Source | Kind | What | Notes | Status |
|---|---|---|---|---|---|---|
| 2026-10-08 | live 2026-10-08 | direct: corvus | balance | Late-game upgrades to stations cost too much scrap | Probably the fits (arrow button) of the last tiers: `apply_cost` 10K / 40K per station and line. Not asked: which tier, how many lines, how many wars won | new |

## Numbers

Developer portal figures worth tracking per build; one row per look.

| Date | Build | Plays | Avg. playtime | Day 1 return | Notes |
|---|---|---|---|---|---|
| 2026-10-11 | live, since launch (day one m20, then m22) | 423 | 10m10s | 2.78 % | Totals since 2026-10-08, the portal has no per-build view; minus the day one row: 282 plays, about 9m03s, conversion about 40 %. 348 players, 54K impressions, CTR 1.1 %; conversion 40.77 %; returning users 2.59 %; day 7 return 0 % (not 7 days live); rating 9.5 from 19 votes; load 0.9 s, load crash 0.22 %, gameplay crash 0.22 %. Desktop: 242 plays, 203 players, 34K impressions, CTR 0.7 %, playtime 12m26s, conversion 50.72 %, day 1 return 3.13 %, load crash 0.37 %; minus day one: 165 plays, about 10m13s (was 17m12s), conversion about 52 % (was 47 %). Mobile: 181 plays, 145 players, 20K impressions, CTR 1.7 %, playtime 7m09s, conversion 32.31 %, day 1 return 2.27 %, gameplay crash 0.56 %; minus day one: 117 plays, about 7m27s (was 6m36s), conversion about 29 % (was 39 %). Their score ([crazygames.md](../release/crazygames.md), Launch stages): 8/15 on desktop and on mobile, 9 needed on each. Next point on desktop: playtime 12m28s (2 s away), conversion 58.06 %, day 1 return 5.91 %; on mobile: conversion 34.72 %, playtime 8m49s, day 1 return 4.71 % |
| 2026-10-09 | live 2026-10-08 | 141 | 12m23s (mid range) | no data yet | First day. 107 players, all new; 16K impressions (mid range, mostly game pages), CTR 1.1 % (bottom 20 %); gameplay conversion 42.46 % (bottom 20 %); rating 10.0 from 10 votes; load 0.7 s, crash rate 0.69 %. Desktop: 77 plays, 59 players, 11K impressions, CTR 0.6 %, playtime 17m12s, conversion 46.84 %, load crash 1.19 %. Mobile: 64 plays, 48 players, 4.8K impressions, CTR 2.1 %, playtime 6m36s, conversion 39.00 %, gameplay crash 1.61 % |

## Closed

Entries with status `done` or `no` move here.

| Date | Build | Source | Kind | What | Notes | Status |
|---|---|---|---|---|---|---|
