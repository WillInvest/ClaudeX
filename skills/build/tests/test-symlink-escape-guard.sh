#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/resolve-cxmem-project.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects" "$TMP/outside" "$TMP/outside-cwd"
ln -s "$TMP/outside" "$CXMEM_HOME/projects/escape"
ln -s "$TMP/outside-cwd" "$CXMEM_HOME/projects/cwdescape"

set +e
CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=escape bash "$SCRIPT" >"$TMP/out" 2>"$TMP/err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'escapes projects root' "$TMP/err"

set +e
( cd "$CXMEM_HOME/projects/cwdescape" && CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" >"$TMP/cwd.out" 2>"$TMP/cwd.err" )
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'escapes projects root' "$TMP/cwd.err"

echo "PASS: cxmem project resolver rejects symlink escapes outside projects root for env and cwd paths"
