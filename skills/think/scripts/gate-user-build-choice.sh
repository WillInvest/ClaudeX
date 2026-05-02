#!/usr/bin/env bash
# Verifies the user chose a literal build launch mode before handoff.
# Usage: gate-user-build-choice.sh <run-dir>
#
# Reads:
#   <run-dir>/.user-build-choice      must contain literal 1 or 2 with optional trailing whitespace
# Writes:
#   none
# Stdout:
#   USER_BUILD_CHOICE_1 | USER_BUILD_CHOICE_2
# Allowed tokens:
#   USER_BUILD_CHOICE_1 | USER_BUILD_CHOICE_2
# Exit:
#   0 success; token emitted
#   2 usage / missing run dir
#   3 missing or invalid user build choice
#   4 unused
#   5 unused
# SKILL.md next-step contract: choice 1 runs inline build; choice 2 runs detached tmux build.
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
sys.exit(0 if re.fullmatch(r'1[ \t\r\n]*', text) else 1)
PY
then
  echo "USER_BUILD_CHOICE_1"
elif python3 - "$CHOICE_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], 'r', encoding='utf-8').read()
sys.exit(0 if re.fullmatch(r'2[ \t\r\n]*', text) else 1)
PY
then
  echo "USER_BUILD_CHOICE_2"
else
  echo "error: invalid user build choice" >&2
  exit 3
fi
