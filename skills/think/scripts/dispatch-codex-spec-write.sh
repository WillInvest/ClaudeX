#!/usr/bin/env bash
# Dispatches Codex to write the brainstorm spec for a given round.
# Usage: dispatch-codex-spec-write.sh <run-dir> <round> <design-file> <approaches-file> <canonical-spec-path>
#   round: 1 | 2 | fix1 | fix2
#
# Reads:
#   <run-dir>/02-transcript.md
#   <run-dir>/03-decisions.md      (FROZEN at this point)
#   <approaches-file>              typically <run-dir>/05-approaches.md
#   <design-file>                  the agreed design markdown
#   ../spec-codex-prompt.md        template, slots: TRANSCRIPT/DECISIONS/APPROACHES/DESIGN
#
# Writes:
#   <run-dir>/spec-prompt-r<round>.md   filled prompt
#   <run-dir>/06-spec-r1.md             round 1 raw
#   <run-dir>/06-spec-r1.clean.md       round 1 cleaned (no banner / no token-footer)
#   <run-dir>/06-spec-r1-fix.md         fix1 variant
#   <run-dir>/06-spec-r1-fix.clean.md
#   <run-dir>/08-spec-r2.md             round 2
#   <run-dir>/08-spec-r2.clean.md
#   <run-dir>/08-spec-r2-fix.md         fix2
#   <run-dir>/08-spec-r2-fix.clean.md
#   <canonical-spec-path>               overwritten via cp from the round's clean output
#
# Exit:
#   0 success — clean spec at <canonical-spec-path>
#   2 usage / missing-file
#   3 codex returned WRONG-DIRECTION (orchestrator MUST escalate; non-blocking exit)
#   4 codex CLI missing OR codex exec failed
#   5 cleanup failed (no markdown body found)
#   6 decisions-preamble byte-match against 03-decisions.md FAILED (DRIFT — re-dispatch or escalate)
set -euo pipefail

RUN_DIR="${1:?usage: dispatch-codex-spec-write.sh <run-dir> <round> <design-file> <approaches-file> <canonical-spec-path>}"
ROUND="${2:?usage: missing <round> (1|2|fix1|fix2)}"
DESIGN_FILE="${3:?usage: missing <design-file>}"
APPROACHES_FILE="${4:?usage: missing <approaches-file>}"
CANONICAL_PATH="${5:?usage: missing <canonical-spec-path>}"

case "$ROUND" in
  1)    RAW="$RUN_DIR/06-spec-r1.md";     CLEAN="$RUN_DIR/06-spec-r1.clean.md";     RESUME="" ;;
  fix1) RAW="$RUN_DIR/06-spec-r1-fix.md"; CLEAN="$RUN_DIR/06-spec-r1-fix.clean.md"; RESUME="--last" ;;
  2)    RAW="$RUN_DIR/08-spec-r2.md";     CLEAN="$RUN_DIR/08-spec-r2.clean.md";     RESUME="--last" ;;
  fix2) RAW="$RUN_DIR/08-spec-r2-fix.md"; CLEAN="$RUN_DIR/08-spec-r2-fix.clean.md"; RESUME="--last" ;;
  *)    echo "error: round must be 1, 2, fix1, or fix2 — got '$ROUND'" >&2;          exit 2 ;;
esac

