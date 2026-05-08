#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUN_POST_MIGRATION_TESTS:-0}" != "1" ]]; then
  echo "PASS: skipped post-migration legacy top-level tree check"
  exit 0
fi

CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
for name in sessions specs runs; do
  [[ ! -e "$CXMEM_ROOT/$name" ]] || { echo "FAIL: legacy top-level tree remains: $CXMEM_ROOT/$name"; exit 1; }
done
echo "PASS: no legacy top-level CXMem trees remain"
