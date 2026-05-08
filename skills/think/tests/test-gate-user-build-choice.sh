#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/gate-user-build-choice.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set +e
bash "$SCRIPT" >"$TMP/usage-out" 2>"$TMP/usage-err"
usage_status=$?
set -e
[[ "$usage_status" -eq 2 ]] || { echo "FAIL: usage error exited $usage_status, expected 2"; exit 1; }

for bad in missing 1 2 "y n" maybe " yes"; do
  rm -f "$TMP/.user-build-choice"
  [[ "$bad" == "missing" ]] || printf '%s\n' "$bad" > "$TMP/.user-build-choice"
  set +e
  bash "$SCRIPT" "$TMP" >"$TMP/out" 2>"$TMP/err"
  status=$?
  set -e
  [[ "$status" -eq 3 ]] || { echo "FAIL: expected exit 3 for choice '$bad', got $status"; exit 1; }
done

printf 'y\n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_YES" ]]

printf 'YES   \n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_YES" ]]

printf 'n\n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_NO" ]]

printf 'No   \n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_NO" ]]

echo "PASS: gate-user-build-choice accepts yes/no only"
