#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/freeze-decisions.sh"
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
bash "$SCRIPT" "$TMP" >/dev/null
[[ -f "$TMP/03-decisions.frozen" ]]

bash "$SCRIPT" "$TMP" >/dev/null
[[ -f "$TMP/03-decisions.frozen" ]]

echo "PASS: freeze-decisions marker creation and idempotent retry"
