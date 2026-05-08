#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 7 ]] || { echo "error: usage: parse-auditor-verdict.sh <proposal-file> <auditor-output> <output-dir> <mission-id> <self-improve-run-id> <advisor-model> <auditor-model>" >&2; exit 2; }

PROPOSAL="$1"
AUDITOR_OUTPUT="$2"
OUTPUT_DIR="$3"
MISSION_ID="$4"
SELF_IMPROVE_RUN_ID="$5"
ADVISOR_MODEL="$6"
AUDITOR_MODEL="$7"

[[ -f "$PROPOSAL" ]] || { echo "error: proposal file missing: $PROPOSAL" >&2; exit 2; }
[[ -f "$AUDITOR_OUTPUT" ]] || { echo "error: auditor output missing: $AUDITOR_OUTPUT" >&2; exit 2; }
mkdir -p "$OUTPUT_DIR"

python3 - "$PROPOSAL" "$AUDITOR_OUTPUT" "$OUTPUT_DIR" "$MISSION_ID" "$SELF_IMPROVE_RUN_ID" "$ADVISOR_MODEL" "$AUDITOR_MODEL" <<'PY'
import os, re, sys
proposal, audit_out, output_dir, mission_id, self_improve_run_id, advisor_model, auditor_model = sys.argv[1:]
audit_text = open(audit_out, "r", encoding="utf-8").read()
matches = list(re.finditer(r"(?m)^(ACCEPT|REJECT|REFINE):[ \t]*(.*)$", audit_text))
proposal_text = open(proposal, "r", encoding="utf-8").read()

def split_frontmatter(text):
    if not text.startswith("---\n"):
        raise SystemExit("error: proposal missing frontmatter")
    end = text.find("\n---\n", 4)
    if end == -1:
        raise SystemExit("error: proposal frontmatter not closed")
    return text[4:end].splitlines(), text[end + 5:]

fm_lines, body = split_frontmatter(proposal_text)
if matches:
    token, reason = matches[-1].group(1), matches[-1].group(2).strip()
    token_map = {"ACCEPT": "accepted", "REJECT": "rejected", "REFINE": "refined"}
    verdict_value = f"{token_map[token]}: {reason}"
    rationale = audit_text[:matches[-1].start()].strip()
    verdict_body = verdict_value + "\n\n## Auditor rationale\n\n" + (rationale or "n/a") + "\n"
else:
    token, reason = "DEGRADED", "auditor-no-verdict"
    verdict_value = "degraded:auditor-no-verdict"
    verdict_body = verdict_value + "\n\n## Auditor rationale\n\n" + (audit_text.strip() or "n/a") + "\n"

new_fm = []
seen = False
for line in fm_lines:
    if line.startswith("verdict: "):
        new_fm.append(f"verdict: {verdict_value}")
        seen = True
    else:
        new_fm.append(line)
if not seen:
    new_fm.append(f"verdict: {verdict_value}")

def replace_section(text, heading, replacement):
    pat = re.compile(rf"(?ms)^{re.escape(heading)}\n.*?(?=^## |\Z)")
    new, n = pat.subn(heading + "\n\n" + replacement.rstrip() + "\n\n", text, count=1)
    if n == 0:
        return text.rstrip() + "\n\n" + heading + "\n\n" + replacement.rstrip() + "\n"
    return new.rstrip() + "\n"

if token == "REFINE":
    tail = audit_text[matches[-1].end():]
    refined = tail
    m = re.search(r"(?ms)^## Proposed change\s*\n(.*)$", tail)
    if m:
        refined = m.group(1)
    refined = refined.strip() or reason
    body = replace_section(body, "## Proposed change", refined)
    verdict_body = verdict_body.rstrip() + "\n\n## Refined proposed change\n\n" + refined + "\n"

body = replace_section(body, "## Audit verdict", verdict_body)

with open(proposal, "w", encoding="utf-8") as f:
    f.write("---\n")
    for line in new_fm:
        f.write(line + "\n")
    f.write("---\n")
    f.write(body if body.startswith("\n") else "\n" + body)

audit_path = os.path.join(output_dir, os.path.basename(proposal))
with open(audit_path, "w", encoding="utf-8") as f:
    f.write("---\n")
    f.write(f"mission_id: {mission_id}\n")
    f.write(f"self_improve_run_id: {self_improve_run_id}\n")
    f.write(f"auditor_model: {auditor_model}\n")
    f.write(f"advisor_model: {advisor_model}\n")
    f.write(f"proposal_path: {os.path.basename(proposal)}\n")
    f.write(f"verdict: {verdict_value}\n")
    f.write("---\n\n")
    f.write(verdict_body)

print(verdict_value)
PY
