# Scheduling scope and adjacent Mooncakes packages

This note addresses the October 2026 application review question about the boundary between MoonTourney's match scheduling and recently published Mooncakes packages. It describes the public packages checked on 20 October 2026 and the code that can be reproduced in this repository. It does not claim that every package or unpublished submission has been examined.

## What MoonTourney schedules

MoonTourney has two connected stages:

1. **Competition fixtures:** generate opponents and dependencies from a selected format (round robin, elimination, groups, Swiss or a combined format). Record results, recalculate standings and advancement, and invalidate dependent results when an earlier score changes.
2. **Suggested court timetable:** assign the currently generated fixtures to numbered courts and minute offsets within a repeating daily playing window. The planner respects fixture dependencies, court occupancy and a rest interval for *every possible entrant* in a future knockout match. It reports fixtures that do not fit the requested horizon. `validate_schedule` checks imported allocations independently.

The second stage is a bounded greedy suggestion, not an optimal timetable solver. It does not model real calendar dates, time zones, venue opening exceptions, entrant availability, travel distance, referee assignment or federation certification. Later Swiss pairings and group/league playoffs require actual results; the planner does not invent them in advance. Suggested times can change when results arrive.

The implementation is in [`round_robin.mbt`](../round_robin.mbt), [`brackets.mbt`](../brackets.mbt), [`swiss.mbt`](../swiss.mbt), [`standings.mbt`](../standings.mbt), [`tournament.mbt`](../tournament.mbt) and [`scheduling.mbt`](../scheduling.mbt). The distinction between fixture generation and court allocation matters: the latter alone is not the project's main reusable contribution.

## Public package comparison

| Package | Published focus | Boundary with MoonTourney |
|---|---|---|
| [100kkk/moon-schedule](https://mooncakes.io/docs/100kkk/moon-schedule) | UTC Cron and RFC 5545 recurrence calculations | Computes when recurring calendar events occur. MoonTourney assigns *competition fixtures* to courts after deriving opponents and dependencies. It does not parse Cron or RRULE. |
| [cj3335556/moonbit-4d-schedule](https://github.com/cj3335556/moonbit-4d-schedule) | Construction activities, CPM/PERT, resource leveling and 4D BIM progress | Both projects schedule constrained work, so there is a broad algorithmic overlap. Its documented objects are activities and construction resources; MoonTourney's are competitors, matches, results, advancement and courts. MoonTourney does not claim CPM, PERT or resource optimization. |
| [zhou506403/fairshift](https://mooncakes.io/docs/zhou506403/fairshift@0.1.0) / [rosterweave](https://mooncakes.io/docs/zhou506403/rosterweave@0.1.0) | Workforce shift rosters under staffing, skills, rest and fairness constraints | Both mention rest and allocations. Their public package summaries describe assigning workers to shifts; MoonTourney schedules matches whose participants may depend on preceding results. It does not solve workforce coverage or fairness. |
| [tlhuecdkoyg/MoonFixture](https://mooncakes.io/docs/tlhuecdkoyg/MoonFixture@0.1.1) | Reproducible relational test-data construction | `Fixture` here means test data, not a sports match. MoonTourney previously used this working name and changed it to avoid a naming collision. |

The Mooncakes homepage [search API](https://github.com/moonbitlang/mooncakes.io#build--run) was checked with `tournament`, `round robin`, `Swiss`, `fixture`, `schedule`, `sport`, `court`, `赛事` and `赛程`. Some queries returned unrelated software, and intermittent TLS/timeouts prevented a complete result set for every term. This search is **discovery evidence only**. A public package that implements competition pairing, results, standings, advancement and match-to-venue allocation would require a direct API and workflow comparison. If reviewers have such a package in mind, a package name or URL would allow an exact comparison.

## Reproducible boundary example

After building with `node scripts/build.mjs`, run these commands from the repository root. Use fresh output paths; the CLI never overwrites an existing file.

```sh
node dist/moontourney.mjs create examples/badminton-cup.json event.json
node dist/moontourney.mjs schedule event.json examples/schedule.json courts.csv
node dist/moontourney.mjs record event.json examples/badminton-result.json round1.json
node dist/moontourney.mjs inspect round1.json
```

The example starts with six badminton players in an eight-slot elimination bracket, assigns known matches to two courts, records a real opening score and resolves a later bracket slot. The timetable has no independent knowledge of those dependencies; it receives them from the same tournament engine that validates scores and advances entrants. See [`scheduling_wbtest.mbt`](../scheduling_wbtest.mbt) for court, rest, dependency, daily-window and partial-horizon checks, and [`tests/smoke.mjs`](../tests/smoke.mjs) for the compiled CLI path.

## Scope of the claim

The project is a competition engine with a modest integrated court planner. Its distinctive *combination* is format-specific fixture generation, result-dependent progression, scoring and standings, court planning and a usable web/CLI workflow in MoonBit. It does not claim that generic scheduling algorithms or individual tournament formats are new, or that it has no possible overlap with a package not identified here.
