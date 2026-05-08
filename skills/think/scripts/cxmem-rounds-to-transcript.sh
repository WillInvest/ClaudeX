#!/usr/bin/env bash
# Projects main CXMem round-memory files into the Codex 2nd-opinion transcript slot.
# Usage: cxmem-rounds-to-transcript.sh <sessions-root> <slug>
#
# Reads:
#   <sessions-root>/<slug>/rounds/round-*.md   main round-memory files
# Writes:
#   none
# Stdout:
#   Projected dialogue transcript, or empty output when no main rounds exist.
# Exit:
#   0 success
#   2 usage / missing dir
set -euo pipefail

[[ "$#" -eq 2 ]] || { echo "error: usage: cxmem-rounds-to-transcript.sh <sessions-root> <slug>" >&2; exit 2; }

SESSIONS_ROOT="$1"
SLUG="$2"
ROUND_DIR="$SESSIONS_ROOT/$SLUG/rounds"

[[ -d "$SESSIONS_ROOT" ]] || { echo "error: sessions root not found: $SESSIONS_ROOT" >&2; exit 2; }
[[ -d "$ROUND_DIR" ]] || exit 0

mapfile -t ROUND_FILES < <(find "$ROUND_DIR" -maxdepth 1 -type f -name 'round-*.md' ! -name '*-codex-*' -print)

python3 - "${ROUND_FILES[@]}" <<'PY'
import os
import re
import sys

paths = sys.argv[1:]

def key(path):
    name = os.path.basename(path)
    m = re.match(r"round-(\d+)(?:\D|\.md$)", name)
    return (int(m.group(1)) if m else 10**9, name)

def extract_verdict(text):
    for pattern in (
        r"(?im)^\s*(?:##\s*)?Verdict\s*:?\s*\n+(.+?)(?=^\s*##\s+|\Z)",
        r"(?im)^\s*(?:\[Codex 2nd opinion\]\s*)?(AGREE|DISAGREE|ANGLE-MISSED):\s*(.+)$",
    ):
        m = re.search(pattern, text, flags=re.DOTALL if "Verdict" in pattern else 0)
        if m:
            if len(m.groups()) == 2:
                return f"{m.group(1)}: {m.group(2).strip()}"
            return m.group(1).strip()
    return ""

def strip_sections(text):
    lines = text.splitlines()
    out = []
    skip = False
    for line in lines:
        if re.match(r"^##\s+(Index|Records|Tool details)\b", line, re.I):
            skip = True
            continue
        if skip and re.match(r"^##\s+", line):
            skip = False
        if not skip:
            out.append(line)
    return "\n".join(out).strip()

parts = []
for path in sorted(paths, key=key):
    text = open(path, encoding="utf-8").read()
    body = strip_sections(text)
    verdict = extract_verdict(text)
    block = [f"## {os.path.basename(path)}", body]
    if verdict:
        block.extend(["", f"[Codex 2nd opinion]: {verdict}"])
    parts.append("\n".join(part for part in block if part is not None).strip())

if parts:
    sys.stdout.write("\n\n".join(parts) + "\n")
PY
