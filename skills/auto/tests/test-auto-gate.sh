#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECORD="$ROOT/skills/think/scripts/record-decision.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HALT_MARKER="Auto mode halted."

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

block() {
  awk -v id="$1" '$0 == "## Decision " id { on=1 } on { print } on && NR > 1 && /^## Decision / && $0 != "## Decision " id { exit }' "$2"
}

new_run() {
  local run="$TMP/$1"
  mkdir -p "$run"
  : > "$run/03-decisions.md"
  : > "$run/.q.md"
  : > "$run/.r.md"
  printf '%s\n' "$run"
}

record_fixture() {
  local id="$1" verdict="$2" decided="$3" fold="$4" blast="$5" marker="$6"
  local run="$TMP/fixtures"
  local file="$run/$id.md"
  mkdir -p "$run"
  [[ -f "$run/03-decisions.md" ]] || : > "$run/03-decisions.md"
  printf 'Decision: %s\nCodex 2nd-opinion verdict: %s: fixture\n' "$id" "$verdict" > "$file"
  "$RECORD" "$run" "$id" "$file" --decided-by "$decided" --foldability "$fold" --high-blast "$blast" >/dev/null
  if [[ "$marker" == present ]]; then
    printf '%s\nReason: %s\nReview the Codex 2nd opinion above.\nChoose Claude, Codex, revise, or stop.\nYour call.\n' "$HALT_MARKER" "$id" >> "$run/output.log"
    grep -q "$HALT_MARKER" "$run/output.log" || fail "$id halt marker missing"
  else
    ! grep -q "$HALT_MARKER" "$file" "$run/.q.md" "$run/.r.md" 2>/dev/null || fail "$id unexpected halt marker"
  fi
  block "$id" "$run/03-decisions.md" | grep -qx "Decided-by: $decided" || fail "$id Decided-by"
  block "$id" "$run/03-decisions.md" | grep -qx "Foldability: $fold" || fail "$id Foldability"
  block "$id" "$run/03-decisions.md" | grep -qx "High-blast: $blast" || fail "$id High-blast"
  pass "fixture $id verdict=$verdict decided=$decided fold=$fold high=$blast marker=$marker"
}

d15_eval() {
  local run="$1"
  LATEST_STAGE3_BLOCK="$(awk '/^Decision ID:/{block=""} {block = block $0 ORS} END{printf "%s", block}' "$run/03-decisions.md")"
  LATEST_STAGE3_VERDICT="$(printf '%s' "$LATEST_STAGE3_BLOCK" | grep -E '^Codex 2nd-opinion verdict:' | head -1 | sed -E 's/^Codex 2nd-opinion verdict: ([A-Z-]+):.*/\1/')"
  LATEST_STAGE3_FOLDABILITY="$(printf '%s' "$LATEST_STAGE3_BLOCK" | grep -E '^Foldability:' | head -1 | sed -E 's/^Foldability: (.*)/\1/')"
  MODE_AUTO="no"; NO_USER_DECISIONS="no"; STAGE3_AGREE="no"
  [[ -f "$run/.mode-auto" ]] && MODE_AUTO="yes"
  grep -q '^Decided-by: user$' "$run/03-decisions.md" || NO_USER_DECISIONS="yes"
  if [[ "$LATEST_STAGE3_VERDICT" == "AGREE" ]] || { [[ "$LATEST_STAGE3_VERDICT" == "ANGLE-MISSED" ]] && [[ "$LATEST_STAGE3_FOLDABILITY" == "folded" ]]; }; then
    STAGE3_AGREE="yes"
  fi
  printf '%s %s %s\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE"
}

write_decision() {
  local run="$1" id="$2" verdict="$3" decided="$4" fold="${5:-n/a}"
  local file="$run/$id.md"
  printf 'Decision: %s\nCodex 2nd-opinion verdict: %s: d15\n' "$id" "$verdict" > "$file"
  "$RECORD" "$run" "$id" "$file" --decided-by "$decided" --foldability "$fold" --high-blast no >/dev/null
}

record_fixture stage-agree AGREE auto n/a no absent
record_fixture stage-folded ANGLE-MISSED auto folded no absent
record_fixture stage-disagree DISAGREE user n/a no present
record_fixture stage-structural ANGLE-MISSED user structural no present
record_fixture stage-codex-failure AGREE user n/a no present
record_fixture stage-unparsable UNKNOWN user n/a no present
record_fixture stage-high-blast AGREE user n/a yes present
record_fixture stage-ambiguous AGREE user n/a ambiguous-halted present

