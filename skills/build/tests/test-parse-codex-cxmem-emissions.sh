#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/parse-codex-cxmem-emissions.sh"
FIXTURE="$ROOT/skills/build/tests/fixtures/well-formed-codex.log"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
mkdir -p "$SCRATCH"
trap 'echo "FAIL: parse-codex-cxmem-emissions failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

parsed="$SCRATCH/well.json"
bash "$SCRIPT" "$FIXTURE" > "$parsed"
jq -e '.records | length == 3' "$parsed" >/dev/null
jq -e '.index | contains("Inspected conventions")' "$parsed" >/dev/null
jq -e '.summary | contains("three structured records")' "$parsed" >/dev/null
jq -e '.degraded_recommended == false' "$parsed" >/dev/null

cat > "$SCRATCH/malformed-middle.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"stage":"impl","round":1,"seq":1,"tool":"Read","plan":"p","tool_summary":"s","findings":[],"next_plan":"n"}
<<<END>>>
<<<CXMEM-RECORD>>>
{"stage":
<<<END>>>
<<<CXMEM-RECORD>>>
{"stage":"impl","round":1,"seq":3,"tool":"Bash","plan":"p","tool_summary":"s","findings":["ok"],"next_plan":"n"}
<<<END>>>
<<<CXMEM-SUMMARY>>>
summary
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/malformed-middle.log" > "$SCRATCH/malformed-middle.json"
jq -e '.records | length == 2' "$SCRATCH/malformed-middle.json" >/dev/null
jq -e '.warnings | length == 1' "$SCRATCH/malformed-middle.json" >/dev/null

: > "$SCRATCH/empty.log"
bash "$SCRIPT" "$SCRATCH/empty.log" > "$SCRATCH/empty.json"
jq -e '.records == [] and .degraded_recommended == true' "$SCRATCH/empty.json" >/dev/null
jq -e 'any(.warnings[]; contains("no CXMem emissions"))' "$SCRATCH/empty.json" >/dev/null

cat > "$SCRATCH/no-summary.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"stage":"impl","round":2,"seq":1,"tool":"Read","plan":"p","tool_summary":"s","findings":[],"next_plan":"n"}
<<<END>>>
<<<CXMEM-INDEX>>>
index
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/no-summary.log" > "$SCRATCH/no-summary.json"
jq -e '.records | length == 1' "$SCRATCH/no-summary.json" >/dev/null
jq -e '.degraded_recommended == true' "$SCRATCH/no-summary.json" >/dev/null
jq -e 'any(.warnings[]; contains("missing-Summary"))' "$SCRATCH/no-summary.json" >/dev/null

cat > "$SCRATCH/batch-missing-version.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"stage":"impl","round":3,"seq":1,"tool":"Edit x 3","plan":"p","tool_summary":"s","findings":["f"],"next_plan":"n"}
<<<END>>>
<<<CXMEM-SUMMARY>>>
summary
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/batch-missing-version.log" > "$SCRATCH/batch-missing-version.json"
jq -e '.records[0].tool == "Edit x 3" and .records[0].version == 1' "$SCRATCH/batch-missing-version.json" >/dev/null

cat > "$SCRATCH/future-version.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"version":2,"stage":"impl","round":4,"seq":1,"tool":"Read","plan":"p","tool_summary":"s","findings":[],"next_plan":"n"}
<<<END>>>
<<<CXMEM-SUMMARY>>>
summary
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/future-version.log" > "$SCRATCH/future-version.json"
jq -e '.records | length == 0' "$SCRATCH/future-version.json" >/dev/null
jq -e 'any(.warnings[]; contains("unsupported record version"))' "$SCRATCH/future-version.json" >/dev/null

cat > "$SCRATCH/unterminated.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"stage":"impl","round":5,"seq":1,"tool":"Read","plan":"bad","tool_summary":"bad","findings":[],"next_plan":"bad"}
<<<CXMEM-RECORD>>>
{"stage":"impl","round":5,"seq":2,"tool":"Read","plan":"p","tool_summary":"s","findings":[],"next_plan":"n"}
<<<END>>>
<<<CXMEM-SUMMARY>>>
summary
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/unterminated.log" > "$SCRATCH/unterminated.json"
jq -e '.records | length == 1' "$SCRATCH/unterminated.json" >/dev/null
jq -e '.records[0].seq == 2' "$SCRATCH/unterminated.json" >/dev/null
jq -e 'any(.warnings[]; contains("unterminated"))' "$SCRATCH/unterminated.json" >/dev/null

cat > "$SCRATCH/threshold.log" <<'EOF'
<<<CXMEM-RECORD>>>
{"stage":
<<<END>>>
<<<CXMEM-RECORD>>>
{"stage":
<<<END>>>
<<<CXMEM-RECORD>>>
{"stage":"impl","round":6,"seq":3,"tool":"Read","plan":"p","tool_summary":"s","findings":[],"next_plan":"n"}
<<<END>>>
<<<CXMEM-SUMMARY>>>
summary
<<<END>>>
EOF
bash "$SCRIPT" "$SCRATCH/threshold.log" > "$SCRATCH/threshold.json"
jq -e '.record_blocks_seen == 3 and .record_blocks_malformed == 2 and .degraded_recommended == true' "$SCRATCH/threshold.json" >/dev/null

for field in stage round seq tool plan tool_summary findings next_plan; do
  jq -n --arg field "$field" '
    {
      stage:"impl", round:8, seq:1, tool:"Read", plan:"p",
      tool_summary:"s", findings:["f"], next_plan:"n"
    } | del(.[$field])
  ' > "$SCRATCH/omit-$field.json"
  {
    echo '<<<CXMEM-RECORD>>>'
    cat "$SCRATCH/omit-$field.json"
    echo '<<<END>>>'
    echo '<<<CXMEM-SUMMARY>>>'
    echo 'summary'
    echo '<<<END>>>'
  } > "$SCRATCH/omit-$field.log"
  bash "$SCRIPT" "$SCRATCH/omit-$field.log" > "$SCRATCH/omit-$field.out"
  jq -e --arg field "$field" '.records | length == 0' "$SCRATCH/omit-$field.out" >/dev/null
  jq -e --arg field "$field" 'any(.warnings[]; contains($field))' "$SCRATCH/omit-$field.out" >/dev/null
done

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: codex cxmem emission parser cases"
