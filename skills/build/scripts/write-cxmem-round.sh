#!/usr/bin/env bash
# Writes a CXMem round-memory file from parsed Codex emissions.
# Usage: write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> <parsed-json-path> --prompt <path> --clean-output <path> (--reviewer-review <path>|--reviewer-skipped <summary>|--reviewer-unavailable <reason>)
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

[[ "$#" -ge 7 ]] || {
  echo "error: usage: write-cxmem-round.sh <sessions-root> <project> <slug> <main-round-seq> <stage> <codex-round-n> <parsed-json-path> --prompt <path> --clean-output <path> (--reviewer-review <path>|--reviewer-skipped <summary>|--reviewer-unavailable <reason>)" >&2
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

PROMPT_PATH=""
CLEAN_OUTPUT_PATH=""
REVIEWER_MODE=""
REVIEWER_VALUE=""

if [[ "$7" == "--degraded" ]]; then
  [[ "$#" -eq 9 ]] || { echo "error: usage: --degraded requires <codex-log-path> <git-diff-path>" >&2; exit 2; }
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
  shift 7
  if [[ "$#" -eq 0 ]]; then
    PROMPT_PATH="/dev/null"
    CLEAN_OUTPUT_PATH="/dev/null"
    REVIEWER_MODE="unavailable"
    REVIEWER_VALUE="reviewer artifact unavailable (legacy writer call)"
  fi
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --prompt)
        [[ "$#" -ge 2 ]] || { echo "error: --prompt requires a path" >&2; exit 2; }
        PROMPT_PATH="$2"
        shift 2
        ;;
      --clean-output)
        [[ "$#" -ge 2 ]] || { echo "error: --clean-output requires a path" >&2; exit 2; }
        CLEAN_OUTPUT_PATH="$2"
        shift 2
        ;;
      --reviewer-review)
        [[ "$#" -ge 2 ]] || { echo "error: --reviewer-review requires a path" >&2; exit 2; }
        [[ -z "$REVIEWER_MODE" ]] || { echo "error: exactly one reviewer flag is required" >&2; exit 2; }
        REVIEWER_MODE="review"
        REVIEWER_VALUE="$2"
        shift 2
        ;;
      --reviewer-skipped)
        [[ "$#" -ge 2 ]] || { echo "error: --reviewer-skipped requires a summary" >&2; exit 2; }
        [[ -z "$REVIEWER_MODE" ]] || { echo "error: exactly one reviewer flag is required" >&2; exit 2; }
        REVIEWER_MODE="skipped"
        REVIEWER_VALUE="$2"
        shift 2
        ;;
      --reviewer-unavailable)
        [[ "$#" -ge 2 ]] || { echo "error: --reviewer-unavailable requires a reason" >&2; exit 2; }
        [[ -z "$REVIEWER_MODE" ]] || { echo "error: exactly one reviewer flag is required" >&2; exit 2; }
        REVIEWER_MODE="unavailable"
        REVIEWER_VALUE="$2"
        shift 2
        ;;
      *)
        echo "error: unknown argument: $1" >&2
        exit 2
        ;;
    esac
  done
  [[ -n "$PROMPT_PATH" ]] || { echo "error: --prompt is required in normal mode" >&2; exit 2; }
  [[ -n "$CLEAN_OUTPUT_PATH" ]] || { echo "error: --clean-output is required in normal mode" >&2; exit 2; }
  [[ -n "$REVIEWER_MODE" ]] || { echo "error: exactly one reviewer flag is required" >&2; exit 2; }
  [[ -r "$PROMPT_PATH" ]] || { echo "error: prompt not found: $PROMPT_PATH" >&2; exit 2; }
  [[ -r "$CLEAN_OUTPUT_PATH" ]] || { echo "error: clean output not found: $CLEAN_OUTPUT_PATH" >&2; exit 2; }
  if [[ "$REVIEWER_MODE" == "review" ]]; then
    [[ -f "$REVIEWER_VALUE" ]] || { echo "error: reviewer review not found: $REVIEWER_VALUE" >&2; exit 2; }
    if ! grep -Eq '^(ready-to-execute|fix-and-proceed|re-review-needed|escalate)\b.*$' "$REVIEWER_VALUE"; then
      echo "error: reviewer review has no verdict line: $REVIEWER_VALUE" >&2
      exit 2
    fi
  fi
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
  python3 - "$PARSED_JSON_PATH" "$PROMPT_PATH" "$CLEAN_OUTPUT_PATH" "$REVIEWER_MODE" "$REVIEWER_VALUE" "$TMP" "$SLUG" "$PROJECT" "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND_N" "$CREATED" <<'PY'
