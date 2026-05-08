#!/usr/bin/env bash
# Verifies the user accepted or declined detached build launch before handoff.
# Usage: gate-user-build-choice.sh <run-dir>
#
# Reads:
#   <run-dir>/.user-build-choice      must contain y/yes/n/no with optional trailing whitespace
# Writes:
#   none
# Stdout:
#   USER_BUILD_YES | USER_BUILD_NO
# Allowed tokens:
#   USER_BUILD_YES | USER_BUILD_NO
# Exit:
#   0 success; token emitted
#   2 usage / missing run dir
#   3 missing or invalid user build choice
#   4 unused
#   5 unused
# SKILL.md next-step contract: yes launches detached tmux build; no stops quietly.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "error: usage: gate-user-build-choice.sh <run-dir>" >&2
  exit 2
fi

RUN_DIR="$1"

[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }

CHOICE_FILE="$RUN_DIR/.user-build-choice"
if [[ ! -f "$CHOICE_FILE" ]]; then
  echo "error: user build choice missing" >&2
  exit 3
fi

if python3 - "$CHOICE_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], 'r', encoding='utf-8').read()
sys.exit(0 if re.fullmatch(r'(?i)y(?:es)?[ \t\r\n]*', text) else 1)
PY
then
  echo "USER_BUILD_YES"
elif python3 - "$CHOICE_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], 'r', encoding='utf-8').read()
sys.exit(0 if re.fullmatch(r'(?i)n(?:o)?[ \t\r\n]*', text) else 1)
PY
then
  echo "USER_BUILD_NO"
else
  echo "error: invalid user build choice" >&2
  exit 3
fi
