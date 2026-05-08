#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PARSER="$ROOT/skills/build/scripts/parse-codex-cxmem-emissions.sh"
WRITER="$ROOT/skills/build/scripts/write-cxmem-round.sh"
FIXTURE="$ROOT/skills/build/tests/fixtures/well-formed-codex.log"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
mkdir -p "$SCRATCH/CXMem/projects/mem/sessions"
trap 'echo "FAIL: integration cxmem round failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

parsed="$SCRATCH/parsed.json"
bash "$PARSER" "$FIXTURE" > "$parsed"
if jq -e '.degraded_recommended == true' "$parsed" >/dev/null; then
  echo "FAIL: fixture unexpectedly recommended degraded mode"
  exit 1
fi

bash "$WRITER" "$SCRATCH/CXMem/projects/mem/sessions" mem "integration-slug" 7 impl 1 "$parsed" >/dev/null
target="$SCRATCH/CXMem/projects/mem/sessions/integration-slug/rounds/round-7-codex-impl-r1.md"

grep -F 'type: round-memory' "$target" >/dev/null
grep -F 'session-id: integration-slug' "$target" >/dev/null
grep -F 'project: mem' "$target" >/dev/null
grep -F 'round: 7' "$target" >/dev/null
grep -F 'created:' "$target" >/dev/null
[[ "$(grep -c '^## Index$' "$target")" -eq 1 ]]
[[ "$(grep -c '^## Records$' "$target")" -eq 1 ]]
[[ "$(grep -c '^## Summary$' "$target")" -eq 1 ]]
grep -E '^### Record 7\.[0-9]+' "$target" >/dev/null
grep -F 'Inspected conventions' "$target" >/dev/null
grep -F 'Codex emitted three structured records' "$target" >/dev/null

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: parser writer cxmem round integration"
