#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/skills/think/SKILL.md"
FREEZE="$ROOT/skills/think/scripts/freeze-decisions.sh"
BUILD="$ROOT/skills/build/SKILL.md"

! grep -q '02-transcript.md.*initialize' "$SKILL"
grep -q 'dispatch-codex-spec-write.sh' "$SKILL"
grep -q 'build-opus-spec-review-prompt.sh' "$SKILL"
grep -q 'freeze-decisions.sh "$RUN_DIR"' "$SKILL"
grep -q 'USER_BUILD_YES' "$SKILL"
! grep -q 'USER_BUILD_CHOICE_1' "$SKILL"
! grep -q 'literal `1` or `2`' "$SKILL"

freeze_count="$(grep -c '03-decisions\.frozen' "$FREEZE" || true)"
build_count="$(grep -c '03-decisions\.frozen' "$BUILD" || true)"
[[ "$freeze_count" -eq 1 ]] || { echo "FAIL: freeze-decisions.sh has $freeze_count frozen-marker matches, expected 1"; exit 1; }
[[ "$build_count" -eq 1 ]] || { echo "FAIL: build SKILL.md has $build_count frozen-marker matches, expected 1"; exit 1; }

freeze_match="$(grep -o '03-decisions\.frozen' "$FREEZE" | head -1)"
build_match="$(grep -o '03-decisions\.frozen' "$BUILD" | head -1)"
[[ "$freeze_match" == "$build_match" ]] || { echo "FAIL: frozen-marker strings differ"; exit 1; }

echo "PASS: think skill keeps spec review stage and uses yes/no bg handoff"
