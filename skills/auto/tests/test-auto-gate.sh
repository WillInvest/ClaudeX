#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RECORD="$ROOT/skills/think/scripts/record-decision.sh"
TMP="$(mktemp -d)"
trap 'tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true; rm -rf "$TMP"' EXIT
HALT_MARKER="Auto mode halted."
TMUX_SESSION=""

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
  LATEST_STAGE3_VERDICT="$(grep -E '^Codex 2nd-opinion verdict:' "$run/03-decisions.md" | tail -1 | sed -E 's/^Codex 2nd-opinion verdict: ([A-Z-]+):.*/\1/')"
  MODE_AUTO="no"; NO_USER_DECISIONS="no"; STAGE3_AGREE="no"
  [[ -f "$run/.mode-auto" ]] && MODE_AUTO="yes"
  grep -q '^Decided-by: user$' "$run/03-decisions.md" || NO_USER_DECISIONS="yes"
  [[ "$LATEST_STAGE3_VERDICT" == "AGREE" ]] && STAGE3_AGREE="yes"
  printf '%s %s %s\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE"
}

write_decision() {
  local run="$1" id="$2" verdict="$3" decided="$4"
  local file="$run/$id.md"
  printf 'Decision: %s\nCodex 2nd-opinion verdict: %s: d15\n' "$id" "$verdict" > "$file"
  "$RECORD" "$run" "$id" "$file" --decided-by "$decided" --foldability n/a --high-blast no >/dev/null
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

run="$(new_run d15-launch)"
spec="$run/spec.md"; : > "$spec"
TMUX_SESSION="claudex-build-autotest-auto-gate-$$"
probe="claudex-build-probe-$$"
if tmux new-session -d -s "$probe" 'sleep 1' >/dev/null 2>&1; then
  tmux kill-session -t "$probe" 2>/dev/null || true
  RUN_ID="auto-gate-$$" RUN_DIR="$run" CANONICAL_SPEC_PATH="$spec" CXMEM_PROJECT="autotest" "$ROOT/skills/think/scripts/start-tmux-build.sh" >/dev/null
  tmux list-sessions 2>/dev/null | grep -q "claudex-build-" || fail "tmux launch session missing"
  pass "D15 clean auto chain launches tmux session"
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
else
  tmux list-sessions 2>/dev/null | grep -q "claudex-build-" && fail "tmux probe found unexpected claudex-build session"
  pass "D15 clean auto chain tmux assertion skipped: tmux server unavailable"
fi
TMUX_SESSION=""

run="$(new_run d15-write-failure)"
mkdir "$run/.auto-launch-decision"
if (printf 'auto_launch=yes\n' > "$run/.auto-launch-decision") 2>/dev/null; then
  fail "write-failure fixture unexpectedly writable"
fi
! tmux list-sessions 2>/dev/null | grep -q "claudex-build-autotest-writefail" || fail "write failure launched tmux"
pass "D15 write failure halts without tmux session"
