# Security and data handling

The web desk performs calculations locally and stores the latest event in browser local storage. Exported snapshots contain entrant names and results; use synthetic entrants in bug reports. This storage is not encrypted and can be cleared by browser settings. Undo history is in memory only.

The bundled development server listens on `127.0.0.1` and serves only the web page, stylesheet and compiled UI. It has no mutation endpoint. The CLI reads only paths supplied by the user and writes new output files with exclusive creation; it never intentionally overwrites an existing file. It is not a directory management tool.

JSON imports are bounded and validated. The UI escapes entrant names and other imported text before HTML rendering. Rule source URLs come from known profiles. CSV exports prefix potential spreadsheet formulas and quote cells; review exported data before opening it in spreadsheet software with unusual import settings.

Report reproducible vulnerabilities privately to the repository maintainer using GitHub's private reporting feature if available. Do not place personal event records, credentials or private file paths in public issues. No external security audit is claimed.
