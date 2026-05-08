#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLAUDE_MD="${CXMEM_HOME:-${HOME}/CXMem}/CLAUDE.md"

for pattern in '${HOME}/CXMem/sessions/' '${HOME}/CXMem/specs/' '${HOME}/CXMem/runs/' '${HOME}/CXMem/project-memory.md' 'vault/projects/claudex/audits'; do
  if grep -Fq "$pattern" "$CLAUDE_MD"; then
    echo "FAIL: legacy protocol path remains: $pattern"
    exit 1
  fi
done

grep -Fq '${HOME}/CXMem/projects/<X>/sessions/' "$CLAUDE_MD"

echo "PASS: CXMem protocol contains no legacy top-level paths"
