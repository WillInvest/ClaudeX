#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/sessions" "$CXMEM_HOME/projects/mem/sessions"
printf 'a\n' > "$CXMEM_HOME/sessions/file"
printf 'b\n' > "$CXMEM_HOME/projects/mem/sessions/file"

set +e
CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >"$TMP/out" 2>"$TMP/err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'differing destination exists' "$TMP/err"

echo "PASS: migrate-r12 halts on differing destinations"
