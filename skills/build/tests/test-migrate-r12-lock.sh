#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/mem"
exec 8>"$CXMEM_HOME/.cxmem-migration.lock"
flock -n 8

set +e
CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >"$TMP/out" 2>"$TMP/err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'another CXMem migration is running' "$TMP/err"

echo "PASS: migrate-r12 lock prevents concurrent migration"
