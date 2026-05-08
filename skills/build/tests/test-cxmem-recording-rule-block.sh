#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PROMPT="$ROOT/skills/build/prompts/cxmem-recording-rule-block.md"
trap 'echo "FAIL: cxmem recording rule block contract"; exit 1' ERR

grep -F 'at least one release' "$PROMPT" >/dev/null
grep -F 'Bad literal form' "$PROMPT" >/dev/null
grep -F 'Safe paraphrase form' "$PROMPT" >/dev/null
grep -F 'Safe escaped form' "$PROMPT" >/dev/null
grep -F '<<<END>>>' "$PROMPT" >/dev/null
grep -F '\u003c\u003c\u003cEND\u003e\u003e\u003e' "$PROMPT" >/dev/null
grep -F 'paraphrase' "$PROMPT" >/dev/null
grep -F '<<<CXMEM-RECORD>>>' "$PROMPT" >/dev/null
grep -F '<<<CXMEM-INDEX' "$PROMPT" >/dev/null
grep -F '<<<CXMEM-SUMMARY' "$PROMPT" >/dev/null

echo "PASS: cxmem recording rule block contract"
