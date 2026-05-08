#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GENERATOR="$ROOT/skills/build/scripts/render-final-summary-warnings.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bash "$GENERATOR" > "$TMP/warnings"
grep -q 'branch is half-applied' "$TMP/warnings"
grep -q '`bash projects/mem/artifacts/migrate-r12.sh`' "$TMP/warnings"
grep -q '`bash projects/mem/sessions/<slug>/runs/<run-id>/run-tests.sh`' "$TMP/warnings"

echo "PASS: final summary warning generator emits R12 half-applied migration warnings"
