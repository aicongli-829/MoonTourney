#!/usr/bin/env python3
"""Run the local checks needed before publishing this Tokei port.

Usage:
    python tools/verify_release.py
    python tools/verify_release.py --upstream path/to/tokei-12.1.2.exe

The optional upstream binary enables differential checks; it is never
downloaded or included in the repository.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "vendor/tokei-v15.0.0/languages.json"
GENERATED = ROOT / "lang/data.mbt"


def run(*args: str) -> str:
    result = subprocess.run(
        list(map(str, args)),
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def verify_language_table() -> None:
    official = json.loads(SNAPSHOT.read_text(encoding="utf-8"))["languages"]
    literals = re.findall(r'^\s+key: ("(?:\\.|[^"\\])*")',
                          GENERATED.read_text(encoding="utf-8"), re.MULTILINE)
    generated = [json.loads(literal) for literal in literals]
    if len(generated) != len(official) or set(generated) != set(official):
        raise SystemExit("Generated language keys differ from the pinned official v15 table")
    if "MoonBit" not in official:
        raise SystemExit("MoonBit is missing from the pinned official table")
    print(f"language definitions: {len(official)} official v15 keys match generated MoonBit data")


def binary_path() -> pathlib.Path:
    path = ROOT / "_build/native/debug/build/cmd/main/main"
    if sys.platform == "win32":
        path = path.with_suffix(".exe")
    if not path.is_file():
        raise SystemExit(f"Built CLI not found: {path}")
    return path


def verify_cli(binary: pathlib.Path, expected_languages: int) -> None:
    listing = run(binary, "--languages")
    if not listing.startswith(f"Languages: {expected_languages}\n"):
        raise SystemExit("CLI reports the wrong language count")
    if "  MoonBit (mbt, mbti)" not in listing:
        raise SystemExit("CLI does not advertise MoonBit extensions")
    report = json.loads(run(binary, "-o", "json", "counter/counter.mbt"))
    moonbit = report.get("MoonBit")
    if not moonbit or moonbit["code"] <= 0 or len(moonbit["reports"]) != 1:
        raise SystemExit("CLI could not count its own MoonBit source file")
    if report["Total"]["code"] != moonbit["code"]:
        raise SystemExit("Total and MoonBit counts disagree")
    with tempfile.TemporaryDirectory() as tmp:
        saved = pathlib.Path(tmp) / "previous.json"
        saved.write_text(json.dumps(report), encoding="utf-8")
        merged = json.loads(run(binary, "--input", saved, "-o", "json",
                                "counter/counter.mbt"))
        if merged["Total"]["code"] != report["Total"]["code"] * 2:
            raise SystemExit("CLI could not merge a saved report with a fresh scan")
        if len(merged["MoonBit"]["reports"]) != 2:
            raise SystemExit("Saved per-file reports were not preserved")
    print("CLI smoke test: language listing, MoonBit report and saved JSON merge pass")


def verify_terminal_parity(binary: pathlib.Path, upstream: pathlib.Path) -> None:
    cases = [
        (ROOT / "tests/fixtures/plain", []),
        (ROOT / "tests/fixtures/plain", ["-c", "100"]),
        (ROOT / "tests/fixtures/embedded", []),
        (ROOT / "tests/fixtures/embedded", ["-C"]),
    ]
    with tempfile.TemporaryDirectory() as tmp:
        large = pathlib.Path(tmp) / "large.rs"
        large.write_text("fn main() {}\n" * 1234, encoding="utf-8")
        cases.append((large, ["-n", "commas"]))
        for fixture, flags in cases:
            official = run(upstream, fixture, *flags)
            port = run(binary, fixture, *flags)
            if official != port:
                raise SystemExit(
                    f"Terminal output differs from upstream for {fixture} {flags}"
                )
    print("official terminal comparison: five table cases match exactly")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=pathlib.Path,
                        help="optional official Tokei 12.1.2 executable")
    args = parser.parse_args()
    verify_language_table()
    run("moon", "check", "--target", "native", "--deny-warn")
    print("moon check: pass")
    tests = run("moon", "test", "--target", "native")
    print(tests.strip().splitlines()[-1])
    run("moon", "build", "--target", "native")
    print("moon build: pass")
    binary = binary_path()
    verify_cli(binary, 333)
    if args.upstream:
        upstream = args.upstream.resolve()
        matrix_result = run(sys.executable, ROOT / "tools/diff_matrix.py",
                            "--upstream", upstream, "--port", binary)
        print(matrix_result.strip().split(" report=", 1)[0])
        matrices = sorted((ROOT / ".scratch").glob("matrix-*"),
                          key=lambda path: path.stat().st_mtime)
        if not matrices:
            raise SystemExit("Differential matrix did not create its fixture directory")
        run(sys.executable, ROOT / "tools/compare_structured.py", "--upstream",
            upstream, "--port", binary, matrices[-1],
            ROOT / "tests/fixtures/embedded")
        print("official v12.1.2 comparison: pass")
        verify_terminal_parity(binary, upstream)
    print("release checks: pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