import json
import re
import sys

parsed_path, prompt_path, output_path, reviewer_mode, reviewer_value, target, slug, project, main_round, stage, codex_round, created = sys.argv[1:]

with open(parsed_path, "r", encoding="utf-8") as f:
    parsed = json.load(f)

def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def first_nonempty(text):
    for line in text.splitlines():
        if line.strip():
            return line
    return ""

def fence_for(text):
    longest = 0
    for line in text.splitlines():
        match = re.match(r"^(`{3,})", line)
        if match:
            longest = max(longest, len(match.group(1)))
    return "`" * max(3, longest + 1)

def fenced_block(text):
    fence = fence_for(text)
    block = fence + "\n" + text
    if not block.endswith("\n"):
        block += "\n"
    return block + fence + "\n"

summary = parsed.get("summary", "")
summary_line = first_nonempty(summary) or "Codex CXMem emissions"
prompt = read_text(prompt_path)
clean_output = read_text(output_path)

if reviewer_mode == "review":
    review = read_text(reviewer_value)
    verdict = ""
    for line in review.splitlines():
        if re.match(r"^(ready-to-execute|fix-and-proceed|re-review-needed|escalate)\b.*$", line):
            verdict = line
            break
    reviewer = verdict + "\n\n" + review
    if not reviewer.endswith("\n"):
        reviewer += "\n"
elif reviewer_mode == "skipped":
    reviewer = f"skipped: {reviewer_value}\n"
elif reviewer_mode == "unavailable":
    reviewer = f"unavailable: {reviewer_value}\n"
else:
    print("error: exactly one reviewer flag is required", file=sys.stderr)
    sys.exit(2)

round_warnings = []
parts = [
    "---\n",
    "type: round-memory\n",
    f"session-id: {slug}\n",
    f"project: {project}\n",
    f"round: {main_round}\n",
    f"created: {created}\n",
    "---\n\n",
    f"# Round {main_round} codex-{stage}-r{codex_round} — {summary_line}\n\n",
    "## Codex prompt (rendered)\n\n",
    fenced_block(prompt),
    "\n## Codex output (verbatim)\n\n",
    fenced_block(clean_output),
    "\n## Reviewer 2nd-opinion\n\n",
    reviewer,
    "\n## Index\n\n",
    parsed.get("index", ""),
    "\n## Records\n\n",
]

for record in parsed.get("records", []):
    seq = str(record.get("seq", ""))
    emitted_round = str(record.get("round", ""))
    parts.extend([
        f"### Record {main_round}.{seq} — {record.get('tool_summary', '')}\n\n",
        f"- **Plan**: {record.get('plan', '')}\n",
        f"- **Tool**: {record.get('tool', '')}\n",
        "- **Findings**:\n",
    ])
    for finding in record.get("findings", []):
        parts.append(f"  - {finding}\n")
    parts.append(f"- **Next plan**: {record.get('next_plan', '')}\n\n")
    if emitted_round != str(main_round):
        round_warnings.append(f"codex-emitted round={emitted_round} differs from orchestrator round={main_round}")

parts.extend(["## Summary\n\n", summary, "\n"])
warnings = list(parsed.get("warnings", [])) + round_warnings
if warnings:
    parts.append("Parser warnings:\n")
    for warning in warnings:
        parts.append(f"- {warning}\n")

with open(target, "w", encoding="utf-8", newline="") as f:
    f.write("".join(parts))
PY
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
