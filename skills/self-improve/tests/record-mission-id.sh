#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/CXMem/projects/p/sessions/source-slug/runs/run-42"
mkdir -p "$RUN"

out="$(bash "$ROOT/skills/self-improve/scripts/record-mission-id.sh" "$RUN")"
[[ "$out" == "source-slug__run-42" ]] || { echo "FAIL: wrong mission id: $out"; exit 1; }

if bash "$ROOT/skills/self-improve/scripts/record-mission-id.sh" "$TMP/not-a-run" >/dev/null 2>&1; then
  echo "FAIL: malformed path accepted"
  exit 1
fi

echo "PASS: record mission id"
