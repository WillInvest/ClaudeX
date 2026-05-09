#!/usr/bin/env bash
# Appends deferred Round close blocks to codex-derived round files.
# Usage: append-codex-round-close.sh <sessions-root> <project> <slug> <main-round-seq>
#
# Writes:
#   <sessions-root>/<slug>/rounds/round-<main-round-seq>-codex-*-r*.md
# Stdout:
#   ok: appended Round close to N codex rounds (M unchanged) | ok: unchanged
# Exit:
#   0 success
#   2 usage / missing-file
#   4 runtime failure
set -euo pipefail

[[ "$#" -eq 4 ]] || { echo "error: usage: append-codex-round-close.sh <sessions-root> <project> <slug> <main-round-seq>" >&2; exit 2; }

SESSIONS_ROOT="$1"
PROJECT="$2"
SLUG="$3"
MAIN_ROUND_SEQ="$4"

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

ROUND_DIR="$SESSIONS_ROOT/$SLUG/rounds"
[[ -d "$ROUND_DIR" ]] || { echo "error: rounds dir not found: $ROUND_DIR" >&2; exit 2; }

mapfile -t CODEX_ROUNDS < <(find "$ROUND_DIR" -maxdepth 1 -type f -name "round-${MAIN_ROUND_SEQ}-codex-*-r*.md" -print | sort)

if [[ "${#CODEX_ROUNDS[@]}" -eq 0 ]]; then
  echo "ok: unchanged"
  exit 0
fi

appended=0
unchanged=0

for path in "${CODEX_ROUNDS[@]}"; do
  tmp="$(mktemp "$(dirname "$path")/.append-close.XXXXXX")"
  if python3 - "$path" "$tmp" <<'PY'
import re
import sys

source, target = sys.argv[1:]
with open(source, "r", encoding="utf-8") as f:
    text = f.read()

def scan_markdown(mode, name=""):
    in_fence = False
    fence = ""
    in_section = False
    lines = []
    for line in text.splitlines(keepends=True):
        stripped = line.rstrip("\n")
        fence_match = re.match(r"^(`{3,})(.*)$", stripped)
        if fence_match:
            ticks = fence_match.group(1)
            if not in_fence:
                in_fence = True
                fence = ticks
            elif len(ticks) >= len(fence):
                in_fence = False
                fence = ""
            if mode == "has_round_close":
                continue
        if mode == "has_round_close":
            if not in_fence and re.match(r"^## Round close[ \t]*$", stripped):
                return True
            continue
        if not in_fence and re.match(r"^## [^\n]*$", stripped):
            heading = stripped[3:].strip()
            if heading == name:
                in_section = True
                lines = []
                continue
            if in_section:
                break
        elif in_section:
            lines.append(line)
    if mode == "has_round_close":
        return False
    return "".join(lines)

def section_body(name):
    return scan_markdown("section", name)

def has_top_level_round_close():
    return scan_markdown("has_round_close")

def first_nonempty(body):
    for line in body.splitlines():
        if line.strip():
            return line
    return ""

def first_content_line(body):
    for line in body.splitlines():
        if line.strip():
            return line
    return ""

if has_top_level_round_close():
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    sys.exit(3)

summary_line = first_nonempty(section_body("Summary")) or "No summary emitted."
reviewer_line = first_content_line(section_body("Reviewer 2nd-opinion"))

pieces = [summary_line]
if reviewer_line:
    pieces.append(reviewer_line)
if reviewer_line.startswith("skipped:"):
    pieces.append("fix accepted under stage protocol")
elif reviewer_line.startswith("unavailable:"):
    pieces.append("reviewer unavailable: " + reviewer_line[len("unavailable:"):].lstrip())

rendered = text.rstrip("\n") + "\n\n## Round close\n\n" + " ".join(pieces) + "\n"
with open(target, "w", encoding="utf-8", newline="") as f:
    f.write(rendered)
PY
  then
    :
  else
    status=$?
    if [[ "$status" -eq 3 ]]; then
      unchanged=$((unchanged + 1))
      rm -f "$tmp"
      continue
    fi
    rm -f "$tmp"
    echo "error: failed to render Round close for: $path" >&2
    exit 4
  fi

  if cmp -s "$tmp" "$path"; then
    unchanged=$((unchanged + 1))
    rm -f "$tmp"
    continue
  fi

  mv -f "$tmp" "$path" || { rm -f "$tmp"; echo "error: failed to write Round close: $path" >&2; exit 4; }
  appended=$((appended + 1))
done

if [[ "$appended" -eq 0 ]]; then
  echo "ok: unchanged"
else
  echo "ok: appended Round close to $appended codex rounds ($unchanged unchanged)"
fi
