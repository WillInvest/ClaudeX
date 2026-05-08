#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/resolve-cxmem-project.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/mem" "$CXMEM_HOME/projects/other" "$CXMEM_HOME/projects/.dotproject" "$TMP/run"

out="$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=mem bash "$SCRIPT")"
[[ "$out" == "mem" ]]

out="$(cd "$CXMEM_HOME/projects/other/deep" 2>/dev/null || { mkdir -p "$CXMEM_HOME/projects/other/deep"; cd "$CXMEM_HOME/projects/other/deep"; }; CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT")"
[[ "$out" == "other" ]]

out="$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=.dotproject bash "$SCRIPT")"
[[ "$out" == ".dotproject" ]]

( cd "$CXMEM_HOME/projects/other" && CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=mem RUN_DIR="$TMP/run" bash "$SCRIPT" >/dev/null )
grep -q 'CXMEM_PROJECT=mem differs from cwd-derived project other' "$TMP/run/.codex-state"

set +e
CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT='.' bash "$SCRIPT" >"$TMP/invalid.out" 2>"$TMP/invalid.err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'invalid CXMEM_PROJECT' "$TMP/invalid.err"

set +e
CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT='bad/name' bash "$SCRIPT" >"$TMP/invalid-slash.out" 2>"$TMP/invalid-slash.err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'invalid CXMEM_PROJECT' "$TMP/invalid-slash.err"

set +e
CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=missing bash "$SCRIPT" >"$TMP/missing.out" 2>"$TMP/missing.err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'project directory missing' "$TMP/missing.err"

set +e
CXMEM_HOME="$TMP/nohost" bash "$SCRIPT" >"$TMP/nohost.out" 2>"$TMP/nohost.err"
status=$?
set -e
[[ "$status" -eq 4 ]]
grep -q 'CXMem host missing' "$TMP/nohost.err"

set +e
( cd "$TMP" && CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" >"$TMP/noproject.out" 2>"$TMP/noproject.err" )
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q "cwd: $TMP" "$TMP/noproject.err"
grep -q 'no projects/<X>/ ancestor' "$TMP/noproject.err"
grep -q 'cd into' "$TMP/noproject.err"
grep -q 'CXMEM_PROJECT=<name>' "$TMP/noproject.err"

echo "PASS: cxmem project resolver handles env, cwd, mismatch, missing, and no-project diagnostics"
