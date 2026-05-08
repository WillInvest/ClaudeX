#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/sessions/s1/rounds" "$CXMEM_HOME/specs" "$CXMEM_HOME/runs/r1" "$CXMEM_HOME/projects/mem"
cat > "$CXMEM_HOME/sessions/s1/rounds/round-1.md" <<'EOF'
---
type: round-memory
---
# Round
EOF
cat > "$CXMEM_HOME/sessions/s1/.session-meta" <<'EOF'
---
slug: s1
---
EOF
printf 'old specs\n' > "$CXMEM_HOME/specs/README.md"
printf 'run\n' > "$CXMEM_HOME/runs/r1/log.txt"

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force > "$TMP/out"
[[ -f "$CXMEM_HOME/projects/mem/sessions/s1/rounds/round-1.md" ]]
[[ -f "$CXMEM_HOME/projects/mem/specs/README.md" ]]
[[ -f "$CXMEM_HOME/projects/mem/runs/r1/log.txt" ]]
grep -q 'project: mem' "$CXMEM_HOME/projects/mem/sessions/s1/rounds/round-1.md"
grep -q 'project: mem' "$CXMEM_HOME/projects/mem/sessions/s1/.session-meta"
[[ ! -e "$CXMEM_HOME/sessions" ]]
[[ ! -e "$CXMEM_HOME/specs" ]]
[[ ! -e "$CXMEM_HOME/runs" ]]

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >/dev/null
[[ -f "$CXMEM_HOME/projects/mem/sessions/s1/rounds/round-1.md" ]]

echo "PASS: migrate-r12 fixture moves trees, inserts frontmatter, removes legacy trees, and reruns"