[[ -d "$RUN_DIR" ]]                              || { echo "error: run dir not found: $RUN_DIR" >&2;       exit 2; }
[[ -f "$RUN_DIR/02-transcript.md" ]]             || { echo "error: transcript missing" >&2;                exit 2; }
[[ -f "$RUN_DIR/03-decisions.md" ]]              || { echo "error: decisions missing" >&2;                 exit 2; }
[[ -f "$APPROACHES_FILE" ]]                      || { echo "error: approaches not found: $APPROACHES_FILE" >&2; exit 2; }
[[ -f "$DESIGN_FILE" ]]                          || { echo "error: design not found: $DESIGN_FILE" >&2;    exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../spec-codex-prompt.md"
[[ -f "$TEMPLATE" ]]                             || { echo "error: template missing: $TEMPLATE" >&2;       exit 2; }

# Build the round prompt via python.
PROMPT_FILE="$RUN_DIR/spec-prompt-r${ROUND}.md"
python3 - "$TEMPLATE" "$RUN_DIR/02-transcript.md" "$RUN_DIR/03-decisions.md" "$APPROACHES_FILE" "$DESIGN_FILE" > "$PROMPT_FILE" <<'PY'
import sys
template, t_path, d_path, a_path, des_path = sys.argv[1:]
def read(p):
    with open(p, 'r', encoding='utf-8') as f:
        return f.read()
text = read(template)
text = text.replace('{{TRANSCRIPT}}',  read(t_path))
text = text.replace('{{DECISIONS}}',   read(d_path))
text = text.replace('{{APPROACHES}}',  read(a_path))
text = text.replace('{{DESIGN}}',      read(des_path))
sys.stdout.write(text)
PY

if ! command -v codex >/dev/null; then
  echo "error: codex CLI not on PATH" >&2
  exit 4
fi

# Run codex.
if [[ -n "$RESUME" ]]; then
  # `codex exec resume` does not accept -C/--sandbox; cd into RUN_DIR in subshell.
  ( cd "$RUN_DIR" && codex exec resume "$RESUME" --skip-git-repo-check - < "$PROMPT_FILE" > "$RAW" 2>&1 ) || {
    echo "error: codex exec resume failed" >&2
    tail -50 "$RAW" >&2
    exit 4
  }
else
  codex exec --sandbox read-only --skip-git-repo-check -C "$RUN_DIR" - < "$PROMPT_FILE" > "$RAW" 2>&1 || {
    echo "error: codex exec failed" >&2
    tail -50 "$RAW" >&2
    exit 4
  }
fi

# Detect WRONG-DIRECTION (Codex's contract: entire first non-banner line of body).
if grep -q '^WRONG-DIRECTION:' "$RAW"; then
  echo "wrong-direction:" >&2
  grep '^WRONG-DIRECTION:' "$RAW" | head -1 >&2
  exit 3
fi

# Clean wrapper noise: take from first markdown H1 to before the "tokens used" footer,
# then SPLICE the verbatim 03-decisions.md content into ## Decisions preamble.
# Splicing (not asking codex to copy) makes the byte-match guaranteed by construction.
if ! python3 - "$RAW" "$RUN_DIR/03-decisions.md" > "$CLEAN" <<'PY'
import sys, re
raw_path, decisions_path = sys.argv[1:]
text = open(raw_path, 'r', encoding='utf-8').read()
# codex CLI output shape: [banner] '\nuser\n' [echoed prompt] '\ncodex\n' [reply] '\ntokens used\n' [...]
# Anchor to the assistant's reply section first; otherwise '^# ' matches the echoed prompt.
m = re.search(r'(?m)^codex\s*\n', text)
if not m:
    sys.stderr.write("error: 'codex' marker not found in output (no assistant reply section)\n")
    sys.exit(1)
reply = text[m.end():]
m2 = re.search(r'(?m)^# ', reply)
if not m2:
    sys.stderr.write("error: no '# ' header found in codex assistant reply\n")
    sys.exit(1)
body = reply[m2.start():]
body = re.split(r'\ntokens used\s*\n', body, maxsplit=1)[0].rstrip() + '\n'

decisions = open(decisions_path, 'r', encoding='utf-8').read().strip()

# Replace the (presumably empty) Decisions preamble section with the verbatim
# decisions content. The codex prompt instructs codex to leave this section
# empty; the splice happens here regardless.
def replace_preamble(spec_text, decisions_text):
    pat = re.compile(r'(?ms)^(## Decisions preamble[ \t]*\n)(.*?)(?=^## )')
    repl = lambda mm: mm.group(1) + '\n' + decisions_text + '\n\n'
    new_text, n = pat.subn(repl, spec_text, count=1)
    if n != 1:
        sys.stderr.write("error: '## Decisions preamble' header not found exactly once before next '## '\n")
        sys.exit(2)
    return new_text

body = replace_preamble(body, decisions)
sys.stdout.write(body)
PY
then
  echo "error: cleanup or preamble splice failed" >&2
  exit 5
fi

# Sanity-recheck the splice (defensive — should always pass after the splice above).
if ! python3 - "$CLEAN" "$RUN_DIR/03-decisions.md" >&2 <<'PY'
import sys, re, difflib
spec_path, decisions_path = sys.argv[1:]
spec = open(spec_path, 'r', encoding='utf-8').read()
expected = open(decisions_path, 'r', encoding='utf-8').read().strip()
m = re.search(r'(?m)^## Decisions preamble\s*\n(.*?)(?=^## )', spec, flags=re.DOTALL)
if not m:
    sys.stderr.write("preamble section missing after splice\n")
    sys.exit(1)
actual = m.group(1).strip()
if actual != expected:
    sys.stderr.write("post-splice byte-match unexpectedly failed (script bug)\n")
    sys.stderr.write("\n".join(difflib.unified_diff(
        expected.splitlines(), actual.splitlines(),
        fromfile='03-decisions.md', tofile='spec preamble', lineterm=''
    )) + "\n")
    sys.exit(1)
PY
then
  echo "error: post-splice preamble byte-match FAILED (script bug)" >&2
  exit 6
fi

# Copy clean spec to canonical path. cp = mechanical, auditable.
# Ensure the destination dir exists — Stage 0's cwd-aware resolution may pick
# a vault project's specs/ dir that has not been created yet.
mkdir -p "$(dirname "$CANONICAL_PATH")"
cp "$CLEAN" "$CANONICAL_PATH"
echo "ok: round=$ROUND clean=$CLEAN canonical=$CANONICAL_PATH"
