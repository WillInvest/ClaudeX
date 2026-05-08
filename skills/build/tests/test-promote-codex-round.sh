#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/promote-codex-round.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SESSIONS="$TMP/CXMem/projects/mem/sessions"
mkdir -p "$SESSIONS/demo/rounds"
printf '# Parent\n' > "$SESSIONS/demo/rounds/round-1.md"
cat > "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md" <<'EOF'
# Round 1 codex
## Summary
Impl summary.
EOF
printf -- '- Round 1: Parent\n' > "$SESSIONS/demo/session-memory.md"

bash "$SCRIPT" "$SESSIONS" mem demo 1 > "$TMP/out"
grep -q 'ok: promoted 1 codex-derived rounds' "$TMP/out"
grep -q '^  - codex-impl-r1: Impl summary\.$' "$SESSIONS/demo/session-memory.md"

mkdir -p "$TMP/CXMem/sessions"
set +e
bash "$SCRIPT" "$TMP/CXMem/sessions" mem demo 1 >"$TMP/escape.out" 2>"$TMP/escape.err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'outside projects/mem/sessions' "$TMP/escape.err"

echo "PASS: codex promotion uses project signature and refuses non-project sessions root"
