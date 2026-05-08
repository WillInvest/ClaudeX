#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/advisor.out" <<'EOF'
noise
<<<SI-PROPOSAL>>>
---
target_kind: other
target_path: n/a
target_section: n/a
change_type: clarify
slug: keep this slug
---
## Observation
Observation body.
## Proposed change
Change body.
## Rationale
Reason body.
## Risk
Risk body.
<<<END-SI-PROPOSAL>>>
EOF

count="$(bash "$ROOT/skills/self-improve/scripts/parse-advisor-proposals.sh" "$TMP/advisor.out" "$TMP/10-advice-by-claude" m__r sir-1 claude-opus --target-kind any --max-items 5)"
[[ "$count" == "1" ]] || { echo "FAIL: expected one proposal, got $count"; exit 1; }
P="$TMP/10-advice-by-claude/m__r--001-keep this slug.md"
[[ -f "$P" ]] || { echo "FAIL: proposal file missing"; exit 1; }
grep -q '^slug: keep this slug$' "$P" || { echo "FAIL: slug not preserved"; exit 1; }
grep -q '^target_path: n/a$' "$P" || { echo "FAIL: target_path n/a not preserved"; exit 1; }
grep -q '^target_section: n/a$' "$P" || { echo "FAIL: target_section not preserved"; exit 1; }
grep -q '^self_improve_run_id: sir-1$' "$P" || { echo "FAIL: self_improve_run_id missing"; exit 1; }
grep -q '^advisor_model: claude-opus$' "$P" || { echo "FAIL: advisor_model missing"; exit 1; }
grep -q '^verdict: pending-audit$' "$P" || { echo "FAIL: pending verdict missing"; exit 1; }
grep -q '^## Observation$' "$P" || { echo "FAIL: Observation section missing"; exit 1; }
grep -q '^## Rationale$' "$P" || { echo "FAIL: Rationale section missing"; exit 1; }
grep -q '^## Risk$' "$P" || { echo "FAIL: Risk section missing"; exit 1; }

echo "PASS: parse advisor proposals roundtrip"
