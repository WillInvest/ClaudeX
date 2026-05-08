#!/usr/bin/env bash
# Writes a CXMem round-memory file from parsed Codex emissions.
# Usage: write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> <parsed-json-path>
#        write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> --degraded <codex-log-path> <git-diff-path>
#
# Reads:
#   <parsed-json-path>     parser JSON for normal mode
#   <codex-log-path>       raw Codex log for degraded mode
#   <git-diff-path>        git diff text for degraded mode
# Writes:
#   <sessions-root>/<slug>/rounds/round-<main-round-seq>-codex-<stage>-r<codex-round-n>.md
# Stdout:
#   ok: wrote <target> | ok: unchanged <target>
# Exit:
#   0 success
#   2 usage / missing-file
#   4 runtime failure
set -euo pipefail

[[ "$#" -eq 7 || "$#" -eq 9 ]] || {
  echo "error: usage: write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> <parsed-json-path>" >&2
  echo "error: usage: write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> --degraded <codex-log-path> <git-diff-path>" >&2
  exit 2
}

SESSIONS_ROOT="$1"
PROJECT="$2"
SLUG="$3"
MAIN_ROUND_SEQ="$4"
STAGE="$5"
CODEX_ROUND_N="$6"
MODE="normal"

[[ -d "$SESSIONS_ROOT" ]] || { echo "error: sessions root not found: $SESSIONS_ROOT" >&2; exit 2; }
if [[ ! "$PROJECT" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ || "$PROJECT" == *..* || "$PROJECT" == */* ]]; then
  echo "error: invalid project: $PROJECT" >&2
  exit 2
fi
sessions_real="$(realpath "$SESSIONS_ROOT")" || { echo "error: cannot resolve sessions root: $SESSIONS_ROOT" >&2; exit 4; }
case "$sessions_real" in
  */projects/"$PROJECT"/sessions) ;;
  *) echo "error: sessions root is outside projects/$PROJECT/sessions: $SESSIONS_ROOT" >&2; exit 2 ;;
esac

if [[ "$#" -eq 9 ]]; then
  [[ "$7" == "--degraded" ]] || { echo "error: expected --degraded as seventh argument" >&2; exit 2; }
  MODE="degraded"
  CODEX_LOG_PATH="$8"
  GIT_DIFF_PATH="$9"
  [[ -f "$CODEX_LOG_PATH" ]] || { echo "error: codex log not found: $CODEX_LOG_PATH" >&2; exit 2; }
  [[ -f "$GIT_DIFF_PATH" ]] || { echo "error: git diff not found: $GIT_DIFF_PATH" >&2; exit 2; }
else
  PARSED_JSON_PATH="$7"
  [[ -f "$PARSED_JSON_PATH" ]] || { echo "error: parsed JSON not found: $PARSED_JSON_PATH" >&2; exit 2; }
  jq -e '.records and .index and .summary and .warnings' "$PARSED_JSON_PATH" >/dev/null || {
    echo "error: parsed JSON missing required keys: $PARSED_JSON_PATH" >&2
    exit 2
  }
fi

ROUND_DIR="$SESSIONS_ROOT/$SLUG/rounds"
mkdir -p "$ROUND_DIR"
TARGET="$ROUND_DIR/round-${MAIN_ROUND_SEQ}-codex-${STAGE}-r${CODEX_ROUND_N}.md"
CREATED="$(date +%F)"
TMP="$(mktemp "$ROUND_DIR/.round-${MAIN_ROUND_SEQ}-codex-${STAGE}-r${CODEX_ROUND_N}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

first_nonempty_line() {
  awk 'NF { print; exit }' "$1"
}