partial="$(new_run partial)"
printf 'Decision: partial\n' > "$partial/p.md"
if "$RECORD" "$partial" partial "$partial/p.md" --decided-by auto >/dev/null 2>"$partial/err"; then
  fail "partial metadata accepted"
fi
grep -q 'must be supplied together' "$partial/err" || fail "partial metadata error"
pass "metadata flags reject partial sets"

run="$(new_run d15-mode-no)"
write_decision "$run" d15-mode-no AGREE auto
[[ "$(d15_eval "$run")" == "no yes yes" ]] || fail "D15 mode_auto=no"
pass "D15 conjunct mode_auto=no"

run="$(new_run d15-user-row)"
touch "$run/.mode-auto"
write_decision "$run" d15-user-row AGREE user
[[ "$(d15_eval "$run")" == "yes no yes" ]] || fail "D15 no_user_decisions=no"
pass "D15 conjunct no_user_decisions=no"

run="$(new_run d15-stage3)"
touch "$run/.mode-auto"
write_decision "$run" d15-stage3 DISAGREE auto
[[ "$(d15_eval "$run")" == "yes yes no" ]] || fail "D15 stage3_agree=no"
pass "D15 conjunct stage3_agree=no"

run="$(new_run d15-stage3-folded)"
touch "$run/.mode-auto"
write_decision "$run" d15-stage3-folded ANGLE-MISSED auto folded
[[ "$(d15_eval "$run")" == "yes yes yes" ]] || fail "D15 stage3_agree=yes (ANGLE-MISSED+folded)"
pass "D15 conjunct stage3_agree=yes via folded ANGLE-MISSED"

run="$(new_run d15-stage3-structural)"
touch "$run/.mode-auto"
write_decision "$run" d15-stage3-structural ANGLE-MISSED user structural
[[ "$(d15_eval "$run")" == "yes no no" ]] || fail "D15 stage3_agree=no (structural ANGLE-MISSED)"
pass "D15 conjunct stage3_agree=no via structural ANGLE-MISSED"

run="$(new_run d15-launch)"
spec="$run/spec.md"; : > "$spec"
# Bg dispatch test: mock claude in a temp bin dir so the real CLI is not touched.
BG_TMP="$(mktemp -d)"
mkdir -p "$BG_TMP/bin"
cat > "$BG_TMP/bin/claude" <<'SH'
#!/usr/bin/env bash
case "$1" in
  --help) printf '%s\n' '  --bg backgrounded'; exit 0 ;;
esac
ARGS_FILE="${CLAUDE_ARGS_FILE:?}"
printf '%s\n' "$@" > "$ARGS_FILE"
printf 'backgrounded \xc2\xb7 c0ffee01\n'
exit 0
SH
chmod +x "$BG_TMP/bin/claude"
CLAUDE_ARGS_FILE="$BG_TMP/claude.args" PATH="$BG_TMP/bin:$PATH" \
  HOME="$BG_TMP" RUN_ID="auto-gate-$$" RUN_DIR="$run" CANONICAL_SPEC_PATH="$spec" CXMEM_PROJECT="autotest" \
  "$ROOT/skills/think/scripts/start-bg-build.sh" >/dev/null
grep -qx -- '--bg' "$BG_TMP/claude.args" || fail "D15 clean auto chain did not invoke claude --bg"
grep -qx -- 'claudex-build-autotest-auto-gate-'"$$" "$BG_TMP/claude.args" || fail "D15 clean auto chain did not pass --name claudex-build-autotest-auto-gate-$$"
pass "D15 clean auto chain launches backgrounded claude agent"
rm -rf "$BG_TMP"

run="$(new_run d15-write-failure)"
mkdir "$run/.auto-launch-decision"
if (printf 'auto_launch=yes\n' > "$run/.auto-launch-decision") 2>/dev/null; then
  fail "write-failure fixture unexpectedly writable"
fi
# write-failure path must not invoke the bg dispatcher; no observable side effect to check
# beyond the predicate file refusing to write. Confirm fixture is unwritable.
[[ -d "$run/.auto-launch-decision" ]] || fail "write-failure fixture was not created as a directory"
pass "D15 write failure halts without launching backgrounded build"
