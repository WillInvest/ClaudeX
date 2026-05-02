#!/usr/bin/env bash
# Appends one numbered dialogue turn to the think transcript audit.
# Usage: record-turn.sh <run-dir> <turn-number> <speaker> <content-file>
#
# Reads:
#   <run-dir>/02-transcript.md        existing transcript, checked for duplicate turn number
#   <content-file>                    markdown content for this turn
# Writes:
#   <run-dir>/02-transcript.md        appended with the new turn block
# Stdout:
#   ok: turn=<turn-number>
# Exit:
#   0 success
#   2 usage / missing-file / invalid arg / duplicate turn
#   3 unused
#   4 runtime failure
#   5 cleanup failure
# SKILL.md next-step contract: exit 0 continues; exit 2/4/5 halts for audit repair.
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "error: usage: record-turn.sh <run-dir> <turn-number> <speaker> <content-file>" >&2
  exit 2
fi

RUN_DIR="$1"
TURN_NUMBER="$2"
SPEAKER="$3"
CONTENT_FILE="$4"

[[ "$TURN_NUMBER" =~ ^[0-9]+$ ]] || { echo "error: invalid turn number: $TURN_NUMBER" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$RUN_DIR/02-transcript.md" ]] || { echo "error: transcript missing in $RUN_DIR" >&2; exit 2; }
[[ -f "$CONTENT_FILE" ]] || { echo "error: content file not found: $CONTENT_FILE" >&2; exit 2; }

if grep -Eq "^## Turn ${TURN_NUMBER}([^0-9]|$)" "$RUN_DIR/02-transcript.md"; then
  echo "error: duplicate turn: $TURN_NUMBER" >&2
  exit 2
fi

TMP="$(mktemp -t claudex-turn.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

{
  printf '## Turn %s — %s\n\n' "$TURN_NUMBER" "$SPEAKER"
  cat "$CONTENT_FILE"
  printf '\n'
} > "$TMP" || { echo "error: failed to build turn block" >&2; exit 4; }

cat "$TMP" >> "$RUN_DIR/02-transcript.md" || { echo "error: failed to append transcript" >&2; exit 4; }
echo "ok: turn=$TURN_NUMBER"
