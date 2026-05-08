#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CMD="$ROOT/commands/self-improve.md"
SKILL="$ROOT/skills/self-improve/SKILL.md"

[[ -f "$CMD" ]] || { echo "FAIL: command file missing"; exit 1; }
[[ -f "$SKILL" ]] || { echo "FAIL: skill file missing"; exit 1; }
grep -q '^description: ' "$CMD" || { echo "FAIL: command frontmatter missing description"; exit 1; }
grep -q '^Use the self-improve skill\.$' "$CMD" || { echo "FAIL: command does not use think-style delegation"; exit 1; }
grep -q '^name: claudex-self-improve$' "$SKILL" || { echo "FAIL: skill frontmatter missing name"; exit 1; }
grep -q '^description: ' "$SKILL" || { echo "FAIL: skill frontmatter missing description"; exit 1; }
grep -q 'flow-short' "$SKILL" || { echo "FAIL: flow-short mapping missing"; exit 1; }
grep -q 'no-auto-apply' "$SKILL" || grep -q 'No auto-apply' "$SKILL" || { echo "FAIL: no-auto-apply contract missing"; exit 1; }

while IFS= read -r sh; do
  [[ -x "$sh" ]] || { echo "FAIL: script is not executable: $sh"; exit 1; }
done < <(find "$ROOT/skills/self-improve" -name '*.sh' -type f)

echo "PASS: skill files present"
