#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/skills/build/SKILL.md"
RULE="$ROOT/skills/build/prompts/cxmem-recording-rule-block.md"
SENTINEL="<<<CXMEM-RECORD>>>"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

build_prompt() {
  local state="$1"
  local template="$2"
  local out="$3"
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/probe-cxmem-host.sh" <<SH
#!/usr/bin/env bash
echo "$state"
SH
  chmod +x "$TMP/bin/probe-cxmem-host.sh"
  local probe
  probe="$(PATH="$TMP/bin:$PATH" probe-cxmem-host.sh)"
  local block=""
  if [[ "$probe" == "CXMEM_HOST_PROJECT_READY" ]]; then
    block="$(cat "$RULE")"
  fi
  python3 - "$template" "$out" "$block" <<'PY'
import sys
template, out, block = sys.argv[1:]
text = open(template, encoding="utf-8").read()
replacements = {
    "{{recording_rule_block}}": block,
    "{{spec_contents}}": "spec",
    "{{patterns_from_claude_md_or_files}}": "patterns",
    "{{clarifications_or_none}}": "none",
    "{{relevant_files_inline}}": "files",
    "{{plan_contents}}": "plan",
    "{{files_may_modify_list}}": "allowed",
    "{{files_out_of_scope_list}}": "oos",
    "{{gotchas_or_none}}": "none",
    "{{DECISIONS}}": "decisions",
    "{{APPROACHES}}": "approaches",
    "{{DESIGN}}": "design",
    "{{CANONICAL_SPEC_PATH}}": "/tmp/spec.md",
    "{{adaptive_context}}": "adaptive",
}
for key, value in replacements.items():
    text = text.replace(key, value)
open(out, "w", encoding="utf-8").write(text)
PY
}

for prompt in "$ROOT/skills/build/spec-codex-prompt.md" "$ROOT/skills/build/plan-codex-prompt.md" "$ROOT/skills/build/impl-codex-prompt.md"; do
  grep -q '{{recording_rule_block}}' "$prompt" || { echo "FAIL: missing recording placeholder in $prompt"; exit 1; }
  ready_out="$TMP/$(basename "$prompt").ready"
  sessionless_out="$TMP/$(basename "$prompt").sessionless"
  missing_out="$TMP/$(basename "$prompt").missing"
  build_prompt CXMEM_HOST_PROJECT_READY "$prompt" "$ready_out"
  build_prompt CXMEM_HOST_PROJECT_NO_SESSION "$prompt" "$sessionless_out"
  build_prompt CXMEM_HOST_MISSING "$prompt" "$missing_out"
  [[ "$(grep -c "$SENTINEL" "$ready_out" || true)" -ge 1 ]] || { echo "FAIL: sentinel missing in ready prompt $prompt"; exit 1; }
  [[ "$(grep -c "$SENTINEL" "$sessionless_out" || true)" -eq 0 ]] || { echo "FAIL: sentinel leaked in sessionless prompt $prompt"; exit 1; }
  [[ "$(grep -c "$SENTINEL" "$missing_out" || true)" -eq 0 ]] || { echo "FAIL: sentinel leaked in missing prompt $prompt"; exit 1; }
done

grep -q 'parse-codex-cxmem-emissions.sh "$CODEX_LOG"' "$SKILL"
grep -q 'write-cxmem-round.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND"' "$SKILL"
grep -q 'degraded_recommended == true' "$SKILL"

echo "PASS: SPEC PLAN IMPLEMENT prompts splice CXMem recording rule only when probe is ready"
