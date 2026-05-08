#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/cxmem-rounds-to-transcript.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/sessions/mixed/rounds"
for n in 1 2 4 5; do
  cat > "$TMP/sessions/mixed/rounds/round-$n.md" <<EOF
# Round $n
assistant output $n
EOF
done
printf '\nDISAGREE: verdict 2\n' >> "$TMP/sessions/mixed/rounds/round-2.md"
printf '\nANGLE-MISSED: verdict 4\n' >> "$TMP/sessions/mixed/rounds/round-4.md"
cat > "$TMP/sessions/mixed/rounds/round-3-codex-spec-r1.md" <<'EOF'
# Codex derived
skip me
EOF

bash "$SCRIPT" "$TMP/sessions" mixed > "$TMP/out"

[[ "$(grep -n '^## round-' "$TMP/out" | cut -d: -f2 | paste -sd '|' -)" == "## round-1.md|## round-2.md|## round-4.md|## round-5.md" ]]
! grep -q 'skip me' "$TMP/out"
awk '/assistant output 2/{seen2=1} /\[Codex 2nd opinion\]: DISAGREE: verdict 2/{if (!seen2) exit 1; found2=1} /assistant output 4/{seen4=1} /\[Codex 2nd opinion\]: ANGLE-MISSED: verdict 4/{if (!seen4) exit 1; found4=1} END{exit (found2 && found4)?0:1}' "$TMP/out"

echo "PASS: mixed CXMem projection preserves order and verdict placement"
