#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/CXMem/projects/p/sessions/s/runs/r1"
mkdir -p "$RUN" "$TMP/CXMem/projects/p/sessions/s/rounds"
printf '# Round one\n' > "$TMP/CXMem/projects/p/sessions/s/rounds/round-1.md"
printf '# Codex round should not be in Claude projection\n' > "$TMP/CXMem/projects/p/sessions/s/rounds/round-2-codex-1.md"

bash "$ROOT/skills/self-improve/scripts/project-mission-inputs.sh" "$RUN" claude > "$TMP/out.md"
head -n 1 "$TMP/out.md" | grep -q '^# CXMEM-CLAUDE-ROUNDS v1$' || { echo "FAIL: claude marker missing"; exit 1; }
grep -q '^# Mission: s__r1$' "$TMP/out.md" || { echo "FAIL: mission metadata missing"; exit 1; }
grep -q "^# Source: $RUN$" "$TMP/out.md" || { echo "FAIL: source metadata missing"; exit 1; }
grep -q 'Round one' "$TMP/out.md" || { echo "FAIL: round content missing"; exit 1; }
! grep -q 'Codex round should not be in Claude projection' "$TMP/out.md" || { echo "FAIL: claude projection included codex-suffixed round"; exit 1; }
printf '# codex ok\n' > "$RUN/round-1-codex-1.md"
bash "$ROOT/skills/self-improve/scripts/project-mission-inputs.sh" "$RUN" codex > "$TMP/codex.md"
head -n 1 "$TMP/codex.md" | grep -q '^# CXMEM-CODEX-RECORDS v1$' || { echo "FAIL: codex marker missing"; exit 1; }

printf '# CXMEM-CODEX-RECORDS v2\n' > "$RUN/round-1-codex-1.md"
if bash "$ROOT/skills/self-improve/scripts/project-mission-inputs.sh" "$RUN" codex > "$TMP/stdout" 2>/dev/null; then
  echo "FAIL: unknown codex version should fail"
  exit 1
fi
grep -q 'degraded:unknown-codex-record-version=2' "$TMP/stdout" || { echo "FAIL: unknown version degradation missing"; exit 1; }

echo "PASS: projection version marker"
