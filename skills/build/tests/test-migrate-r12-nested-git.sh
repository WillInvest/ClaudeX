#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/mem/sub"
printf 'gitdir: elsewhere\n' > "$CXMEM_HOME/projects/mem/sub/.git"

set +e
CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >"$TMP/out" 2>"$TMP/err"
status=$?
set -e
[[ "$status" -eq 4 ]]
grep -q 'nested .git' "$TMP/err"

echo "PASS: migrate-r12 rejects nested git roots and worktree markers"
