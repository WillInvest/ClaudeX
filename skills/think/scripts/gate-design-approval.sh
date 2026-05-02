#!/usr/bin/env bash
# Verifies final design approval before decisions freeze and spec writing.
# Usage: gate-design-approval.sh <run-dir>
#
# Reads:
#   <run-dir>/.design-approved        marker created only after user approval
# Writes:
#   none
# Stdout:
#   DESIGN_APPROVED
# Allowed tokens:
#   DESIGN_APPROVED
# Exit:
#   0 success; token emitted
#   2 usage / missing run dir
#   3 design approval gate refused
#   4 unused
#   5 unused
# SKILL.md next-step contract: DESIGN_APPROVED continues; exit 3 halts for user approval.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "error: usage: gate-design-approval.sh <run-dir>" >&2
  exit 2
fi

RUN_DIR="$1"

[[ -d "$RUN_DIR" ]] || { echo "error: run dir not found: $RUN_DIR" >&2; exit 2; }

if [[ ! -f "$RUN_DIR/.design-approved" ]]; then
  echo "error: design not approved" >&2
  exit 3
fi

echo "DESIGN_APPROVED"
