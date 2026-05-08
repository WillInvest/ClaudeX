#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -ge 5 ]] || { echo "error: usage: parse-advisor-proposals.sh <advisor-output-file> <output-dir> <mission_id> <self_improve_run_id> <advisor_model> [--target-kind <kind>] [--max-items <N>]" >&2; exit 2; }

ADVISOR_OUTPUT="$1"
PROPOSALS_DIR="$2"
MISSION_ID="$3"
SELF_IMPROVE_RUN_ID="$4"
ADVISOR_MODEL="$5"
shift 5

TARGET_KIND="any"
MAX_ITEMS="999999"
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --target-kind)
      [[ "$#" -ge 2 ]] || { echo "error: --target-kind requires a value" >&2; exit 2; }
      TARGET_KIND="$2"
      shift 2
      ;;
    --max-items)
      [[ "$#" -ge 2 ]] || { echo "error: --max-items requires a value" >&2; exit 2; }
      MAX_ITEMS="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$ADVISOR_OUTPUT" ]] || { echo "error: advisor output missing: $ADVISOR_OUTPUT" >&2; exit 2; }
[[ "$MAX_ITEMS" =~ ^[0-9]+$ ]] || { echo "error: max-items must be numeric: $MAX_ITEMS" >&2; exit 2; }

mkdir -p "$PROPOSALS_DIR"

python3 - "$ADVISOR_OUTPUT" "$PROPOSALS_DIR" "$MISSION_ID" "$SELF_IMPROVE_RUN_ID" "$ADVISOR_MODEL" "$TARGET_KIND" "$MAX_ITEMS" <<'PY'
import os, re, sys
src, out_dir, mission_id, self_improve_run_id, advisor_model, target_filter, max_items_s = sys.argv[1:]
max_items = int(max_items_s)
text = open(src, "r", encoding="utf-8").read()
allowed_kinds = {"skill-prompt", "recording-protocol", "design-heuristic", "script", "other"}
allowed_changes = {"add", "remove", "replace", "clarify"}
if target_filter != "any" and target_filter not in allowed_kinds:
    sys.stderr.write(f"error: unsupported target-kind flag: {target_filter}\n")
    sys.exit(2)

blocks = re.findall(r"(?s)<<<SI-PROPOSAL>>>\s*(.*?)\s*<<<END-SI-PROPOSAL>>>", text)
written = 0
for block in blocks:
    if written >= max_items:
        break
    if not block.startswith("---\n"):
        continue
    end = block.find("\n---\n", 4)
    if end == -1:
        continue
    fm_text = block[4:end]
    body = block[end + 5:].strip() + "\n"
    fields = {}
    ordered = []
    malformed = False
    for line in fm_text.splitlines():
        if ": " not in line:
            malformed = True
            break
        key, value = line.split(": ", 1)
        fields[key] = value
        ordered.append((key, value))
    if malformed:
        continue
    for key in ("target_kind", "target_path", "target_section", "change_type", "slug"):
        if key not in fields or fields[key] == "":
            malformed = True
    if malformed:
        continue
    if fields["target_kind"] not in allowed_kinds or fields["change_type"] not in allowed_changes:
        continue
    if target_filter != "any" and fields["target_kind"] != target_filter:
        continue
    required_headings = ["## Observation", "## Proposed change", "## Rationale", "## Risk"]
    if re.findall(r"(?m)^## .+$", body) != required_headings:
        malformed = True
    for heading in required_headings:
        if heading not in body:
            malformed = True
    if malformed:
        continue

    written += 1
    filename = f"{mission_id}--{written:03d}-{fields['slug']}.md"
    path = os.path.join(out_dir, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write(f"mission_id: {mission_id}\n")
        f.write(f"self_improve_run_id: {self_improve_run_id}\n")
        f.write(f"advisor_model: {advisor_model}\n")
        f.write(f"target_path: {fields['target_path']}\n")
        f.write(f"target_section: {fields['target_section']}\n")
        f.write(f"target_kind: {fields['target_kind']}\n")
        f.write(f"change_type: {fields['change_type']}\n")
        f.write(f"slug: {fields['slug']}\n")
        f.write("verdict: pending-audit\n")
        f.write("---\n\n")
        f.write(body)
        if not body.endswith("\n\n"):
            f.write("\n")
        f.write("## Audit verdict\n\npending-audit\n")

print(written)
PY
