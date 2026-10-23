#!/usr/bin/env python3
"""Compare basic per-language fixtures with a real upstream Tokei binary.

Only definitions identical in the pinned v15 snapshot and the selected older
reference snapshot are included. This prevents language-table version changes
from being reported as scanner defects. Generated inputs remain under .scratch.
"""

import argparse
import collections
import json
import pathlib
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
V15 = ROOT / "vendor/tokei-v15.0.0/languages.json"


def run(binary, fixture):
    result = subprocess.run(
        [str(binary), "-o", "json", str(fixture)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return json.loads(result.stdout)


def reports(data):
    found = {}
    for language, value in data.items():
        if language == "Total":
            continue
        for report in value.get("reports", []):
            path = report["name"].replace("\\", "/")
            stats = report["stats"]
            found[path] = (language, stats["code"], stats["comments"], stats["blanks"])
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", required=True, type=pathlib.Path)
    parser.add_argument("--port", type=pathlib.Path,
                        default=ROOT / "_build/native/debug/build/cmd/main/main.exe")
    parser.add_argument("--reference-data", type=pathlib.Path,
                        default=ROOT / "vendor/tokei-v12.1.2/languages.json")
    parser.add_argument("--limit", type=int, default=0,
                        help="0 tests every eligible language")
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    port = args.port.resolve()
    reference = json.loads(args.reference_data.read_text(encoding="utf-8"))["languages"]
    current = json.loads(V15.read_text(encoding="utf-8"))["languages"]
    extension_owners = collections.defaultdict(set)
    for key, definition in current.items():
        for extension in definition.get("extensions", []):
            extension_owners[extension.lower()].add(key)
    for key, definition in reference.items():
        for extension in definition.get("extensions", []):
            extension_owners[extension.lower()].add(key)

    eligible = []
    for key in sorted(set(current) & set(reference)):
        if current[key] != reference[key]:
            continue
        extensions = [extension for extension in current[key].get("extensions", [])
                      if len(extension_owners[extension.lower()]) == 1
                      and extension.isalnum()]
        if extensions:
            eligible.append((key, extensions[0]))
    if args.limit:
        eligible = eligible[:args.limit]

    scratch = ROOT / ".scratch"
    scratch.mkdir(exist_ok=True)
    fixture = pathlib.Path(tempfile.mkdtemp(prefix="matrix-", dir=scratch))
    manifest = {}
    for index, (key, extension) in enumerate(eligible):
        folder = fixture / f"case-{index:03d}"
        folder.mkdir()
        code = folder / f"code.{extension}"
        code.write_text("sample\n", encoding="utf-8", newline="\n")
        manifest[str(code).replace("\\", "/")] = key
        no_final_newline = folder / f"no_final_newline.{extension}"
        no_final_newline.write_text("sample", encoding="utf-8", newline="\n")
        manifest[str(no_final_newline).replace("\\", "/")] = key
        crlf = folder / f"crlf.{extension}"
        crlf.write_bytes(b"sample\r\n\r\n")
        manifest[str(crlf).replace("\\", "/")] = key
        bom = folder / f"utf8_bom.{extension}"
        bom.write_bytes(b"\xef\xbb\xbfsample\n")
        manifest[str(bom).replace("\\", "/")] = key
        definition = current[key]
        env = definition.get("env", [])
        if env:
            shebang = folder / f"shebang.{extension}"
            shebang.write_text(
                "#!/usr/bin/env " + env[0] + "\nsample\n",
                encoding="utf-8", newline="\n",
            )
            manifest[str(shebang).replace("\\", "/")] = key
        comments = definition.get("line_comment", [])
        if comments:
            comment = folder / f"comment.{extension}"
            marker = comments[0].replace('\\"', '"')
            comment.write_text(marker + " sample\n", encoding="utf-8", newline="\n")
            manifest[str(comment).replace("\\", "/")] = key
            quotes = definition.get("quotes", [])
            if quotes:
                opening, closing = (part.replace('\\"', '"') for part in quotes[0])
                quoted = folder / f"quoted.{extension}"
                quoted.write_text(
                    opening + " " + marker + " still text " + closing + "\n",
                    encoding="utf-8", newline="\n",
                )
                manifest[str(quoted).replace("\\", "/")] = key
                multi = folder / f"multiline_quote.{extension}"
                multi.write_text(
                    opening + " start\n" + marker + " still text\n" + closing + "\n",
                    encoding="utf-8", newline="\n",
                )
                manifest[str(multi).replace("\\", "/")] = key
        blocks = definition.get("multi_line_comments", [])
        if blocks:
            opening, closing = (part.replace('\\"', '"') for part in blocks[0])
            block = folder / f"block.{extension}"
            block.write_text(
                opening + "\ninside comment\n" + closing + "\n",
                encoding="utf-8", newline="\n",
            )
            manifest[str(block).replace("\\", "/")] = key
            if definition.get("nested"):
                nested = folder / f"nested_block.{extension}"
                nested.write_text(
                    opening + " outer\n" + opening + " inner " + closing
                    + "\nstill outer " + closing + "\n",
                    encoding="utf-8", newline="\n",
                )
                manifest[str(nested).replace("\\", "/")] = key

    official = reports(run(upstream, fixture))
    moonbit = reports(run(port, fixture))
    mismatches = []
    for path in sorted(set(official) | set(moonbit)):
        if official.get(path) != moonbit.get(path):
            mismatches.append({
                "path": path,
                "definition": manifest.get(path),
                "upstream": official.get(path),
                "port": moonbit.get(path),
            })
    report = {
        "eligible_languages": len(eligible),
        "fixture_files": len(manifest),
        "matched_files": len(set(official) & set(moonbit)) - sum(
            1 for item in mismatches if item["upstream"] and item["port"]
        ),
        "mismatches": mismatches,
    }
    report_path = scratch / "matrix-report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"languages={len(eligible)} files={len(manifest)} "
          f"mismatches={len(mismatches)} report={report_path}")
    for item in mismatches[:20]:
        print(f"  {item['definition']}: {item['upstream']} != {item['port']}")
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
