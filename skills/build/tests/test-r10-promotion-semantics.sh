#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER="$ROOT/skills/build/scripts/promote-codex-round.sh"
SKILL="$ROOT/skills/build/SKILL.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

grep -q 'promote-codex-round.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ"' "$SKILL"

SESSIONS="$TMP/CXMem/projects/mem/sessions"
mkdir -p "$SESSIONS/demo/rounds"
cat > "$SESSIONS/demo/rounds/round-7-codex-spec-r1.md" <<'EOF'
# Round 7 codex-spec-r1
## Summary
Spec summary.
EOF
cat > "$SESSIONS/demo/rounds/round-7-codex-plan-r1.md" <<'EOF'
# Round 7 codex-plan-r1
## Summary
Plan summary.
EOF
sleep 1
cat > "$SESSIONS/demo/rounds/round-7.md" <<'EOF'
# Parent main round

## Round close
Closed after codex-derived writes.
EOF
cat > "$SESSIONS/demo/session-memory.md" <<'EOF'
- Round 7: Parent main round.
EOF
cat > "$TMP/CXMem/projects/mem/project-memory.md" <<'EOF'
| Session | Summary |
|---|---|
| demo | Parent only |
EOF
before="$(grep -c '^|' "$TMP/CXMem/projects/mem/project-memory.md")"

bash "$HELPER" "$SESSIONS" mem demo 7 > "$TMP/promote.out"
grep -q 'ok: promoted 2 codex-derived rounds into session-memory.md' "$TMP/promote.out"
[[ -f "$SESSIONS/demo/session-memory.md" ]]
awk '
  /^- Round 7:/ { parent=1; next }
  parent && /^  - codex-/ { nested++ }
  /^- codex-/ { peer++ }
  END { exit (nested == 2 && peer == 0) ? 0 : 1 }
' "$SESSIONS/demo/session-memory.md"
grep -q '^  - codex-spec-r1: Spec summary\.$' "$SESSIONS/demo/session-memory.md"
grep -q '^  - codex-plan-r1: Plan summary\.$' "$SESSIONS/demo/session-memory.md"
after="$(grep -c '^|' "$TMP/CXMem/projects/mem/project-memory.md")"
[[ "$before" -eq "$after" ]] || { echo "FAIL: project-memory row count changed"; exit 1; }

mkdir -p "$SESSIONS/future/rounds"
cat > "$SESSIONS/future/rounds/round-3.md" <<'EOF'
# Future parent
EOF
cat > "$SESSIONS/future/rounds/round-3-codex-spec-r1.md" <<'EOF'
# Future codex
## Summary
Future summary.
EOF
touch -d '+1 day' "$SESSIONS/future/rounds/round-3-codex-spec-r1.md"
set +e
bash "$HELPER" "$SESSIONS" mem future 3 > "$TMP/future.out" 2>"$TMP/future.err"
status=$?
set -e
[[ "$status" -eq 4 ]] || { echo "FAIL: future mtime exited $status, expected 4"; exit 1; }
grep -q 'mtime is in the future' "$TMP/future.err"

echo "PASS: promotion helper nests codex summaries and rejects future codex mtimes"
