#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 6 ]] || { echo "error: usage: dispatch-auditor-codex.sh <run-dir> <mission-id> <seq> <projection-file> <proposal-file> <auditor-side>" >&2; exit 2; }

RUN_DIR="$1"
MISSION_ID="$2"
SEQ="$3"
PROJECTION="$4"
PROPOSAL="$5"
AUDITOR_SIDE="$6"

[[ -d "$RUN_DIR" ]] || { echo "error: run dir missing: $RUN_DIR" >&2; exit 2; }
[[ -f "$PROJECTION" ]] || { echo "error: projection file missing: $PROJECTION" >&2; exit 2; }
[[ -f "$PROPOSAL" ]] || { echo "error: proposal file missing: $PROPOSAL" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TEMPLATE="$ROOT/skills/self-improve/auditor-prompt.md"
[[ -f "$TEMPLATE" ]] || { echo "error: auditor template missing: $TEMPLATE" >&2; exit 2; }

RAW="$RUN_DIR/.last-codex-audit-$MISSION_ID-$SEQ.raw"
ERR="$RUN_DIR/.last-codex-audit-$MISSION_ID-$SEQ.err"
TMP_PROMPT="$(mktemp)"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_PROMPT" "$TMP_OUT"' EXIT
RECORDING_RULE_BLOCK=""
if [[ "${CXMEM_HOST_STATE:-}" == "CXMEM_HOST_PROJECT_READY" ]]; then
  RECORDING_RULE_PATH="$ROOT/skills/build/prompts/cxmem-recording-rule-block.md"
  [[ -f "$RECORDING_RULE_PATH" ]] || { echo "error: recording rule missing: $RECORDING_RULE_PATH" >&2; exit 2; }
  RECORDING_RULE_BLOCK="$(cat "$RECORDING_RULE_PATH")"
fi

python3 - "$TEMPLATE" "$PROJECTION" "$PROPOSAL" "$MISSION_ID" "$AUDITOR_SIDE" "$RECORDING_RULE_BLOCK" > "$TMP_PROMPT" <<'PY'
import sys
template, projection, proposal, mission_id, auditor_side, recording = sys.argv[1:]
def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()
text = read(template)
text = text.replace("{{mission_id}}", mission_id)
text = text.replace("{{AUDITOR_SIDE}}", auditor_side)
text = text.replace("{{MISSION_PROJECTION}}", read(projection))
text = text.replace("{{PROPOSAL_RECORD}}", read(proposal))
text = text.replace("{{recording_rule_block}}", recording)
sys.stdout.write(text)
PY

if [[ -n "${CLAUDEX_SI_STUB_AUDITOR_OUTPUT:-}" ]]; then
  [[ -r "$CLAUDEX_SI_STUB_AUDITOR_OUTPUT" ]] || { echo "error: unreadable stub output file: $CLAUDEX_SI_STUB_AUDITOR_OUTPUT" >&2; exit 2; }
  {
    printf 'user\n'
    cat "$TMP_PROMPT"
    printf '\ncodex\n'
    cat "$CLAUDEX_SI_STUB_AUDITOR_OUTPUT"
    printf '\n'
  } > "$RAW"
  cat "$CLAUDEX_SI_STUB_AUDITOR_OUTPUT"
  exit 0
fi

if ! command -v codex >/dev/null; then
  echo "error: codex CLI not on PATH; orchestrator should fall back to Agent dispatch" >&2
  exit 3
fi

if ! codex exec --sandbox read-only --skip-git-repo-check -C "$RUN_DIR" - < "$TMP_PROMPT" > "$TMP_OUT" 2> "$ERR"; then
  {
    printf 'user\n'
    cat "$TMP_PROMPT"
    printf '\n'
    cat "$TMP_OUT"
  } > "$RAW"
  echo "error: codex exec failed" >&2
  tail -50 "$ERR" >&2
  exit 4
fi

{
  printf 'user\n'
  cat "$TMP_PROMPT"
  printf '\n'
  cat "$TMP_OUT"
} > "$RAW"

python3 - "$RAW" <<'PY'
import re, sys
raw = open(sys.argv[1], "r", encoding="utf-8").read()
m = re.search(r"(?m)^codex\s*\n", raw)
body = raw[m.end():] if m else raw
body = re.split(r"\ntokens used\s*\n", body, maxsplit=1)[0]
sys.stdout.write(body.rstrip() + "\n")
PY
