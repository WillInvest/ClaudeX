#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/cxmem-rounds-to-transcript.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/sessions/demo/rounds"

bash "$SCRIPT" "$TMP/sessions" "demo" > "$TMP/empty"
[[ ! -s "$TMP/empty" ]] || { echo "FAIL: empty rounds dir should produce empty success"; exit 1; }

cat > "$TMP/sessions/demo/rounds/round-10.md" <<'EOF'
# Round 10
user prompt ten
assistant output ten
## Index
omit index
## Records
omit records
## Tool details
omit tool details
## Summary
summary ten
EOF
cat > "$TMP/sessions/demo/rounds/round-2.md" <<'EOF'
# Round 2
assistant output two
AGREE: verdict two
EOF
cat > "$TMP/sessions/demo/rounds/round-3-codex-plan-r1.md" <<'EOF'
# Codex derived
must not appear
EOF
cat > "$TMP/sessions/demo/rounds/round-1.md" <<'EOF'
# Round 1
assistant output one
EOF

bash "$SCRIPT" "$TMP/sessions" "demo" > "$TMP/out"

grep -q 'round-1.md' "$TMP/out"
grep -q 'round-2.md' "$TMP/out"
grep -q 'round-10.md' "$TMP/out"
! grep -q 'must not appear' "$TMP/out"
! grep -q 'omit index' "$TMP/out"
! grep -q 'omit records' "$TMP/out"
! grep -q 'omit tool details' "$TMP/out"
grep -q 'user prompt ten' "$TMP/out"
grep -q 'assistant output ten' "$TMP/out"
[[ "$(grep -n 'round-1.md\|round-2.md\|round-10.md' "$TMP/out" | cut -d: -f2 | paste -sd '|' -)" == "## round-1.md|## round-2.md|## round-10.md" ]]
awk '/assistant output two/{seen=1} /\[Codex 2nd opinion\]: AGREE: verdict two/{if (!seen) exit 1; found=1} END{exit found?0:1}' "$TMP/out"

ALT="$TMP/non-default"
mkdir -p "$ALT/other/rounds"
cat > "$ALT/other/rounds/round-1.md" <<'EOF'
# Round 1
other root works
EOF
bash "$SCRIPT" "$ALT" "other" > "$TMP/non-default-out"
grep -q 'other root works' "$TMP/non-default-out"

echo "PASS: cxmem projection orders main rounds, skips codex-derived, omits detail, includes verdicts"
