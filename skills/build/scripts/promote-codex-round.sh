#!/usr/bin/env bash
# Promotes codex-derived round summaries into session memory under the parent main round.
# Usage: promote-codex-round.sh <sessions-root> <project> <slug> <main-round-seq>
#
# Reads:
#   <sessions-root>/<slug>/rounds/round-<main-round-seq>.md
#   <sessions-root>/<slug>/rounds/round-<main-round-seq>-codex-*-r*.md
# Writes:
#   <sessions-root>/<slug>/session-memory.md
# Stdout:
#   ok: promoted N codex-derived rounds into session-memory.md
# Exit:
#   0 success
#   2 usage / missing-file
#   4 runtime failure
set -euo pipefail

[[ "$#" -eq 4 ]] || { echo "error: usage: promote-codex-round.sh <sessions-root> <project> <slug> <main-round-seq>" >&2; exit 2; }

SESSIONS_ROOT="$1"
PROJECT="$2"
SLUG="$3"
MAIN_ROUND_SEQ="$4"
START_EPOCH="$(date +%s)"

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

SESSION_DIR="$SESSIONS_ROOT/$SLUG"
ROUND_DIR="$SESSION_DIR/rounds"
MAIN_ROUND="$ROUND_DIR/round-${MAIN_ROUND_SEQ}.md"
SESSION_MEMORY="$SESSION_DIR/session-memory.md"

[[ -d "$ROUND_DIR" ]] || { echo "error: rounds dir not found: $ROUND_DIR" >&2; exit 2; }
[[ -f "$MAIN_ROUND" ]] || { echo "error: main round not found: $MAIN_ROUND" >&2; exit 2; }

mapfile -t CODEX_ROUNDS < <(find "$ROUND_DIR" -maxdepth 1 -type f -name "round-${MAIN_ROUND_SEQ}-codex-*-r*.md" -print | sort)

for path in "${CODEX_ROUNDS[@]}"; do
  mtime="$(stat -c %Y "$path")" || { echo "error: failed to stat codex round: $path" >&2; exit 4; }
  if [[ "$mtime" -gt "$START_EPOCH" ]]; then
    echo "error: codex round mtime is in the future relative to promotion start: $path" >&2
    exit 4
  fi
done

mkdir -p "$SESSION_DIR"
if [[ ! -f "$SESSION_MEMORY" ]]; then
  main_summary="$(awk 'NF && $0 !~ /^---$/ { sub(/^# /, ""); print; exit }' "$MAIN_ROUND")"
  [[ -n "$main_summary" ]] || main_summary="Round ${MAIN_ROUND_SEQ}"
  printf -- '- Round %s: %s\n' "$MAIN_ROUND_SEQ" "$main_summary" > "$SESSION_MEMORY"
fi

TMP="$(mktemp "$SESSION_DIR/.session-memory.XXXXXX")"
trap 'rm -f "$TMP" "$TMP.sub"' EXIT

: > "$TMP.sub"
for path in "${CODEX_ROUNDS[@]}"; do
  label="$(basename "$path" .md)"
  label="${label#round-${MAIN_ROUND_SEQ}-}"
  summary="$(awk '
    /^## Summary[[:space:]]*$/ { in_summary=1; next }
    in_summary && /^## / { exit }
    in_summary && NF { print; exit }
  ' "$path")"
  [[ -n "$summary" ]] || summary="No summary emitted."
  printf '  - %s: %s\n' "$label" "$summary" >> "$TMP.sub"
done

if ! awk -v round="$MAIN_ROUND_SEQ" -v subfile="$TMP.sub" '
  BEGIN { inserted=0 }
  {
    print
    if (!inserted && $0 ~ "^- Round " round ":") {
      while ((getline line < subfile) > 0) print line
      close(subfile)
      inserted=1
    }
  }
  END { exit inserted ? 0 : 1 }
' "$SESSION_MEMORY" > "$TMP"; then
  echo "error: parent round bullet not found in session-memory.md" >&2
  exit 4
fi

mv "$TMP" "$SESSION_MEMORY" || { echo "error: failed to update session-memory.md" >&2; exit 4; }
trap - EXIT
echo "ok: promoted ${#CODEX_ROUNDS[@]} codex-derived rounds into session-memory.md"
