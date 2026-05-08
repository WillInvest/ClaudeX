#!/usr/bin/env bash
# Appends one decision to the think decisions audit.
# Usage: record-decision.sh <run-dir> <decision-id> <decision-file> [--decided-by <auto|user>] [--foldability <folded|structural|n/a>] [--high-blast <yes|no|ambiguous-halted>]
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

if [[ "$#" -lt 3 ]]; then
  echo "error: usage: record-decision.sh <run-dir> <decision-id> <decision-file> [--decided-by <auto|user>] [--foldability <folded|structural|n/a>] [--high-blast <yes|no|ambiguous-halted>]" >&2
  exit 2
fi

RUN_DIR="$1"
DECISION_ID="$2"
DECISION_FILE="$3"
shift 3

DECIDED_BY=""
FOLDABILITY=""
HIGH_BLAST=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --decided-by)
      [[ "$#" -ge 2 ]] || { echo "error: missing value for --decided-by" >&2; exit 2; }
      DECIDED_BY="$2"
      shift 2
      ;;
    --foldability)
      [[ "$#" -ge 2 ]] || { echo "error: missing value for --foldability" >&2; exit 2; }
      FOLDABILITY="$2"
      shift 2
      ;;
    --high-blast)
      [[ "$#" -ge 2 ]] || { echo "error: missing value for --high-blast" >&2; exit 2; }
      HIGH_BLAST="$2"
      shift 2
      ;;
    *)
      echo "error: invalid arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ "$DECISION_ID" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "error: invalid decision id: $DECISION_ID" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]] || { echo "error: decisions missing in $RUN_DIR" >&2; exit 2; }
[[ -f "$DECISION_FILE" ]] || { echo "error: decision file not found: $DECISION_FILE" >&2; exit 2; }
if [[ -n "$DECIDED_BY$FOLDABILITY$HIGH_BLAST" && ( -z "$DECIDED_BY" || -z "$FOLDABILITY" || -z "$HIGH_BLAST" ) ]]; then
  echo "error: --decided-by, --foldability, and --high-blast must be supplied together" >&2
  exit 2
fi
[[ -z "$DECIDED_BY" || "$DECIDED_BY" =~ ^(auto|user)$ ]] || { echo "error: invalid --decided-by: $DECIDED_BY" >&2; exit 2; }
[[ -z "$FOLDABILITY" || "$FOLDABILITY" =~ ^(folded|structural|n/a)$ ]] || { echo "error: invalid --foldability: $FOLDABILITY" >&2; exit 2; }
[[ -z "$HIGH_BLAST" || "$HIGH_BLAST" =~ ^(yes|no|ambiguous-halted)$ ]] || { echo "error: invalid --high-blast: $HIGH_BLAST" >&2; exit 2; }

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
  if [[ -n "$DECIDED_BY" || -n "$FOLDABILITY" || -n "$HIGH_BLAST" ]]; then
    printf '\n'
    [[ -n "$DECIDED_BY" ]] && printf 'Decided-by: %s\n' "$DECIDED_BY"
    [[ -n "$FOLDABILITY" ]] && printf 'Foldability: %s\n' "$FOLDABILITY"
    [[ -n "$HIGH_BLAST" ]] && printf 'High-blast: %s\n' "$HIGH_BLAST"
  fi
  printf '\n'
} > "$TMP" || { echo "error: failed to build decision block" >&2; exit 4; }

cat "$TMP" >> "$RUN_DIR/03-decisions.md" || { echo "error: failed to append decisions" >&2; exit 4; }
echo "ok: decision=$DECISION_ID"
