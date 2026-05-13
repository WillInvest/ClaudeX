#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/skills/build/SKILL.md"
THINK_SKILL="$ROOT/skills/think/SKILL.md"
THINK_START="$ROOT/skills/think/scripts/start-bg-build.sh"

grep -q 'RUN_ID="${RUN_ID:-' "$SKILL"
grep -q 'if \[\[ -z "${RUN_DIR:-}" \]\]; then' "$SKILL"
grep -q 'resolve-run-dir.sh "$RUN_ID"' "$SKILL"
grep -q 'CANONICAL_SPEC_PATH="${CANONICAL_SPEC_PATH:-' "$SKILL"
grep -q 'test -f "$RUN_DIR/03-decisions.frozen"' "$SKILL"
grep -q 'probe-cxmem-host.sh' "$SKILL"
grep -q '\[test-only/manual\] running outside backgrounded claude agent and tmux; continuing' "$SKILL"
grep -q 'CXMEM_HOST_PROJECT_READY' "$SKILL"
grep -q 'CXMEM_HOST_PROJECT_NO_SESSION' "$SKILL"
grep -q 'CXMEM_HOST_MISSING' "$SKILL"
grep -q 'inherited `RUN_DIR` wins' "$SKILL"
! grep -q 'RUN_DIR="${RUN_DIR:-${HOME}/vault/projects/claudex/audits' "$SKILL"

grep -q 'resolve-run-dir.sh' "$THINK_SKILL"
grep -q 'CXMEM_HOST_PROJECT_READY' "$THINK_SKILL"
grep -q 'CXMEM_HOST_PROJECT_NO_SESSION' "$THINK_SKILL"
grep -q 'CXMEM_HOST_MISSING' "$THINK_SKILL"
! grep -q 'RUN_DIR="${HOME}/vault/projects/claudex/audits' "$THINK_SKILL"

grep -q 'start-bg-build.sh' "$THINK_START"
grep -q 'claude --bg' "$THINK_START"
grep -q 'STABLE_PROMPT="$RUN_DIR/.bg-prompt.md"' "$THINK_START"
grep -q 'CXMEM_HOME="${CXMEM_HOME:-}"' "$THINK_START"
! grep -q '\[test-only/manual\]' "$THINK_START"

echo "PASS: build Stage 0 documents resolver routing, env precedence, CXMem states, and manual bg/tmux warning"
