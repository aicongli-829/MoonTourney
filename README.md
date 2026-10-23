# TokeiMBT

A MoonBit port of the code statistics tool
[Tokei](https://github.com/XAMPPRocky/tokei) (XAMPPRocky/tokei, Apache-2.0/MIT).

TokeiMBT counts code, comments and blank lines, groups results by language,
and provides terminal, JSON, CSV and YAML reports. It imports **333 language
definitions** from Tokei v15.0.0. Automated comparison fixtures cover 201
definitions shared with the runnable Tokei 12.1.2 release; the exact test
scope is documented in [PORTING_STATUS.md](PORTING_STATUS.md).

The imported table includes MoonBit. The v12.1.2 executable serves as a
comparison reference for definitions shared by the two releases.

The MoonBit module is `aicongli829/tokei`.

Run `moon run cmd/main -- tests/fixtures/plain` to get a real sample report:

```text
===============================================================================
 Language            Files        Lines         Code     Comments       Blanks
===============================================================================
 C                       1            6            4            2            0
 Go                      1            6            4            1            1
 JavaScript              1            5            4            1            0
 Python                  1            6            5            1            0
 Rust                    1            7            6            1            0
===============================================================================
 Total                   5           30           23            6            1
===============================================================================
```

## Why

- **For MoonBit's own ecosystem**: every MoonBit repo (including all
  hackathon projects) benefits from a first-class LOC tool that also
  understands `.mbt`/`.mbti` files.
- **Tokei implementation in MoonBit**: the language grammar table is
  generated from Tokei's `languages.json` (333 definitions). The scanner
  handles line and block comments, quotes and shebangs. Differential tests
  compare its results with the runnable upstream release.

## Build & Run

```bash
moon update  # fetch the Mooncakes index for moonbitlang/x
moon build --target native
# Windows binary: _build/native/debug/build/cmd/main/main.exe
moon run cmd/main -- path/to/project
moon test --target native  # 45 tests, including broad delimiter smoke tests
python tools/verify_release.py  # checks build, tests, language table and CLI
```

On Windows PowerShell, run these commands from this folder. To include the
optional official differential checks, pass a Tokei 12.1.2 executable:

```powershell
python .\tools\verify_release.py --upstream C:\path\to\tokei.exe
```

Requires the MoonBit toolchain (https://www.moonbitlang.com) and
`moonbitlang/x` (`moon add moonbitlang/x`).

## Usage

```text
tokei [FLAGS] [OPTIONS] [path]...

FLAGS:
    -h, --help               Print this help message
    -V, --version            Print version information
    -l, --languages          Print supported languages and their extensions
    -f, --files              Print individual file statistics beneath each language
    -C, --compact            Hide embedded-language detail rows in the table
        --hidden             Count hidden files
        --no-ignore          Do not respect ignore files
        --no-ignore-dot      Do not respect .ignore or .tokeignore
        --no-ignore-vcs      Do not respect .gitignore
        --no-progress        Compatibility flag (accepted, ignored)

OPTIONS:
    -o, --output <FORMAT>    Output format: table, json, csv, yaml (default: table)
    -i, --input <FILE>       Merge a previously saved JSON report
        --output-file <FILE> Write output to FILE instead of stdout
    -t, --type <LANGS>       Only count the given languages (comma separated)
    -T, --type-not <LANGS>   Count everything except the given languages
    -e, --exclude <PATTERN>  Ignore files/directories matching PATTERN (repeatable)
    -s, --sort <ORDER>       Sort by files, lines, blanks, code, comments or language
    -n, --num-format <STYLE> Format table numbers: plain, commas, dots, underscores
    -c, --columns <WIDTH>    Set the terminal table width (minimum 79)
    -r, --reverse            Reverse the sort order
```

Examples:

```bash
moon run cmd/main -- .                         # count current directory
moon run cmd/main -- -o json --output-file stats.json .  # JSON report to file
moon run cmd/main -- -t rust,python -s code .  # only Rust+Python, sorted by code
moon run cmd/main -- -i stats.json .            # merge saved statistics with a fresh scan
```

## Architecture

| Package    | Responsibility                                                        |
|------------|-----------------------------------------------------------------------|
| `lang/`    | 333 imported definitions; 201 shared definitions have basic differential fixtures |
| `counter/` | per-file line-classification state machine (code/comment/blank)       |
| `ignore/`  | ignore pattern matching for `.gitignore`, `.ignore`, `.tokeignore` |
| `walk/`    | recursive file discovery, hidden/binary filtering, language lookup    |
| `report/`  | aggregation and sorting                                               |
| `output/`  | table / JSON / CSV / YAML rendering                                   |
| `cmd/main` | CLI entry point                                                       |

The core is a single-pass character scanner per line that tracks cross-line
state (block-comment depth, current string token), matching the longest
delimiter first — this is what makes results agree with tokei on tricky
inputs such as `"/* not a comment */"` inside strings or nested `/* /* */ */`.

## Testing

```bash
moon test --target native        # scanner, ignore, CLI and output tests
./tools/compare_tokei.ps1 DIR   # Windows: compare with upstream tokei (JSON)
tools/compare_tokei.sh DIR      # Bash: same comparison
```

The differential scripts run both implementations over the same inputs
and compare language and file reports. They require an upstream Tokei binary, which is
not installed by this project. On Windows, the pinned comparison matrix can
be reproduced with the official Tokei 12.1.2 binary:

```bash
python tools/diff_matrix.py --upstream path/to/tokei.exe
python tools/compare_structured.py --upstream path/to/tokei.exe \
  --port _build/native/debug/build/cmd/main/main.exe \
  tests/fixtures/embedded/sample.ipynb
```

The matrix generates 1,341 simple fixtures across the 201 language definitions
identical in the v12.1.2 and v15.0.0 tables and compares per-file language,
code, comment and blank counts. The complete JSON report for that generated
directory also matches after path normalization and report-order sorting.
The comparison covers these generated cases; additional cases are tracked in
[PORTING_STATUS.md](PORTING_STATUS.md).

Eight terminal-output cases are also compared line-for-line against Tokei
12.1.2 after normalizing Windows path separators: ordinary and wide tables,
embedded-language rows, `--files` for a notebook, compact mode, and grouped
numbers. JSON `--input` accepts a saved report file and preserves
per-file and child-language counts.

`tools/verify_release.py` is the local release gate. It verifies that all 333
generated language keys match the pinned official table, runs strict MoonBit
checks and tests, builds the native CLI, and checks a real MoonBit JSON report.

## Attribution & License

- Language definition data is converted from the pinned
  [Tokei v15.0.0 snapshot](vendor/tokei-v15.0.0/README.md), licensed under
  Apache-2.0 OR MIT. Regenerate `lang/data.mbt` with
  `python3 tools/gen_lang_data.py > lang/data.mbt` and run `moon fmt`.
- This project is licensed under Apache-2.0 (see LICENSE).

## Roadmap

- Expand differential fixtures to the rest of the language table and richer syntax
- Add nested embedded-language cases, `--input stdin`, and more CLI options
- Read configuration files and provide optional CBOR serialization
- `--folders` per-directory statistics
- HTML output format
- Parallel scanning for very large repositories
- Broader embedded-language support beyond basic `.ipynb` code/Markdown cells
