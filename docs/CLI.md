# Command-line interface

Build with `node scripts/build.mjs`. The CLI needs Node.js 22 or later for the small file adapter. Core command parsing, JSON requests and tournament decisions are MoonBit.

| Command | Usage |
|---|---|
| Help | `node dist/moontourney.mjs help` |
| Rule profiles | `node dist/moontourney.mjs presets` |
| Create | `node dist/moontourney.mjs create config.json [new-event.json]` |
| Inspect | `node dist/moontourney.mjs inspect event.json` |
| Record | `node dist/moontourney.mjs record event.json result.json [new-event.json]` |
| Clear / invalidate | `node dist/moontourney.mjs clear event.json fixture-id [new-event.json]` |
| Change unscored roster | `node dist/moontourney.mjs roster event.json names.json [new-event.json]` |
| Start group, league or Swiss knockout | `node dist/moontourney.mjs advance event.json [new-event.json]` |
| Next Swiss round | `node dist/moontourney.mjs next-round event.json [new-event.json]` |
| Withdraw | `node dist/moontourney.mjs withdraw event.json entrant-id [new-event.json]` |
| Schedule | `node dist/moontourney.mjs schedule event.json settings.json [new-schedule.csv]` |
| Export | `node dist/moontourney.mjs export event.json kind [new-file]` |
| Full API | `node dist/moontourney.mjs request request.json [new-response.json]` |
| New season archive | `node dist/moontourney.mjs season-new "Community 2026" [new-series.json]` |
| Add event as season | `node dist/moontourney.mjs season-add series.json event.json "Spring 2026" [new-series.json]` |
| List seasons | `node dist/moontourney.mjs season-list series.json` |
| Extract one event | `node dist/moontourney.mjs season-extract series.json season-key [event.json]` |
| Start next season | `node dist/moontourney.mjs season-clone series.json season-1 "Summer 2026" [new-series.json]` |
| Update saved season | `node dist/moontourney.mjs season-update series.json season-key event.json [new-series.json]` |
| Remove season | `node dist/moontourney.mjs season-remove series.json season-key [new-series.json]` |
| Rename archive | `node dist/moontourney.mjs season-rename series.json "Club 2026" [new-series.json]` |
| Export archive | `node dist/moontourney.mjs season-export series.json json\|seasons-csv\|history-csv [new-file]` |

Bracket/group/Swiss mutations output a **snapshot**. Inspect outputs a **view**. Request outputs the **full envelope**. Export outputs content only. Defaults use stdout; supplying a path writes a new file with exclusive creation. Never redirect a command over its own input file: the shell may truncate the file before the CLI reads it.

## Reproducible badminton example

```sh
node dist/moontourney.mjs create examples/badminton-cup.json event.json
node dist/moontourney.mjs record event.json examples/badminton-result.json round1.json
node dist/moontourney.mjs inspect round1.json
node dist/moontourney.mjs schedule round1.json examples/schedule.json courts.csv
node dist/moontourney.mjs export round1.json report report.md
```

Six entrants occupy an eight-slot bracket; two have byes. `w-1-2` is a real opening game. The supplied result wins 2–1 in sets and resolves one semifinal slot. The input event stays unchanged.

## Settings

Create examples are in `examples/`. `seedTieBreak: true` is an organizer decision that resolves otherwise equal final table positions by original seed. Without it, a qualification cutoff tie blocks advancement.

`examples/football-home-away-groups.json` demonstrates home/away group fixtures before knockout. `examples/chess-swiss-playoff.json` demonstrates a fixed number of Swiss rounds followed by a four-player playoff. Use `next-round` after completing each Swiss round, then `advance` after the configured final round.

`examples/community-league-playoff.json` combines open-score results, a single round robin and four playoff places. `examples/football-league-home-away.json` uses two reversed legs for every league pairing. Record every league game before `advance`; a result edit clears the old bracket, preserving the corrected table.

Schedule settings use `courts`, `duration`, `rest`, `start`, `horizon`, `dayStart` and `dayEnd`, measured in minutes. `dayStart` and `dayEnd` define the repeating daily playing window; omit them for all-day planning. A horizon of 1440 is the end of offset day zero. The planner may report games that do not fit; the schedule command fails in that case. Use a full `request` to examine partial allocations and `unscheduled` together.

Errors go to stderr and set exit status 1. Writes do not overwrite existing paths. Reads are bounded to 4 MB and accept UTF-8 with an optional BOM.

## Spring and Summer workflow

```sh
node dist/moontourney.mjs create examples/community-league-playoff.json spring-event.json
node dist/moontourney.mjs season-new "Community 2026" seasons-empty.json
node dist/moontourney.mjs season-add seasons-empty.json spring-event.json "Spring 2026" seasons-spring.json
node dist/moontourney.mjs season-clone seasons-spring.json season-1 "Summer 2026" seasons-summer.json
node dist/moontourney.mjs season-extract seasons-summer.json season-2 summer-event.json
node dist/moontourney.mjs roster summer-event.json examples/summer-entrants.json summer-reseeded.json
node dist/moontourney.mjs season-update seasons-summer.json season-2 summer-reseeded.json seasons-reseeded.json
node dist/moontourney.mjs season-list seasons-summer.json
node dist/moontourney.mjs season-export seasons-summer.json history-csv history.csv
```

Each output path is new. The original season remains unchanged when you clone it; the new one has the same entrants, rules and format with an empty result map. `season-extract`, `roster` and `season-update` let you change Summer's teams before recording results. The web desk applies the entrant list and updates its active season automatically. Once a result exists, roster replacement is rejected.
