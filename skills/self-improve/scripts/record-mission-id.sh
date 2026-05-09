#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 1 ]] || { echo "error: usage: record-mission-id.sh <source-run-dir>" >&2; exit 2; }

RUN_DIR="${1%/}"
case "$RUN_DIR" in
  */projects/*/sessions/*/runs/*) ;;
  *) echo "error: malformed source run path: $1" >&2; exit 2 ;;
esac

run_id="${RUN_DIR##*/}"
parent="${RUN_DIR%/runs/$run_id}"
session_slug="${parent##*/sessions/}"
session_slug="${session_slug%%/*}"

[[ -n "$session_slug" && -n "$run_id" && "$session_slug" != "$parent" ]] || {
  echo "error: malformed source run path: $1" >&2
  exit 2
}

printf '%s__%s\n' "$session_slug" "$run_id"
