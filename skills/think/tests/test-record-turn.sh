#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/record-turn.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set +e
bash "$SCRIPT" >"$TMP/usage-out" 2>"$TMP/usage-err"
status=$?
set -e
if [[ "$status" -ne 2 ]]; then
  echo "FAIL: usage error exited $status, expected 2"
  exit 1
fi

touch "$TMP/02-transcript.md"
printf 'hello\n' > "$TMP/turn.md"

bash "$SCRIPT" "$TMP" 1 Claude "$TMP/turn.md" >/dev/null

if bash "$SCRIPT" "$TMP" 1 User "$TMP/turn.md" >"$TMP/out" 2>"$TMP/err"; then
  echo "FAIL: duplicate turn was accepted"
  exit 1
fi

grep -q 'error: duplicate turn' "$TMP/err"
echo "PASS: record-turn duplicate refusal"
