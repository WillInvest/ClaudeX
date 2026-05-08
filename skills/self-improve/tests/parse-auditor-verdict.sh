#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/proposal.md" <<'EOF'
---
mission_id: m__r
self_improve_run_id: sir-1
advisor_model: claude-opus
target_path: skills/x/SKILL.md
target_section: prompt
target_kind: skill-prompt
change_type: replace
slug: refine-me
verdict: pending-audit
---

## Observation
P

## Proposed change
old change

## Rationale
R

## Risk
V

## Audit verdict

pending-audit
EOF
cat > "$TMP/auditor.out" <<'EOF'
ACCEPT: earlier line is echoed
REFINE: tighten scope

## Proposed change
new refined change
EOF

mv "$TMP/proposal.md" "$TMP/m__r--001-refine-me.md"
out="$(bash "$ROOT/skills/self-improve/scripts/parse-auditor-verdict.sh" "$TMP/m__r--001-refine-me.md" "$TMP/auditor.out" "$TMP/20-audit-by-codex" m__r sir-1 claude-opus codex-gpt)"
[[ "$out" == "refined: tighten scope" ]] || { echo "FAIL: wrong verdict: $out"; exit 1; }
grep -q '^verdict: refined: tighten scope$' "$TMP/m__r--001-refine-me.md" || { echo "FAIL: frontmatter verdict not single-line refined"; exit 1; }
grep -q 'new refined change' "$TMP/m__r--001-refine-me.md" || { echo "FAIL: refined proposed change missing"; exit 1; }
[[ -f "$TMP/20-audit-by-codex/m__r--001-refine-me.md" ]] || { echo "FAIL: paired audit record missing"; exit 1; }
grep -q '^self_improve_run_id: sir-1$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: audit self_improve_run_id missing"; exit 1; }
grep -q '^auditor_model: codex-gpt$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: audit auditor_model missing"; exit 1; }
grep -q '^advisor_model: claude-opus$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: audit advisor_model missing"; exit 1; }
grep -q '^proposal_path: m__r--001-refine-me.md$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: audit proposal_path missing"; exit 1; }
grep -q '^refined: tighten scope$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: audit parsed verdict line missing"; exit 1; }
grep -q '^## Auditor rationale$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: auditor rationale section missing"; exit 1; }
grep -q 'ACCEPT: earlier line is echoed' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: auditor rationale body missing"; exit 1; }
grep -q '^## Refined proposed change$' "$TMP/20-audit-by-codex/m__r--001-refine-me.md" || { echo "FAIL: refined proposed change section missing"; exit 1; }

cat > "$TMP/noverdict.out" <<'EOF'
No closed token here.
EOF
bash "$ROOT/skills/self-improve/scripts/parse-auditor-verdict.sh" "$TMP/m__r--001-refine-me.md" "$TMP/noverdict.out" "$TMP/20-audit-by-codex" m__r sir-1 claude-opus codex-gpt >/dev/null
grep -q '^verdict: degraded:auditor-no-verdict$' "$TMP/m__r--001-refine-me.md" || { echo "FAIL: missing verdict degradation not recorded"; exit 1; }

echo "PASS: parse auditor verdict"
