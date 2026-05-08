#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 1 ]] || { echo "error: usage: codex-rounds-reader.sh <source-run-dir>" >&2; exit 2; }

RUN_DIR="${1%/}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISSION_ID="$(bash "$SCRIPT_DIR/record-mission-id.sh" "$RUN_DIR")"

printf '# CXMEM-CODEX-RECORDS v1\n'
printf '# Mission: %s\n' "$MISSION_ID"
printf '# Source: %s\n\n' "$RUN_DIR"

shopt -s nullglob
records=("$RUN_DIR"/round-*-codex-*.md "$RUN_DIR"/*/round-*-codex-*.md)
if [[ "${#records[@]}" -eq 0 ]]; then
  printf 'degraded:empty-projection\n'
  exit 0
fi

for p in "${records[@]}"; do
  first="$(head -n 1 "$p" || true)"
  if [[ "$first" =~ ^#\ CXMEM-CODEX-RECORDS\ v([0-9]+)$ && "${BASH_REMATCH[1]}" != "1" ]]; then
    printf 'degraded:unknown-codex-record-version=%s\n' "${BASH_REMATCH[1]}"
    exit 1
  fi
  cat "$p"
  printf '\n'
done
