#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUN_POST_MIGRATION_TESTS:-0}" != "1" ]]; then
  echo "PASS: skipped post-migration nested git root check"
  exit 0
fi

CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
if find "$CXMEM_ROOT/projects" -mindepth 2 \( -name .git -type d -o -name .git -type f \) -print -quit | grep -q .; then
  echo "FAIL: nested .git root or worktree marker remains under $CXMEM_ROOT/projects"
  exit 1
fi
echo "PASS: no nested git roots exist under CXMem projects"
