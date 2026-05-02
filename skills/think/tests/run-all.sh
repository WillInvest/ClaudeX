#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0

for test_file in "$TEST_DIR"/test-*.sh; do
  name="$(basename "$test_file")"
  if bash "$test_file"; then
    printf 'ok: %s\n' "$name"
  else
    printf 'not ok: %s\n' "$name"
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -ne 0 ]]; then
  printf 'FAIL: %s test(s) failed\n' "$failures"
  exit 1
fi

echo "PASS: all think script tests passed"
