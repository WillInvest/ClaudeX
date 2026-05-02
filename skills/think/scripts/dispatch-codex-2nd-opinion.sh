#!/usr/bin/env bash
# Dispatches Codex for a per-recommendation 2nd opinion.
# Usage: dispatch-codex-2nd-opinion.sh <run-dir> <question-file> <recommendation-file>
#
# Reads:
#   <run-dir>/02-transcript.md       full transcript to date
#   <run-dir>/03-decisions.md        decisions log
#   <question-file>                  the question Claude plans to ask (markdown text)
#   <recommendation-file>            Claude's recommendation (markdown text)
#   ../second-opinion-prompt.md      template, slots: TRANSCRIPT/DECISIONS/QUESTION/RECOMMENDATION
#
# Writes:
#   <run-dir>/.last-2nd-opinion.raw  full codex output (for audit/debug)
#
# Stdout:
#   One verdict line: AGREE: ... | DISAGREE: ... | ANGLE-MISSED: ...
#
# Exit:
#   0 verdict captured
#   2 usage / missing-file error
#   3 codex CLI not on PATH (caller falls back to Claude subagent)
#   4 codex exec failed (caller decides — retry or fallback)
#   5 codex output did not contain a recognizable verdict line
set -euo pipefail

RUN_DIR="${1:?usage: dispatch-codex-2nd-opinion.sh <run-dir> <question-file> <recommendation-file>}"
QUESTION_FILE="${2:?usage: missing <question-file>}"
RECOMMENDATION_FILE="${3:?usage: missing <recommendation-file>}"

[[ -d "$RUN_DIR" ]]                                 || { echo "error: run dir not found: $RUN_DIR" >&2;            exit 2; }
[[ -f "$RUN_DIR/02-transcript.md" ]]                || { echo "error: transcript missing in $RUN_DIR" >&2;         exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]]                 || { echo "error: decisions missing in $RUN_DIR" >&2;          exit 2; }
[[ -f "$QUESTION_FILE" ]]                           || { echo "error: question file not found: $QUESTION_FILE" >&2; exit 2; }
[[ -f "$RECOMMENDATION_FILE" ]]                     || { echo "error: recommendation file not found: $RECOMMENDATION_FILE" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../second-opinion-prompt.md"
[[ -f "$TEMPLATE" ]]                                || { echo "error: template missing: $TEMPLATE" >&2;            exit 2; }

# Build prompt via python (handles multi-line slot content cleanly).
PROMPT_FILE="$(mktemp -t codex-2nd-opinion-prompt.XXXXXX)"
RAW_OUT="$RUN_DIR/.last-2nd-opinion.raw"
trap 'rm -f "$PROMPT_FILE"' EXIT

python3 - "$TEMPLATE" "$RUN_DIR/02-transcript.md" "$RUN_DIR/03-decisions.md" "$QUESTION_FILE" "$RECOMMENDATION_FILE" > "$PROMPT_FILE" <<'PY'
import sys
template, t_path, d_path, q_path, r_path = sys.argv[1:]
def read(p):
    with open(p, 'r', encoding='utf-8') as f:
        return f.read()
text = read(template)
text = text.replace('{{TRANSCRIPT}}',     read(t_path))
text = text.replace('{{DECISIONS}}',      read(d_path))
text = text.replace('{{QUESTION}}',       read(q_path))
text = text.replace('{{RECOMMENDATION}}', read(r_path))
sys.stdout.write(text)
PY

if ! command -v codex >/dev/null; then
  echo "error: codex CLI not on PATH; orchestrator should fall back to Agent dispatch" >&2
  exit 3
fi

if ! codex exec --sandbox read-only --skip-git-repo-check - < "$PROMPT_FILE" > "$RAW_OUT" 2>&1; then
  echo "error: codex exec failed" >&2
  tail -50 "$RAW_OUT" >&2
  exit 4
fi

# Verdict line is one of AGREE/DISAGREE/ANGLE-MISSED. Take the last match
# (codex sometimes echoes the prompt back inside its banner).
VERDICT="$(grep -E '^(AGREE|DISAGREE|ANGLE-MISSED):' "$RAW_OUT" | tail -n 1 || true)"

if [[ -z "$VERDICT" ]]; then
  echo "error: codex output did not contain a verdict line (AGREE/DISAGREE/ANGLE-MISSED)" >&2
  echo "--- raw output (tail) ---" >&2
  tail -50 "$RAW_OUT" >&2
  exit 5
fi

echo "$VERDICT"
