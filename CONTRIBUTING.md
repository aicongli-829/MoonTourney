# Contributing

Describe the concrete event workflow or rule bug, include a small synthetic example, and state the intended policy. Distinguish published scoring rules from organizer-defined tournament rules. Link a primary source and its edition for rule changes.

Domain decisions belong in the MoonBit core. Browser and Node adapters should stay thin. Add a behavior test when changing a nontrivial algorithm or state transition. Avoid tests that only repeat the implementation, source padding, generated files and private participant data.

Before a pull request:

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon test --target wasm-gc --deny-warn
node scripts/build.mjs
node tests/smoke.mjs
```

Maintain portable root code. Do not silently add a seed tie-break, treat pending entrants as byes, retain invalid dependent results or promise complete federation compliance from a scoring subset. Public snapshots should be treated as read-only by callers. Tracked docs and UI are English.
