#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/sessions/s1"
cat > "$CXMEM_HOME/sessions/s1/good.md" <<'EOF'
---
type: round-memory
---
body
EOF
cat > "$CXMEM_HOME/sessions/s1/has-project.md" <<'EOF'
---
project: mem
type: round-memory
---
body
EOF
printf -- '---\nunterminated\n' > "$CXMEM_HOME/sessions/s1/bad.md"
printf 'no yaml\n' > "$CXMEM_HOME/sessions/s1/plain.md"

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force > "$TMP/out"
grep -q 'project: mem' "$CXMEM_HOME/projects/mem/sessions/s1/good.md"
[[ "$(grep -c '^project: mem$' "$CXMEM_HOME/projects/mem/sessions/s1/has-project.md")" -eq 1 ]]
grep -q 'unterminated' "$CXMEM_HOME/projects/mem/sessions/s1/bad.md"
grep -q 'skipped=' "$TMP/out"

echo "PASS: migrate-r12 frontmatter insertion skips malformed files without corruption"
