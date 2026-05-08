#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/resolve-run-dir.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

home="$TMP/home"
cxmem="$TMP/cxmem"
mkdir -p "$home" "$cxmem/projects/mem" "$cxmem/docs"
printf '**Active session**: `session-slug`, last round 4\n' > "$cxmem/projects/mem/project-memory.md"

out="$(HOME="$home" CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY bash "$SCRIPT" "run-1")"
[[ "$out" == "$cxmem/projects/mem/sessions/session-slug/runs/run-1" ]]

out="$(HOME="$home" CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_NO_SESSION bash "$SCRIPT" "run-2")"
[[ "$out" == "$cxmem/projects/mem/runs/run-2" ]]

out="$(HOME="$home" CXMEM_HOME="$TMP/missing" CXMEM_HOST_STATE=CXMEM_HOST_MISSING bash "$SCRIPT" "run-3")"
[[ "$out" == "$home/vault/projects/claudex/audits/run-3" ]]

out="$(HOME="$home" CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE= bash "$SCRIPT" "run-4")"
[[ "$out" == "$cxmem/projects/mem/sessions/session-slug/runs/run-4" ]]

set +e
HOME="$home" CXMEM_HOME="$cxmem" CXMEM_HOST_STATE=CXMEM_HOST_NO_PROJECT bash "$SCRIPT" "run-5" >"$TMP/noproject.out" 2>"$TMP/noproject.err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'no resolved project' "$TMP/noproject.err"

set +e
HOME="$home" CXMEM_HOME="$cxmem" CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_NO_MEMORY bash "$SCRIPT" "run-6" >"$TMP/nomem.out" 2>"$TMP/nomem.err"
status=$?
set -e
[[ "$status" -eq 3 ]]
grep -q 'project memory is missing' "$TMP/nomem.err"

set +e
bash "$SCRIPT" >"$TMP/missing-out" 2>"$TMP/missing-err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'usage: resolve-run-dir.sh <run-id>' "$TMP/missing-err"

set +e
HOME="$home" CXMEM_HOME="$cxmem" CXMEM_HOST_STATE=BAD_STATE bash "$SCRIPT" "run-7" >"$TMP/bad-out" 2>"$TMP/bad-err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'invalid CXMEM_HOST_STATE' "$TMP/bad-err"

echo "PASS: run-dir resolver routes R12 project states, fallback, overrides, and invalid inputs"
