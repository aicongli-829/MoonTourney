#!/usr/bin/env bash
# Differential test: compare TokeiMBT against upstream tokei (JSON output).
# Usage: tools/compare_tokei.sh <directory>
# Requires: tokei (cargo install tokei) and a built TokeiMBT binary.
set -euo pipefail

DIR="${1:?usage: compare_tokei.sh <directory>}"
BIN="${BIN:-_build/native/debug/build/cmd/main/main.exe}"
UPSTREAM="${UPSTREAM:-tokei}"

if ! command -v "$UPSTREAM" >/dev/null 2>&1 && [ ! -x "$UPSTREAM" ]; then
  echo "upstream tokei not found; install with: cargo install tokei" >&2
  exit 2
fi

if [ ! -x "$BIN" ]; then
  echo "TokeiMBT binary not found at $BIN; run: moon build --target native" >&2
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Upstream JSON serializes Language and its per-file Report collection.
"$UPSTREAM" "$DIR" -o json --files > "$TMP/upstream.json" 2>/dev/null || "$UPSTREAM" "$DIR" -o json > "$TMP/upstream.json"
# Ours
"$BIN" "$DIR" -o json > "$TMP/ours.json"

python3 - "$TMP/upstream.json" "$TMP/ours.json" << 'EOF'
import json, sys

def load(path):
    d = json.load(open(path))
    out = {}
    for k, v in d.items():
        if not isinstance(v, dict) or "code" not in v:
            continue
        out[k] = (len(v.get("reports", [])), v.get("code", 0),
                  v.get("comments", 0), v.get("blanks", 0))
    return out

up, ours = load(sys.argv[1]), load(sys.argv[2])
ok = True
for lang in sorted(set(up) | set(ours)):
    u, o = up.get(lang), ours.get(lang)
    if u != o:
        ok = False
        print(f"MISMATCH {lang}: upstream={u} ours={o}")
print("DIFF OK — all per-language counts agree" if ok else "DIFF FAILED")
sys.exit(0 if ok else 1)
EOF
