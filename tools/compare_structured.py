#!/usr/bin/env python3
"""Compare complete JSON reports from the port and an upstream Tokei binary.

This checks nested blobs and child reports, unlike the basic language matrix.
The only normalization is Windows versus POSIX separators in report paths.
"""

import argparse
import json
import pathlib
import subprocess
import sys


def run(binary: pathlib.Path, fixture: pathlib.Path) -> dict:
    result = subprocess.run(
        [str(binary), "-o", "json", str(fixture)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return json.loads(result.stdout)


def normalize(value):
    if isinstance(value, dict):
        return {
            key: normalize(entry).replace("\\", "/")
            if key == "name" and isinstance(entry, str)
            else normalize(entry)
            for key, entry in value.items()
        }
    if isinstance(value, list):
        entries = [normalize(entry) for entry in value]
        if entries and all(isinstance(entry, dict) and "name" in entry for entry in entries):
            return sorted(entries, key=lambda entry: entry["name"])
        return entries
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, type=pathlib.Path)
    parser.add_argument("--port", required=True, type=pathlib.Path)
    parser.add_argument("fixture", nargs="+", type=pathlib.Path)
    args = parser.parse_args()
    failed = False
    for fixture in args.fixture:
        official = normalize(run(args.upstream.resolve(), fixture))
        port = normalize(run(args.port.resolve(), fixture))
        if official == port:
            print(f"MATCH {fixture}")
        else:
            failed = True
            print(f"DIFF {fixture}")
            print("upstream:", json.dumps(official, indent=2, ensure_ascii=False))
            print("port:", json.dumps(port, indent=2, ensure_ascii=False))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
