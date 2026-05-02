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
if [[ "$usage_status" -ne 2 ]]; then
  echo "FAIL: usage error exited $usage_status, expected 2"
  exit 1
fi

for bad in missing 3 "1 2" " 1" "yes"; do
  rm -f "$TMP/.user-build-choice"
  [[ "$bad" == "missing" ]] || printf '%s\n' "$bad" > "$TMP/.user-build-choice"
  set +e
  bash "$SCRIPT" "$TMP" >"$TMP/out" 2>"$TMP/err"
  status=$?
  set -e
  if [[ "$status" -ne 3 ]]; then
    echo "FAIL: expected exit 3 for choice '$bad', got $status"
    exit 1
  fi
done

printf '1\n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_CHOICE_1" ]]

printf '2   \n' > "$TMP/.user-build-choice"
[[ "$(bash "$SCRIPT" "$TMP")" == "USER_BUILD_CHOICE_2" ]]

echo "PASS: gate-user-build-choice literal choices only"
