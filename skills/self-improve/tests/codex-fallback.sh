#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/run"
mkdir -p "$RUN"
printf '# projection\n' > "$TMP/projection.md"
printf 'advisor text\n' > "$TMP/stub.txt"

## Fallback contract
grep -q 'skills/think/scripts/probe.sh.*codex' "$ROOT/skills/self-improve/scripts/probe-codex.sh" || { echo "FAIL: probe wrapper does not reuse think probe"; exit 1; }
grep -q '\.last-codex-fallback-<role>-<mission_id>-<seq>\.raw' "$ROOT/skills/self-improve/SKILL.md" || { echo "FAIL: fallback raw schema missing in SKILL.md"; exit 1; }
grep -q '\[Codex(fallback)\]' "$ROOT/skills/self-improve/SKILL.md" || { echo "FAIL: fallback label not documented in SKILL.md"; exit 1; }

## Stub bypass
CLAUDEX_SI_STUB_ADVISOR_OUTPUT="$TMP/stub.txt" bash "$ROOT/skills/self-improve/scripts/dispatch-advisor-codex.sh" "$RUN" m__r 001 "$TMP/projection.md" codex any 5 "skills/self-improve/SKILL.md" > "$TMP/out"
grep -q 'advisor text' "$TMP/out" || { echo "FAIL: stub advisor output not returned"; exit 1; }
grep -q 'advisor text' "$RUN/.last-codex-advise-m__r-001.raw" || { echo "FAIL: raw stub output not preserved"; exit 1; }
grep -q 'Advisor side: `codex`' "$RUN/.last-codex-advise-m__r-001.raw" || { echo "FAIL: advisor side slot not filled"; exit 1; }
[[ ! -f "$RUN/.last-codex-advise-m__r-001.prompt" ]] || { echo "FAIL: prompt artifact should not remain"; exit 1; }

if CLAUDEX_SI_STUB_ADVISOR_OUTPUT="$TMP/missing.txt" bash "$ROOT/skills/self-improve/scripts/dispatch-advisor-codex.sh" "$RUN" m__r 002 "$TMP/projection.md" codex any 5 "skills/self-improve/SKILL.md" >/dev/null 2>&1; then
  echo "FAIL: unreadable stub accepted"
  exit 1
fi

echo "PASS: codex fallback"