render_normal() {
  local summary_line
  local summary_tmp="$ROUND_DIR/.summary-source.$$"
  jq -r '.summary' "$PARSED_JSON_PATH" > "$summary_tmp"
  summary_line="$(first_nonempty_line "$summary_tmp")"
  rm -f "$summary_tmp"
  [[ -n "$summary_line" ]] || summary_line="Codex CXMem emissions"

  {
    printf '%s\n' '---'
    printf 'type: round-memory\n'
    printf 'session-id: %s\n' "$SLUG"
    printf 'project: %s\n' "$PROJECT"
    printf 'round: %s\n' "$MAIN_ROUND_SEQ"
    printf 'created: %s\n' "$CREATED"
    printf '%s\n\n' '---'
    printf '# Round %s codex-%s-r%s — %s\n\n' "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND_N" "$summary_line"
    printf '## Index\n\n'
    jq -r '.index' "$PARSED_JSON_PATH"
    printf '\n## Records\n\n'
  } > "$TMP"

  local count
  count="$(jq '.records | length' "$PARSED_JSON_PATH")"
  local i
  for ((i = 0; i < count; i++)); do
    local seq plan tool next_plan emitted_round tool_summary
    seq="$(jq -r --argjson i "$i" '.records[$i].seq' "$PARSED_JSON_PATH")"
    plan="$(jq -r --argjson i "$i" '.records[$i].plan' "$PARSED_JSON_PATH")"
    tool="$(jq -r --argjson i "$i" '.records[$i].tool' "$PARSED_JSON_PATH")"
    tool_summary="$(jq -r --argjson i "$i" '.records[$i].tool_summary' "$PARSED_JSON_PATH")"
    next_plan="$(jq -r --argjson i "$i" '.records[$i].next_plan' "$PARSED_JSON_PATH")"
    emitted_round="$(jq -r --argjson i "$i" '.records[$i].round' "$PARSED_JSON_PATH")"
    {
      printf '### Record %s.%s — %s\n\n' "$MAIN_ROUND_SEQ" "$seq" "$tool_summary"
      printf -- '- **Plan**: %s\n' "$plan"
      printf -- '- **Tool**: %s\n' "$tool"
      printf -- '- **Findings**:\n'
      jq -r --argjson i "$i" '.records[$i].findings[] | "  - " + tostring' "$PARSED_JSON_PATH"
      printf -- '- **Next plan**: %s\n\n' "$next_plan"
      if [[ "$emitted_round" != "$MAIN_ROUND_SEQ" ]]; then
        printf 'codex-emitted round=%s differs from orchestrator round=%s\n' "$emitted_round" "$MAIN_ROUND_SEQ" >> "$ROUND_DIR/.round-mismatch-warnings.$$"
      fi
    } >> "$TMP"
  done

  {
    printf '## Summary\n\n'
    jq -r '.summary' "$PARSED_JSON_PATH"
    printf '\n'
    if [[ -s "$ROUND_DIR/.round-mismatch-warnings.$$" || "$(jq '.warnings | length' "$PARSED_JSON_PATH")" -gt 0 ]]; then
      printf 'Parser warnings:\n'
      jq -r '.warnings[] | "- " + .' "$PARSED_JSON_PATH"
      if [[ -s "$ROUND_DIR/.round-mismatch-warnings.$$" ]]; then
        while IFS= read -r warning; do
          printf -- '- %s\n' "$warning"
        done < "$ROUND_DIR/.round-mismatch-warnings.$$"
      fi
    fi
  } >> "$TMP"
  rm -f "$ROUND_DIR/.round-mismatch-warnings.$$"
}

render_degraded() {
  local diff_stat
  diff_stat="$(grep -E '^( [^|]+ \| |[0-9]+ files? changed)' "$GIT_DIFF_PATH" || true)"
  [[ -n "$diff_stat" ]] || diff_stat="No diff stat available."
  {
    printf '%s\n' '---'
    printf 'type: round-memory\n'
    printf 'session-id: %s\n' "$SLUG"
    printf 'project: %s\n' "$PROJECT"
    printf 'round: %s\n' "$MAIN_ROUND_SEQ"
    printf 'created: %s\n' "$CREATED"
    printf '%s\n\n' '---'
    printf '# Round %s codex-%s-r%s — degraded Codex CXMem fallback\n\n' "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND_N"
    printf '## Index\n\n'
    printf '| ID | Summary | Source |\n'
    printf '|---|---|---|\n'
    printf '| %s.1 | Degraded Codex execution record | %s |\n\n' "$MAIN_ROUND_SEQ" "$CODEX_LOG_PATH"
    printf '## Records\n\n'
    printf '### Record %s.1 — codex exec fallback\n\n' "$MAIN_ROUND_SEQ"
    printf -- '- **Plan**: Preserve Codex audit trail after parser degradation recommendation.\n'
    printf -- '- **Tool**: codex exec\n'
    printf -- '- **Findings**:\n'
    printf '  - Fallback was used because structured CXMem emissions were degraded.\n'
    printf '  - Raw log path: %s\n' "$CODEX_LOG_PATH"
    while IFS= read -r line; do
      printf '  - Diff stat: %s\n' "$line"
    done <<< "$diff_stat"
    printf -- '- **Next plan**: Review raw log and diff before relying on this round memory.\n\n'
    printf '## Summary\n\n'
    printf 'Fallback was used for this Codex round. Raw log path: `%s`.\n\n' "$CODEX_LOG_PATH"
    printf 'Log tail:\n\n'
    printf '```text\n'
    tail -40 "$CODEX_LOG_PATH"
    printf '\n```\n\n'
    printf 'Diff stat:\n\n'
    printf '```text\n%s\n```\n' "$diff_stat"
  } > "$TMP"
}

if [[ "$MODE" == "normal" ]]; then
  render_normal
else
  render_degraded
fi

if [[ -f "$TARGET" ]] && cmp -s "$TMP" "$TARGET"; then
  rm -f "$TMP"
  trap - EXIT
  echo "ok: unchanged $TARGET"
  exit 0
fi

mv "$TMP" "$TARGET" || { echo "error: failed to write round memory: $TARGET" >&2; exit 4; }
trap - EXIT
echo "ok: wrote $TARGET"
