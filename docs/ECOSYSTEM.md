# Ecosystem positioning

## Scope of the project

The deliverable is a reusable competition engine with a web reference application. Its public domain types are participants, fixtures, results, rules, standings and allocations. It does not implement local file search, generic filesystem migration, HTTP capture, request mocking or replay.

## Search evidence and limits

An initial review on 29 September 2026 examined a Mooncakes registry snapshot of 2,721 package records and public GitHub discovery queries for MoonBit tournament / fixture / bracket / Swiss / round-robin projects. Chinese scheduling queries were also examined. Reviewed discovery results did not identify a directly matching multi-sport tournament engine with these workflows; several keyword matches concerned networking round-robin behavior, individual games, or project catalogs.

A fresh Mooncakes search on 16 October 2026 covered tournament, bracket, fixture, round-robin, Swiss, league, standings, elimination, pairing and Chinese competition terms. It found no published package with the same end-to-end competition engine. It did find `tlhuecdkoyg/MoonFixture`, a relational **test-data generator** unrelated to sports, but with the same name as this project's original working title. This project is now named **MoonTourney** to avoid that naming collision. `0Ayachi0/SwissTable` is a hash table, and the tournament match in `bobzhang/games` is an archery game.

This is **negative discovery evidence**, not a proof that no overlapping project exists. Package metadata and public search do not cover unpublished work, private repositories, recent unindexed submissions or the organizers' internal project list. The detailed local research snapshots remain in ignored private materials, not in the distributed package.

Public entry points for independent checking:

- [Mooncakes registry](https://mooncakes.io/)
- [MoonBit tournament repository discovery](https://github.com/search?q=MoonBit+tournament&type=repositories)
- [MoonBit Swiss repository discovery](https://github.com/search?q=MoonBit+Swiss&type=repositories)
- [MoonBit fixture repository discovery](https://github.com/search?q=MoonBit+fixture&type=repositories)

## Reusable contribution

A MoonBit application can use the library without its web UI, without Node filesystem adapters and without a network service. Examples include a club portal displaying an event table, a desktop organizer computing brackets, a student competition dashboard and an esports map-score application.

Evidence of usefulness is supplied through runnable scenarios, rule-boundary documentation and behavior tests. No adoption numbers, organizer endorsement, federation certification or guaranteed hackathon approval are claimed. Before final submission, compare any newly identified similar project by actual public APIs and core workflows, and describe concrete differences.
