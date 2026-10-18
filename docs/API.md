# JSON API

`dispatch_json(source : String) -> String` always returns an envelope:

```json
{"ok":true,"data":{}}
```

```json
{"ok":false,"error":"Complete the current Swiss round first."}
```

All numbers used as integers must be integral and bounded. Participant IDs and seeds are unique positive integers. Unknown actions, malformed JSON, illegal scores, unresolved dependencies and qualification ties produce error envelopes. Consumers must check `ok` before using `data`.

## Actions

| Action | Additional fields | Success data |
|---|---|---|
| `presets` | None | `presets` array with rule sources and scope |
| `create` | `title`, `format`, `rules`, `entrants` (names); optional `groupCount`, `qualifiers`, `swissRounds`, `thirdPlace`, `seedTieBreak` | Competition view |
| `inspect` | `tournament` | Competition view |
| `record` | `tournament`, `result` | Updated competition view |
| `roster` | `tournament`, `names` (array of entrant names) | Regenerated fixture graph before any result exists |
| `clear` | `tournament`, `fixtureId` | Updated view with dependent results cleared |
| `advance` | `tournament` | View with group, league or Swiss playoff knockout |
| `next-round` | `tournament` | View with next Club Swiss round |
| `withdraw` | `tournament`, `participantId`; optional `active` (default false) | Updated view with ready forfeits settled |
| `schedule` | `tournament`; optional `courts`, `duration`, `rest`, `start`, `horizon`, `dayStart`, `dayEnd` | `allocations`, `unscheduled`, `csv` |
| `export` | `tournament`, `kind`; optional `stage` | `content`, `kind` |
| `series` | `rules`, `games`, `bestOf` | `homeWins`, `awayWins`, `complete`, `nextGame`, `winnerSide` |
| `season-new` | `title` | Empty season collection view |
| `season-inspect` | `collection` | Collection, season progress and participant history |
| `season-extract` | `collection`, `key` | One season's `tournament` snapshot |
| `season-add` | `collection`, `label`, `tournament`; optional `key` | Updated collection view |
| `season-update` | `collection`, `key`, `tournament` | Updated collection view; preserves season identity |
| `season-clone` | `collection`, `sourceKey`, `label`; optional `key`, `title` | New season with copied format, rules and entrants, empty results |
| `season-remove` | `collection`, `key` | Collection view without that season |
| `season-rename` | `collection`, `title` | Updated collection view |
| `season-export` | `collection`, `kind` (`json`, `seasons-csv`, `history-csv`) | `content`, `kind` |

Formats: `round-robin`, `double-round-robin`, `league-playoff`, `league-double-playoff`, `single-elimination`, `double-elimination`, `groups`, `groups-double`, `swiss`, `swiss-playoff`. `groups-double` plays each group pairing twice with reversed sides. League playoffs use `qualifiers` (a power of two, default 2) and advance only after every league game finishes; editing a league score clears the playoff. `swiss-playoff` uses `swissRounds` (default 3) and `qualifiers` (a power of two, default 2). Tied seeding or cutoff positions require an explicit final tie-break. Export kinds: `json`, `fixtures-csv`, `standings-csv`, `report`.

Rule configuration is either a preset string or an object with `id` and optional `bestOf`, `target`, `finalTarget`, `winBy`, `cap`, `winPoints`, `drawPoints`, `lossPoints`, `forfeitScore`, `pointScale`, `tieBreaks`. Display labels, source URLs and scope are derived from the preset rather than trusted from imported JSON. `seedTieBreak: true` adds an explicit final seed criterion at creation; false removes it.

The `open-score` preset accepts a nonnegative final score for any organizer-defined activity. A league draw is valid; a tied knockout requires `decider: 1` or `2`. Win/draw/loss points and ranking criteria can be configured. It does not claim sport-specific official rules.

## Results

Score-based game:

```json
{"fixtureId":"w-1-1","home":2,"away":2,"decider":1}
```

Set-based match (aggregate is computed if absent):

```json
{"fixtureId":"w-1-2","sets":[{"home":21,"away":18},{"home":21,"away":19}]}
```

Canonical forfeit:

```json
{"fixtureId":"w-1-1","kind":"forfeit","winnerSide":2}
```

## Snapshot and view

A `schemaVersion: 1` snapshot includes title, format, rules, participants, fixtures, results, groupCount, qualifiers and swissRounds. Older snapshots without swissRounds remain importable. Exported results follow fixture order. A view contains `tournament` (the snapshot), resolved `fixtures`, stage-specific `tables` and `champion`. It is a projection, not an importable snapshot: save `data.tournament`, or use export kind `json`.

A season collection uses `seasonSeriesVersion: 1`, a title and up to 32 ordered `{key, label, tournament}` entries. Keys and labels must be unique. Entrant names must be unique within each season; historical appearances and titles match the same exact name across seasons. A collection view is a projection: save `data.collection`, or use `season-export` with `json`. Each embedded tournament is validated on import. Score totals are not combined across profiles because football goals, chess points and volleyball sets are different quantities.

`roster` rebuilds a tournament using the same title, rules, format and configuration with a new ordered entrant list. It requires zero recorded results; IDs and seeds are assigned from the new list. Use `season-update` to save that rebuilt tournament into a collection when working through the JSON API.

Slot JSON: `{"kind":"entrant","id":1}`, `{"kind":"winner","fixture":"w-1-1"}`, `{"kind":"loser","fixture":"w-1-1"}` or `{"kind":"bye"}`.

Chess standings store points as integer half-point units; `pointsLabel` is the human-readable value. SB explanations show the scale denominator explicitly. The web input `1–1` is a chess draw and is not a double win.

Scheduling times are minute offsets, not timestamps. `dayStart` and `dayEnd` are minutes after midnight (0–1440), and every scheduled game must fit inside that daily window. Omit them for all-day planning. The CSV has start and end minute columns. Partial schedules expose `unscheduled`; an integration must display or handle that list. The convenience CLI refuses to emit a silently partial schedule.
