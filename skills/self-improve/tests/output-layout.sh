#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/CXMem/projects/p/improvements/2026-01-01-0000-cac-topic"
SRC="$TMP/CXMem/projects/p/sessions/s/runs/r1"
mkdir -p "$RUN" "$SRC" "$TMP/CXMem/projects/p/sessions/s/rounds"
printf '# source round\n' > "$TMP/CXMem/projects/p/sessions/s/rounds/round-1.md"
cat > "$TMP/advisor.stub" <<'EOF'
<<<SI-PROPOSAL>>>
---
target_kind: script
target_path: skills/self-improve/scripts/x.sh
target_section: dispatch
change_type: replace
slug: script-fix
---
## Observation
P
## Proposed change
C
## Rationale
R
## Risk
V
<<<END-SI-PROPOSAL>>>
EOF
printf 'ACCEPT: looks good\n' > "$TMP/auditor.stub"

mkdir -p "$RUN/01-projections"
printf '# Inputs\n\nmission_id: s__r1\n' > "$RUN/00-inputs.md"
bash "$ROOT/skills/self-improve/scripts/project-mission-inputs.sh" "$SRC" claude > "$RUN/01-projections/s__r1-claude.md"
bash "$ROOT/skills/self-improve/scripts/project-mission-inputs.sh" "$SRC" codex > "$RUN/01-projections/s__r1-codex.md"
CLAUDEX_SI_STUB_ADVISOR_OUTPUT="$TMP/advisor.stub" bash "$ROOT/skills/self-improve/scripts/dispatch-advisor-codex.sh" "$RUN" s__r1 001 "$RUN/01-projections/s__r1-claude.md" claude any 5 "skills/self-improve/scripts/x.sh" > "$RUN/advisor.out"
bash "$ROOT/skills/self-improve/scripts/parse-advisor-proposals.sh" "$RUN/advisor.out" "$RUN/10-advice-by-claude" s__r1 self-run-1 claude-opus --target-kind any --max-items 5 >/dev/null
CLAUDEX_SI_STUB_AUDITOR_OUTPUT="$TMP/auditor.stub" bash "$ROOT/skills/self-improve/scripts/dispatch-auditor-codex.sh" "$RUN" s__r1 001 "$RUN/01-projections/s__r1-claude.md" "$RUN/10-advice-by-claude/s__r1--001-script-fix.md" codex > "$RUN/auditor.out"
bash "$ROOT/skills/self-improve/scripts/parse-auditor-verdict.sh" "$RUN/10-advice-by-claude/s__r1--001-script-fix.md" "$RUN/auditor.out" "$RUN/20-audit-by-codex" s__r1 self-run-1 claude-opus codex-gpt >/dev/null
printf '# Index\n\n- 10-advice-by-claude/s__r1--001-script-fix.md\n' > "$RUN/index.md"
printf '# Summary\n\naccepted: 1\n' > "$RUN/99-summary.md"

[[ -f "$RUN/00-inputs.md" ]] || { echo "FAIL: projection missing"; exit 1; }
[[ -f "$RUN/01-projections/s__r1-claude.md" ]] || { echo "FAIL: claude projection missing"; exit 1; }
[[ -f "$RUN/01-projections/s__r1-codex.md" ]] || { echo "FAIL: codex projection missing"; exit 1; }
[[ -f "$RUN/.last-codex-advise-s__r1-001.raw" ]] || { echo "FAIL: advisor raw missing"; exit 1; }
[[ -f "$RUN/.last-codex-audit-s__r1-001.raw" ]] || { echo "FAIL: auditor raw missing"; exit 1; }
[[ ! -f "$RUN/.last-codex-audit-s__r1-001.prompt" ]] || { echo "FAIL: auditor prompt artifact should not remain"; exit 1; }
grep -q '## Mission Projection' "$RUN/.last-codex-audit-s__r1-001.raw" || { echo "FAIL: auditor raw missing projection slot"; exit 1; }
[[ -f "$RUN/10-advice-by-claude/s__r1--001-script-fix.md" ]] || { echo "FAIL: advice record missing"; exit 1; }
[[ -f "$RUN/20-audit-by-codex/s__r1--001-script-fix.md" ]] || { echo "FAIL: audit record missing"; exit 1; }
grep -q '^verdict: accepted: looks good$' "$RUN/20-audit-by-codex/s__r1--001-script-fix.md" || { echo "FAIL: accepted audit verdict missing"; exit 1; }
[[ -f "$RUN/index.md" && -f "$RUN/99-summary.md" ]] || { echo "FAIL: index/summary missing"; exit 1; }

echo "PASS: output layout"
