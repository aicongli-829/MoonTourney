# Scoring profiles and rule boundaries

Sources were reviewed on 29 September 2026. The engine validates completed scores, allocates table points and applies selected ranking criteria. It does not model match clocks, officiating, player eligibility or every competition-specific fallback. Configured overrides are organizer policies and are marked as custom.

| Preset ID | Completed match | Table policy | Reference / scope |
|---|---|---|---|
| `open-score` | Nonnegative final score; tied knockout needs an explicit winner | Organizer-configurable win/draw/loss points and ranking criteria; default 3 / 1 / 0 | Organizer-defined; useful for games or activities without a supported sport rule, with no federation standard claimed |
| `football` | Nonnegative final goals; tied knockout needs a shootout winner | 3 / 1 / 0, then goal difference and goals scored; club forfeit 3–0 | [Premier League explanation](https://www.premierleague.com/en/premier-league-explained); full final tie procedure is excluded |
| `basketball` | Final score must have a winner; forfeit 20–0 | Win 2, played loss 1, forfeit loss 0; points, mini-table points, difference, scored | [FIBA 2024 rules](https://assets.fiba.basketball/image/upload/documents-corporate-fiba-official-rules-2024-v10a.pdf), Articles 8/20 and Appendix D; classification is a club approximation |
| `volleyball` | Best of five, sets to 25, deciding set to 15, two-point margin | 3/0 for 3–0 or 3–1; 2/1 for 3–2; wins, points, set ratio, rally ratio, head-to-head | [2025–2028 playing rules](https://www.fivb.com/wp-content/uploads/2025/01/FIVB-Volleyball_Rules2025_2028-EN-v05.pdf) and [2026 Event Regulations](https://www.fivb.com/wp-content/uploads/2024/06/FIVB-Event-Regulations-2026_27022026_clean.pdf), Section 8; full final mini-table fallbacks excluded |
| `beach-volleyball` | Best of three, sets to 21, deciding set to 15, two-point margin | Club win 2 / loss 0; wins, set ratio, rally ratio | [FIVB beach rules](https://www.fivb.com/beach-volleyball/the-game/official-rules-of-the-games/) |
| `badminton-21` | Best of three, 21 points, two-point margin, cap 30 | Club win 2 / loss 0; points, head-to-head, set ratio, rally ratio | [BWF statutes and laws](https://corporate.bwfbadminton.com/statutes/) |
| `badminton-15` | Best of three, 15 points, two-point margin, cap 21 | Same club table policy as above | [BWF alternative scoring appendix](https://system.bwfbadminton.com/documents/folder_1_81/Regulations/Laws/Part%20II%20-%20Section%201B%20-%20Appendix%203%20-%20Other%20Scoring%20Systems.pdf) |
| `table-tennis` | Default best of five; odd best-of configurable; each game 11, two-point margin, no cap | Club win 2 / loss 0; points, head-to-head, set ratio, rally ratio | [ITTF statutes](https://www.ittf.com/statutes/); the implemented 11-point scoring subset is documented in [the 2025 edition](https://db.ittf.com/sites/default/files/public/2025-02/2025_ITTF_Statutes_clean_version.pdf), Sections 2.11/2.12; current competition regulations must be checked separately |
| `chess` | Input `1–0`, `0–1`, or `1–1` for a draw | Exact internal half-point units: 2 / 1 / 0; points, played-opponent Buchholz, played-opponent SB | [FIDE Handbook](https://handbook.fide.com/); virtual-opponent and unplayed-round corrections excluded |
| `esports` | Default best of three maps; each map exactly 1–0 or 0–1 | Club win 3 / loss 0; points, head-to-head, map difference, maps won | Organizer-defined; no universal esports standard claimed |

The BWF 15-point system is exposed as an alternative profile, not automatically substituted for 21 points. Worldwide adoption was announced for **4 January 2027**; federations may adopt different local dates. See the [Spanish federation announcement](https://www.badminton.es/news/163151/La-Asamblea-General-de-la-BWF-aprueba-el-nuevo-sistema-de-puntuacion-315).

## Terminal scores and series

A game must end on a legal winning point: `21–19`, `22–20` and `30–29` are accepted for badminton 21; `21–20`, `22–19` and `31–29` are rejected. A match cannot contain another set after a player has won the required number. Set totals must match the aggregate match score. Tied football and open-score knockouts can have a separate winner; the decider is not added to the recorded score. A league game cannot use a decider.

The independent series API handles multiple full games, for example a basketball best-of-seven playoff. This is distinct from a volleyball set match or an esports map match. It reports whether the series is complete and the next game number. It does not attach a multi-game series to bracket fixtures automatically.

The volleyball 2/1 narrow-match split applies to the default best-of-five, win-3/loss-0 configuration. Changing that match length or the win/loss points switches to the configured flat win/loss allocation; it does not silently retain a federation table policy.

## Rankings

Criteria are evaluated in configured order. Initial seed only stabilizes display when values remain equal; equal positions retain an equal rank. Add `seed` explicitly to resolve final ties by initial seeding. Group advancement fails when an equal rank spans the qualification cutoff.

`head-to-head` is the sum of table points earned against opponents with equal overall points (and equal wins for volleyball). It is a static mini-table, not a pairwise comparator. It does not recursively recompute mini-tables after a subset separates, or include mini-table goal/rally difference. Those distinctions matter for complete FIBA/FIVB classification.

Ratios use integer cross multiplication. A positive numerator over zero outranks a finite ratio; two such ratios are equal. Zero over zero is treated as zero. Chess Buchholz sums **played** opponents' final points; Cut-1 drops the lowest played-opponent total. SB multiplies opponent points by points earned against that opponent. Forfeits and pairing byes do not invent opponents. These are disclosed club metrics, not complete FIDE tie-break regulation implementations.

## Format policies

- Seeded brackets use standard balanced placement and expand to the next power of two. A pending opponent is never treated as a bye.
- Double elimination includes an upper and lower bracket. The grand final places the upper champion at home. An away win activates a reset; an upper-champion win leaves it inactive.
- Groups use snake distribution. Qualification places are interleaved by rank, with same-rank seed swaps to avoid opening same-group games when a local repair is possible. This is not a federation-specific draw protocol and does not guarantee later-round group separation.
- Home/away groups use the same distribution and qualification rules, but play two legs with reversed sides. A changed group result removes the old knockout, so qualifiers must be recalculated.
- League playoffs rank all entrants after one or two reversed legs per pair. The top power-of-two count of active entrants advances to a seeded single-elimination bracket. Equal ranks among the qualifying seeds or at the cutoff require an explicit final tie-break. A league result edit removes the old bracket so it can be seeded again from corrected results.
- Club Swiss searches up to 50,000 nodes per bye candidate. It avoids repeat pairings, prefers closer scores, balances home/away softly and permits at most one full-point bye per entrant. It can return the best valid pairing found before the limit, without proving global optimality. FIDE Dutch rules, absolute color restrictions, acceleration and virtual-opponent corrections are not implemented.
- Swiss playoffs use the same disclosed Club Swiss pairing policy for a configured number of rounds. Active entrants are ranked on Swiss results only; an unresolved tie within the playoff seeds or across the qualification cutoff blocks advancement. A changed Swiss result clears later Swiss rounds and the playoff. This is an organizer format, not a federation-certified Swiss system.
- An inactive entrant forfeits a ready game against an active entrant. Two inactive entrants remain unresolved for an organizer decision. Withdrawal does not erase earlier results.

## Scheduling

Times are minute offsets, independent of time zones. Future bracket slots reserve rest for all possible entrants, so the plan is conservative and may be longer than necessary. Known results narrow the candidate sets. Match duration is an organizer estimate; rain delays, venue opening intervals, travel and rolling live clocks are outside this version.
