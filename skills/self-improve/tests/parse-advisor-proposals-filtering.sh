#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/advisor.out" <<'EOF'
<<<SI-PROPOSAL>>>
---
target_kind: skill-prompt
target_path: skills/x/SKILL.md
target_section: prompt
change_type: replace
slug: first
---
## Observation
A
## Proposed change
B
## Rationale
C
## Risk
C
<<<END-SI-PROPOSAL>>>
<<<SI-PROPOSAL>>>
---
target_kind: recording-protocol
target_path: skills/x/prompt.md
target_section: records
change_type: clarify
slug: second
---
## Observation
A
## Proposed change
B
## Rationale
C
## Risk
C
<<<END-SI-PROPOSAL>>>
EOF

count="$(bash "$ROOT/skills/self-improve/scripts/parse-advisor-proposals.sh" "$TMP/advisor.out" "$TMP/10-advice-by-claude" m__r sir-1 codex --target-kind skill-prompt --max-items 1)"
[[ "$count" == "1" ]] || { echo "FAIL: max/filter count wrong: $count"; exit 1; }
[[ -f "$TMP/10-advice-by-claude/m__r--001-first.md" ]] || { echo "FAIL: filtered proposal missing"; exit 1; }
[[ ! -f "$TMP/10-advice-by-claude/m__r--002-second.md" ]] || { echo "FAIL: max-items ignored"; exit 1; }

if bash "$ROOT/skills/self-improve/scripts/parse-advisor-proposals.sh" "$TMP/advisor.out" "$TMP/bad" m__r sir-1 codex --target-kind unsupported --max-items 5 >/dev/null 2>&1; then
  echo "FAIL: unsupported target-kind accepted"
  exit 1
fi

echo "PASS: parse advisor proposals filtering"
