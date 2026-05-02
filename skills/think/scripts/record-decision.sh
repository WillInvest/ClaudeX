#!/usr/bin/env bash
# Appends one decision to the think decisions audit.
# Usage: record-decision.sh <run-dir> <decision-id> <decision-file>
#
# Reads:
#   <run-dir>/03-decisions.md         existing decisions log, checked for duplicate decision ID
#   <run-dir>/03-decisions.frozen     if present, decisions are closed and append is refused
#   <decision-file>                   markdown decision body
# Writes:
#   <run-dir>/03-decisions.md         appended with the new decision block
# Stdout:
#   ok: decision=<decision-id>
# Exit:
#   0 success
#   2 usage / missing-file / invalid arg / duplicate decision / decisions frozen
#   3 unused
#   4 runtime failure
#   5 cleanup failure
# SKILL.md next-step contract: exit 0 continues; exit 2/4/5 halts for audit repair.
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "error: usage: record-decision.sh <run-dir> <decision-id> <decision-file>" >&2
  exit 2
fi

RUN_DIR="$1"
DECISION_ID="$2"
DECISION_FILE="$3"

[[ "$DECISION_ID" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: invalid decision id: $DECISION_ID" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]] || { echo "error: decisions missing in $RUN_DIR" >&2; exit 2; }
[[ -f "$DECISION_FILE" ]] || { echo "error: decision file not found: $DECISION_FILE" >&2; exit 2; }

if [[ -f "$RUN_DIR/03-decisions.frozen" ]]; then
  echo "error: decisions frozen" >&2
  exit 2
fi

if grep -Fqx "Decision ID: $DECISION_ID" "$RUN_DIR/03-decisions.md"; then
  echo "error: duplicate decision ID: $DECISION_ID" >&2
  exit 2
fi

TMP="$(mktemp -t claudex-decision.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

{
  printf '## Decision %s\n\n' "$DECISION_ID"
  printf 'Decision ID: %s\n\n' "$DECISION_ID"
  cat "$DECISION_FILE"
  printf '\n'
} > "$TMP" || { echo "error: failed to build decision block" >&2; exit 4; }

cat "$TMP" >> "$RUN_DIR/03-decisions.md" || { echo "error: failed to append decisions" >&2; exit 4; }
echo "ok: decision=$DECISION_ID"
