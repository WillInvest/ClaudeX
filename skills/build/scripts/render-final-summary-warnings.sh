#!/usr/bin/env bash
# Prints the required R12 final-summary warning lines.
# Usage: render-final-summary-warnings.sh
# Reads:
#   none
# Writes:
#   none
# Stdout:
#   three required final-summary warning lines
# Exit:
#   0 success
#   2 usage
set -euo pipefail

if [[ "$#" -ne 0 ]]; then
  echo "error: usage: render-final-summary-warnings.sh" >&2
  exit 2
fi

printf '%s\n' \
  '- branch is half-applied' \
  '- to finish R12, run `bash projects/mem/artifacts/migrate-r12.sh`' \
  '- after migration, run `bash projects/mem/sessions/<slug>/runs/<run-id>/run-tests.sh` for post-migration regression tests'
