#!/usr/bin/env bash
set -euo pipefail

if [[ "${CLAUDEX_NO_LIVE_TREE_SIDE_EFFECTS_ACTIVE:-}" == "1" ]]; then
  echo "PASS: no live tree side-effects guard skipped during nested run-all"
  exit 0
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE="${HOME}/CXMem/projects"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ -d "$LIVE" ]]; then
  find "$LIVE" -mindepth 1 -printf '%P\n' | sort > "$TMP/before"
else
  : > "$TMP/before"
fi

CLAUDEX_NO_LIVE_TREE_SIDE_EFFECTS_ACTIVE=1 bash "$TEST_DIR/run-all.sh" > "$TMP/run-all.out"

if [[ -d "$LIVE" ]]; then
  find "$LIVE" -mindepth 1 -printf '%P\n' | sort > "$TMP/after"
else
  : > "$TMP/after"
fi

comm -13 "$TMP/before" "$TMP/after" > "$TMP/new"
if [[ -s "$TMP/new" ]]; then
  echo "FAIL: build test suite created live CXMem project entries:" >&2
  cat "$TMP/new" >&2
  exit 1
fi

echo "PASS: build test suite creates no live CXMem project side effects"
