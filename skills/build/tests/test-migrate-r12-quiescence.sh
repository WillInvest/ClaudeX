#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/sessions" "$CXMEM_HOME/projects/mem"
printf 'recent\n' > "$CXMEM_HOME/sessions/recent.md"

set +e
CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" >"$TMP/out" 2>"$TMP/err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'recent top-level CXMem writes detected' "$TMP/err"

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >/dev/null
[[ -f "$CXMEM_HOME/projects/mem/sessions/recent.md" ]]

echo "PASS: migrate-r12 quiescence check blocks recent writes unless forced"
