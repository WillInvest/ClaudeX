#!/usr/bin/env bash
# Marks the decisions audit frozen before spec writing.
# Usage: freeze-decisions.sh <run-dir>
#
# Reads:
#   <run-dir>/03-decisions.md         decisions log that is being frozen
#   <run-dir>/03-decisions.frozen     existing marker; re-freeze exits 0 quietly
# Writes:
#   <run-dir>/03-decisions.frozen     freeze marker, created idempotently
# Stdout:
#   ok: frozen
# Exit:
#   0 success, including already-frozen retry
#   2 usage / missing-file
#   3 unused
#   4 runtime failure
#   5 cleanup failure
# SKILL.md next-step contract: exit 0 permits Stage 4 spec dispatch; exit 2/4/5 halts.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "error: usage: freeze-decisions.sh <run-dir>" >&2
  exit 2
fi

RUN_DIR="$1"

[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]] || { echo "error: decisions missing in $RUN_DIR" >&2; exit 2; }

if [[ -f "$RUN_DIR/03-decisions.frozen" ]]; then
  exit 0
fi

printf 'frozen\n' > "$RUN_DIR/03-decisions.frozen" || { echo "error: failed to create freeze marker" >&2; exit 4; }
echo "ok: frozen"
