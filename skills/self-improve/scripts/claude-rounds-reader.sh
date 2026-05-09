#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 1 ]] || { echo "error: usage: claude-rounds-reader.sh <source-run-dir>" >&2; exit 2; }

RUN_DIR="${1%/}"
MISSION_ID="$(bash "$(dirname "${BASH_SOURCE[0]}")/record-mission-id.sh" "$RUN_DIR")"
run_id="${RUN_DIR##*/}"
session_dir="${RUN_DIR%/runs/$run_id}"
session_slug="${session_dir##*/}"
project_dir="${session_dir%/sessions/$session_slug}"
rounds_dir="$session_dir/rounds"

printf '# CXMEM-CLAUDE-ROUNDS v1\n'
printf '# Mission: %s\n' "$MISSION_ID"
printf '# Source: %s\n\n' "$RUN_DIR"

if [[ ! -d "$rounds_dir" ]]; then
  printf 'degraded:empty-projection\n'
  exit 0
fi

shopt -s nullglob
rounds=("$rounds_dir"/round-*.md)
filtered=()
for p in "${rounds[@]}"; do
  base="$(basename "$p")"
  case "$base" in
    round-*-codex-*.md|round-*-codex.md) ;;
    *) filtered+=("$p") ;;
  esac
done
if [[ "${#filtered[@]}" -eq 0 ]]; then
  printf 'degraded:empty-projection\n'
  exit 0
fi

for p in "${filtered[@]}"; do
  cat "$p"
  printf '\n'
done
