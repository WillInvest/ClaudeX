#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/record-decision.sh"
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

touch "$TMP/03-decisions.md"
printf 'Decision: pick A\nRationale: test\n' > "$TMP/decision.md"

bash "$SCRIPT" "$TMP" D1 "$TMP/decision.md" >/dev/null

if bash "$SCRIPT" "$TMP" D1 "$TMP/decision.md" >"$TMP/out1" 2>"$TMP/err1"; then
  echo "FAIL: duplicate decision ID was accepted"
  exit 1
fi
grep -q 'error: duplicate decision ID' "$TMP/err1"

touch "$TMP/03-decisions.frozen"
if bash "$SCRIPT" "$TMP" D2 "$TMP/decision.md" >"$TMP/out2" 2>"$TMP/err2"; then
  echo "FAIL: frozen decisions were accepted"
  exit 1
fi
grep -q 'error: decisions frozen' "$TMP/err2"

echo "PASS: record-decision duplicate and freeze refusal"
