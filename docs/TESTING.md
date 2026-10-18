# Validation strategy

## Core behavior suite

The MoonBit suite checks invariants and edge cases rather than only snapshotting output:

- Round-robin pair coverage, unique round participation, odd-field byes and reversed return legs.
- Single-elimination match counts, pending-versus-vacant slots, seed placement and third place.
- Double-elimination completion across field sizes 2–24, both reset outcomes, and exactly two losses for every non-champion.
- Group size balance, completed-group requirements, qualification ties, cross-group openings and knockout invalidation.
- Sport terminal scores, hard caps, deciding-game targets, aggregate validation, overtime outcomes, shootouts, canonical forfeits and independent playoff series.
- Ranking ties, static head-to-head mini-tables, exact large ratios, played-opponent Buchholz / SB, rally and set totals.
- Multi-round Swiss no-repeat pairing, single byes, field exhaustion, withdrawals and re-pairing after edits.
- Two-leg group qualification and fixed-length Swiss-to-knockout transitions, including stale bracket clearing.
- Single- and two-leg league qualification, equal-rank blocking, seeded playoff completion, snapshot round trips and bracket invalidation after a league score edit.
- Open-score draws, explicit knockout deciders and rejection of invalid deciders outside elimination.
- Season archive round trips, mixed-sport collections, fresh-season cloning, title history, duplicate identity rejection and CLI archive operations.
- New-season roster regeneration before scoring, rejection after scoring and CLI archive updates without changing the previous season.
- Independently validated court/rest plans, multi-day playing windows, partial horizons, dependency order and malformed allocations.
- JSON schema validation, fractional numbers, duplicate identities/results, unknown actions, snapshot round trips, history branches and CSV formula protection.

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon test --target wasm-gc --deny-warn
node scripts/build.mjs
node tests/smoke.mjs
```

`scripts/check.ps1` runs this sequence on Windows. If a locally assembled toolchain lacks a core target bundle, run `moon bundle --target wasm-gc` from its `lib/core` directory before using that target. This is toolchain preparation, not a project package dependency.

## Integration smoke

The Node smoke test exercises the compiled MoonBit CLI and engine with a test-owned temporary directory: create, record, inspect, schedule, export, no-overwrite behavior, malformed JSON, unknown commands and a clinched basketball series. It does not duplicate tournament calculations in JavaScript.

## Web acceptance

Check desktop and narrow layouts. Fill an example, create a competition with automatic season archiving, inspect the generated fixtures and suggested daily timetable, reject an invalid score, record a legal score from the fixtures or timetable, inspect automatic advancement, undo and redo, change filters, read ranking explanations, update courts and daily hours, export and import a snapshot, and reload to restore browser state. Browser history is intentionally not persisted. Check that changing a result refreshes the suggested timetable and its export.

## Known limits

Local validation on 18 October 2026 used `moon 0.1.20261012` and Node.js 22. Formatting, strict checks, 72 tests on each of JavaScript, Native and Wasm GC, release builds and the CLI / engine smoke passed. Combined formats, season collections, daily scheduling windows and roster changes were exercised through library and CLI tests.

Browser review on 17 October 2026: the new desk was opened at a local loopback URL. Desktop and 390-pixel layouts were inspected, a narrow-screen horizontal overflow was fixed, the event shortcut was checked, and entering then undoing a score updated the new progress indicator from 0/28 to 1/28 and back. The full result-entry matrix, all tournament formats and native download behavior were not rechecked in this visual pass.

Current formatted MoonBit source: 6,301 implementation lines plus 1,635 test lines. Counts include normal formatting and comments; they exclude generated output, dependencies and toolchains. Source size is reported for review, not enforced as a quality test.

Swiss search is bounded and not a formal FIDE certification. Schedule efficiency is not globally optimized. The current suite is not a comprehensive federation compliance suite, a security audit, or a benchmark at unrestricted scale. Refer to [RULES.md](RULES.md) for the behavior promised by each profile.
