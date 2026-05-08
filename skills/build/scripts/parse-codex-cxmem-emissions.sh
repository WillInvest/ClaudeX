#!/usr/bin/env bash
# Parses Codex CXMem sentinel emissions into canonical JSON.
# Usage: parse-codex-cxmem-emissions.sh <codex-log-path>
#
# Reads:
#   <codex-log-path>     raw Codex stdout/stderr log containing CXMem sentinel blocks
# Writes:
#   none
# Stdout:
#   JSON object with records, index, summary, warnings, and extension keys:
#   record_blocks_seen, record_blocks_malformed, degraded_recommended
# Exit:
#   0 success
#   2 usage / missing-file
set -euo pipefail

LOG_PATH="${1:?usage: parse-codex-cxmem-emissions.sh <codex-log-path>}"
[[ "$#" -eq 1 ]] || { echo "error: usage: parse-codex-cxmem-emissions.sh <codex-log-path>" >&2; exit 2; }
[[ -f "$LOG_PATH" ]] || { echo "error: codex log not found: $LOG_PATH" >&2; exit 2; }

WORK_DIR="$(mktemp -d -t claudex-parse-cxmem.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

WARNINGS="$WORK_DIR/warnings.jsonl"
VALID_RECORDS="$WORK_DIR/records.jsonl"
INDEX_FILE="$WORK_DIR/index.md"
SUMMARY_FILE="$WORK_DIR/summary.md"
: > "$WARNINGS"
: > "$VALID_RECORDS"
: > "$INDEX_FILE"
: > "$SUMMARY_FILE"

warn() {
  jq -Rn --arg msg "$1" '$msg' >> "$WARNINGS"
}

is_opening_sentinel() {
  [[ "$1" == "<<<CXMEM-RECORD>>>" ||
     "$1" =~ ^\<\<\<CXMEM-INDEX([[:space:]]+version=\"1\")?\>\>\>$ ||
     "$1" =~ ^\<\<\<CXMEM-SUMMARY([[:space:]]+version=\"1\")?\>\>\>$ ]]
}

sentinel_type() {
  case "$1" in
    "<<<CXMEM-RECORD>>>") echo "record" ;;
    "<<<CXMEM-INDEX"*) echo "index" ;;
    "<<<CXMEM-SUMMARY"*) echo "summary" ;;
  esac
}

record_paths=()
record_blocks_seen=0
current_type=""
current_file=""
block_id=0
any_emission=0

start_block() {
  local line="$1"
  current_type="$(sentinel_type "$line")"
  block_id=$((block_id + 1))
  current_file="$WORK_DIR/block-$block_id.payload"
  : > "$current_file"
  any_emission=1
  if [[ "$current_type" == "record" ]]; then
    record_blocks_seen=$((record_blocks_seen + 1))
  fi
}

finish_block() {
  case "$current_type" in
    record)
      record_paths+=("$current_file")
      ;;
    index)
      cp "$current_file" "$INDEX_FILE"
      ;;
    summary)
      cp "$current_file" "$SUMMARY_FILE"
      ;;
  esac
  current_type=""
  current_file=""
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ -z "$current_type" ]]; then
    if is_opening_sentinel "$line"; then
      start_block "$line"
    elif [[ "$line" == "<<<END>>>" ]]; then
      warn "orphaned end sentinel skipped"
    fi
    continue
  fi

  if [[ "$line" == "<<<END>>>" ]]; then
    finish_block
    continue
  fi

  if is_opening_sentinel "$line"; then
    warn "unterminated $current_type block discarded before new opening sentinel"
    start_block "$line"
    continue
  fi

  printf '%s\n' "$line" >> "$current_file"
done < "$LOG_PATH"

if [[ -n "$current_type" ]]; then
  warn "unterminated $current_type block discarded at end of log"
fi

record_blocks_malformed=0
declare -A seen_record_keys=()
first_valid_round=""

for path in "${record_paths[@]}"; do
  if ! parsed="$(jq -c . "$path" 2>/dev/null)"; then
    warn "malformed record skipped: invalid JSON"
    record_blocks_malformed=$((record_blocks_malformed + 1))
    continue
  fi

  # Future major schema bumps must support the prior major version for at least one release.
  version="$(jq -r '(.version // 1)' <<< "$parsed")"
  if [[ "$version" != "1" ]]; then
    warn "unsupported record version skipped: $version"
    record_blocks_malformed=$((record_blocks_malformed + 1))
    continue
  fi

  missing="$(jq -r '
    . as $obj
    | ["stage","round","seq","tool","plan","tool_summary","findings","next_plan"]
    | map(. as $key | select($obj | has($key) | not))
    | join(",")
  ' <<< "$parsed")"
  if [[ -n "$missing" ]]; then
    warn "malformed record skipped: missing required field(s): $missing"
    record_blocks_malformed=$((record_blocks_malformed + 1))
    continue
  fi

  if ! jq -e '.findings | type == "array"' <<< "$parsed" >/dev/null; then
    warn "malformed record skipped: findings must be an array"
    record_blocks_malformed=$((record_blocks_malformed + 1))
    continue
  fi

  stage="$(jq -r '.stage | tostring' <<< "$parsed")"
  round="$(jq -r '.round | tostring' <<< "$parsed")"
  seq="$(jq -r '.seq | tostring' <<< "$parsed")"
  tool="$(jq -r '.tool | tostring' <<< "$parsed")"
  if [[ -z "$first_valid_round" ]]; then
    first_valid_round="$round"
  elif [[ "$round" != "$first_valid_round" ]]; then
    warn "round-number divergence warning: record round=$round differs from first valid round=$first_valid_round"
  fi
  record_key="${stage}"$'\t'"${round}"$'\t'"${seq}"$'\t'"${tool}"
  if [[ -n "${seen_record_keys[$record_key]+x}" ]]; then
    warn "duplicate record skipped: stage=$stage round=$round seq=$seq tool=$tool"
    continue
  fi
  seen_record_keys[$record_key]=1

  jq -c '.version = (.version // 1)' <<< "$parsed" >> "$VALID_RECORDS"
done

records_count="$(wc -l < "$VALID_RECORDS" | tr -d ' ')"
summary_text="$(cat "$SUMMARY_FILE")"

if [[ "$any_emission" -eq 0 ]]; then
  warn "no CXMem emissions found"
fi
if [[ "$records_count" -eq 0 ]]; then
  warn "missing-record condition: no valid records found"
fi
if [[ -z "$summary_text" ]]; then
  warn "missing-Summary condition: no Summary block found"
fi

degraded=false
if [[ "$records_count" -eq 0 || -z "$summary_text" ]]; then
  degraded=true
elif [[ "$record_blocks_seen" -gt 0 && $((record_blocks_malformed * 2)) -gt "$record_blocks_seen" ]]; then
  degraded=true
fi

jq -s \
  --rawfile index "$INDEX_FILE" \
  --rawfile summary "$SUMMARY_FILE" \
  --slurpfile warnings "$WARNINGS" \
  --argjson seen "$record_blocks_seen" \
  --argjson malformed "$record_blocks_malformed" \
  --argjson degraded "$degraded" \
  '{
    records: .,
    index: $index,
    summary: $summary,
    warnings: $warnings,
    record_blocks_seen: $seen,
    record_blocks_malformed: $malformed,
    degraded_recommended: $degraded
  }' "$VALID_RECORDS"
