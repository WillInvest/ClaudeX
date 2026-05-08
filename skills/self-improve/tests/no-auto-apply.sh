#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/run"
mkdir -p "$RUN" "$TMP/project"
printf 'original\n' > "$TMP/project/source.txt"
before="$(sha256sum "$TMP/project/source.txt")"
cat > "$TMP/advisor.out" <<'EOF'
<<<SI-PROPOSAL>>>
---
target_kind: script
target_path: source.txt
target_section: n/a
change_type: replace
slug: do-not-apply
---
## Observation
P
## Proposed change
Replace source file contents.
## Rationale
R
## Risk
V
<<<END-SI-PROPOSAL>>>
EOF
printf 'ACCEPT: advisory only\n' > "$TMP/auditor.out"

bash "$ROOT/skills/self-improve/scripts/parse-advisor-proposals.sh" "$TMP/advisor.out" "$RUN/10-advice-by-claude" m__r sir-1 claude --target-kind any --max-items 5 >/dev/null
bash "$ROOT/skills/self-improve/scripts/parse-auditor-verdict.sh" "$RUN/10-advice-by-claude/m__r--001-do-not-apply.md" "$TMP/auditor.out" "$RUN/20-audit-by-codex" m__r sir-1 claude codex >/dev/null
after="$(sha256sum "$TMP/project/source.txt")"
[[ "$before" == "$after" ]] || { echo "FAIL: source file changed"; exit 1; }
grep -q 'No auto-apply behavior exists' "$ROOT/skills/self-improve/SKILL.md" || { echo "FAIL: no-auto-apply prose missing"; exit 1; }

echo "PASS: no auto apply"
