#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/gate-design-approval.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set +e
bash "$SCRIPT" >"$TMP/usage-out" 2>"$TMP/usage-err"
usage_status=$?
set -e
if [[ "$usage_status" -ne 2 ]]; then
  echo "FAIL: usage error exited $usage_status, expected 2"
  exit 1
fi

set +e
bash "$SCRIPT" "$TMP" >"$TMP/out" 2>"$TMP/err"
status=$?
set -e

if [[ "$status" -ne 3 ]]; then
  echo "FAIL: expected exit 3 for missing design marker, got $status"
  exit 1
fi
grep -q 'error: design not approved' "$TMP/err"

touch "$TMP/.design-approved"
[[ "$(bash "$SCRIPT" "$TMP")" == "DESIGN_APPROVED" ]]

echo "PASS: gate-design-approval refusal and success"
