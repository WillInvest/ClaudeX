#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/promote-codex-round.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
trap 'echo "FAIL: promote-codex-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

SESSIONS="$SCRATCH/CXMem/projects/mem/sessions"
mkdir -p "$SESSIONS/demo/rounds"
printf '# Parent\n' > "$SESSIONS/demo/rounds/round-1.md"
cat > "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md" <<'EOF'
# Round 1 codex

## Summary

Legacy summary should not win.

## Round close

Close-preferred summary.
EOF
cat > "$SESSIONS/demo/rounds/round-1-codex-plan-r1.md" <<'EOF'
# Round 1 codex

## Summary

Legacy summary fallback.
EOF
printf -- '- Round 1: Parent\n' > "$SESSIONS/demo/session-memory.md"

bash "$SCRIPT" "$SESSIONS" mem demo 1 > "$SCRATCH/out" 2> "$SCRATCH/err"
grep -q 'ok: promoted 2 codex-derived rounds' "$SCRATCH/out"
grep -q '^  - codex-impl-r1: Close-preferred summary\.$' "$SESSIONS/demo/session-memory.md"
grep -q '^  - codex-plan-r1: Legacy summary fallback\.$' "$SESSIONS/demo/session-memory.md"
grep -F "warning: falling back to ## Summary for legacy codex round: $SESSIONS/demo/rounds/round-1-codex-plan-r1.md" "$SCRATCH/err" >/dev/null
[[ "$(grep -c 'falling back to ## Summary' "$SCRATCH/err")" -eq 1 ]]

mkdir -p "$SCRATCH/CXMem/sessions"
set +e
trap - ERR
bash "$SCRIPT" "$SCRATCH/CXMem/sessions" mem demo 1 >"$SCRATCH/escape.out" 2>"$SCRATCH/escape.err"
status=$?
set -e
trap 'echo "FAIL: promote-codex-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -eq 2 ]]
grep -q 'outside projects/mem/sessions' "$SCRATCH/escape.err"

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: codex promotion prefers close and warns on legacy fallback"
