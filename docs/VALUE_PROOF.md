# Use cases and inspectable evidence

## Problem

A small competition often spreads decisions across a pairing sheet, a score sheet and a timetable. If a semifinal result is corrected, the organizer must remember which final and third-place results became invalid. If a group cutoff is tied, stable row ordering can accidentally be mistaken for a real qualification rule. MoonTourney makes those dependencies and policies explicit.

## Concrete scenarios

| Scenario | Organizer task | Runnable evidence |
|---|---|---|
| Eight-team campus football cup | Two groups, six games each, two qualifiers per group, cross-group opening knockout | `examples/football-groups.json`; tests for group cutoff ties, pairing repair and group-result invalidation |
| Six-player badminton evening | Handle two byes, legal extended scores, semifinal dependencies and a third-place game | `examples/badminton-cup.json`, `examples/badminton-result.json`; CLI smoke and single-bracket simulations |
| Seven-player chess club | Pair score groups without repeat opponents, assign a different bye, explain half-point standings | `examples/chess-swiss.json`; multi-round Swiss, bye, opponent-metric and withdrawal tests |
| Eight-team esports cup | Best-of-five maps, two-loss elimination, conditional grand-final reset | `examples/esports-double.json`; double-elimination simulations for both final outcomes |
| Community volleyball league | Different deciding-set target, 3–2 points split, exact set and rally ratios | Scoring and standings tests for 25-point / 15-point games, 2/1 points and ratio zero denominators |
| Two-court club day | Prevent participant overlap and allow rest before a later bracket game | `examples/schedule.json`; independent allocation validation and short-horizon tests |
| Home/away group cup | Play both sides of each group pairing, then qualify entrants for a final bracket | `examples/football-home-away-groups.json`; full group-to-knockout test and correction invalidation |
| Community league cup | Play a complete table with organizer-defined scores, then seed the top four into a playoff | `examples/community-league-playoff.json`; API smoke plus qualification, tie-blocking and edit-invalidation tests |
| Home/away football season | Play reversed fixtures before the top four enter a playoff | `examples/football-league-home-away.json`; two-leg league and snapshot round-trip tests |
| Spring and Summer club program | Save Spring results, reuse the same setup for Summer without carrying over scores, inspect both winners and export the archive | `season-new`, `season-add`, `season-clone`, `season-list` CLI smoke; collection round-trip and mixed-format tests |
| Swiss chess playoff | Complete three score-based pairing rounds, rank active entrants, then seed a four-player knockout | `examples/chess-swiss-playoff.json`; round-limit, qualification, snapshot and stale-bracket tests |

## Acceptance demonstration

Run the badminton commands in [CLI.md](CLI.md), then import the resulting JSON into the web desk. Confirm that the scored game shows `2 : 1`, that its winner occupies the corresponding semifinal, and that pending fixtures remain waiting. Change the opening result after a later fixture is scored: the dependent result must disappear. Undo must restore the previous snapshot.

For group or league qualification, complete every first-stage game. A tie across the cutoff must block advancement unless an explicit final criterion has been configured. Knockout results must not affect the original tables. For double elimination, a lower-champion victory in the grand final must activate a reset; the upper champion cannot be eliminated on a first loss.

## Evidence quality

The examples use synthetic entrants and the tests exercise actual algorithms. They establish reproducible behavior, not real-world adoption or speed compared with spreadsheets. User interviews, production event records and external integrations have not yet been collected. These are the next validation steps, rather than invented evidence for an application form.

## MoonBit value

The domain engine is portable across JavaScript, Native and Wasm GC. UI rendering and CLI command logic are also written in MoonBit. The same validated transitions are used by the web desk, command line and JSON integration boundary, so consumers do not need to reimplement ranking and bracket dependency rules.
