#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 2 ]] || { echo "error: usage: project-mission-inputs.sh <run-trail-path> <side: claude|codex>" >&2; exit 2; }

RUN_DIR="${1%/}"
SIDE="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$SIDE" in
  claude) exec bash "$SCRIPT_DIR/claude-rounds-reader.sh" "$RUN_DIR" ;;
  codex) exec bash "$SCRIPT_DIR/codex-rounds-reader.sh" "$RUN_DIR" ;;
  *) echo "error: side must be claude or codex: $SIDE" >&2; exit 2 ;;
esac
