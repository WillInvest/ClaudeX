#!/usr/bin/env bash
# Builds the Opus reviewer prompt for a spec round and writes it to a file.
# The orchestrator then dispatches the Agent tool with the prompt body.
#
# This script is the mechanical half of opus spec review — slot filling.
# The Agent invocation itself remains Claude-Code-tool-only (cannot be a
# shell call), but every byte of the prompt body comes from this script.
#
# Usage: build-opus-spec-review-prompt.sh <run-dir> <round> <approaches-file>
#   round: 1 | 2
#
# Reads:
#   <run-dir>/03-decisions.md
#   <run-dir>/04-design.md
#   <approaches-file>                       typically <run-dir>/05-approaches.md
#   <run-dir>/06-spec-r1.clean.md           (round 1) OR
#   <run-dir>/08-spec-r2.clean.md           (round 2)
#   ../reviewer-prompt.md                   template, slots: stage/source_document/artifact
#
# Writes:
#   <run-dir>/07-spec-r1-review-prompt.md   (round 1) OR
#   <run-dir>/09-spec-r2-review-prompt.md   (round 2)
#
# Stdout:
#   The full path of the written prompt file.
#
# Exit:
#   0 success
#   2 usage / missing-file
set -euo pipefail

RUN_DIR="${1:?usage: build-opus-spec-review-prompt.sh <run-dir> <round> <approaches-file>}"
ROUND="${2:?usage: missing <round> (1|2)}"
APPROACHES_FILE="${3:?usage: missing <approaches-file>}"

case "$ROUND" in
  1) SPEC="$RUN_DIR/06-spec-r1.clean.md"; OUT="$RUN_DIR/07-spec-r1-review-prompt.md" ;;
  2) SPEC="$RUN_DIR/08-spec-r2.clean.md"; OUT="$RUN_DIR/09-spec-r2-review-prompt.md" ;;
  *) echo "error: round must be 1 or 2 — got '$ROUND'" >&2; exit 2 ;;
esac

[[ -d "$RUN_DIR" ]]                              || { echo "error: run dir not found: $RUN_DIR" >&2;       exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]]              || { echo "error: decisions missing" >&2;                 exit 2; }
[[ -f "$RUN_DIR/04-design.md" ]]                 || { echo "error: design missing" >&2;                    exit 2; }
[[ -f "$APPROACHES_FILE" ]]                      || { echo "error: approaches not found: $APPROACHES_FILE" >&2; exit 2; }
[[ -f "$SPEC" ]]                                 || { echo "error: spec not found: $SPEC" >&2;             exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../reviewer-prompt.md"
[[ -f "$TEMPLATE" ]]                             || { echo "error: template missing: $TEMPLATE" >&2;       exit 2; }

python3 - "$TEMPLATE" "$RUN_DIR/03-decisions.md" "$RUN_DIR/04-design.md" "$APPROACHES_FILE" "$SPEC" > "$OUT" <<'PY'
import sys
template, d_path, des_path, a_path, s_path = sys.argv[1:]
def read(p):
    with open(p, 'r', encoding='utf-8') as f:
        return f.read()
source = "\n\n".join([
    "# APPROVED DESIGN",
    read(des_path),
    "# FROZEN DECISIONS",
    read(d_path),
    "# APPROACHES",
    read(a_path),
])
text = read(template)
text = text.replace('{{stage}}', "spec")
text = text.replace('{{source_document}}', source)
text = text.replace('{{artifact}}', read(s_path))
sys.stdout.write(text)
PY

echo "$OUT"
