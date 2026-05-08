#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/mem"
cat > "$CXMEM_HOME/projects/mem/project-memory.md" <<'EOF'
${HOME}/CXMem/sessions/a
${HOME}/CXMem/specs/r12
${HOME}/CXMem/runs/run
${HOME}/CXMem/projects/mem/sessions/already
EOF

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >/dev/null
expected="$TMP/expected"
cat > "$expected" <<'EOF'
${HOME}/CXMem/projects/mem/sessions/a
${HOME}/CXMem/projects/mem/specs/r12
${HOME}/CXMem/projects/mem/runs/run
${HOME}/CXMem/projects/mem/sessions/already
EOF
cmp "$expected" "$CXMEM_HOME/projects/mem/project-memory.md"
CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >/dev/null
cmp "$expected" "$CXMEM_HOME/projects/mem/project-memory.md"

echo "PASS: migrate-r12 rewrites legacy project-memory paths idempotently"
