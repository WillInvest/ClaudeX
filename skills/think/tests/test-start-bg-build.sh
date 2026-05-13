#!/usr/bin/env bash
# Covers the dispatcher's behavior contract per
# specs/2026-05-13-bg-build-dispatch-design.md §Testing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/start-bg-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/run" "$TMP/home" "$TMP/bin"
printf '# spec\n' > "$TMP/spec.md"

# --- helper: refresh test-controlled mock claude ----------------------------
make_claude_mock() {
  local mode="$1"
  cat > "$TMP/bin/claude" <<SH
#!/usr/bin/env bash
ARGS_FILE="\${CLAUDE_ARGS_FILE:-$TMP/claude.args}"
ENV_FILE="\${CLAUDE_ENV_FILE:-$TMP/claude.env}"
PROMPT_FILE="\${CLAUDE_PROMPT_FILE:-$TMP/claude.prompt}"
# Dump args (one per line, preserves quoting)
printf '%s\n' "\$@" > "\$ARGS_FILE"
# Dump env
env > "\$ENV_FILE"
# Capture -p value
prev=""; for a in "\$@"; do
  if [[ "\$prev" == "-p" ]]; then printf '%s' "\$a" > "\$PROMPT_FILE"; fi
  prev="\$a"
done

case "\$1" in
  --help)
    case "$mode" in
      help-no-bg)
        cat <<HELP
Usage: claude [options] [prompt]
  --print -p   print mode
  --name <n>   display name
HELP
        ;;
      *)
        cat <<HELP
Usage: claude [options] [prompt]
  --bg         run as backgrounded agent
  --print -p   print mode
  --name <n>   display name
HELP
        ;;
    esac
    exit 0
    ;;
esac

case "$mode" in
  happy)
    printf 'backgrounded \xc2\xb7 deadbeef\n  claude agents             list sessions\n'
    exit 0
    ;;
  disclaimer)
    printf '%s\n' '--bg with bypassPermissions requires accepting the disclaimer first. Run \`claude --dangerously-skip-permissions\` once interactively.' >&2
    exit 1
    ;;
  generic-fail)
    printf 'something unrelated went wrong\n' >&2
    exit 7
    ;;
  parse-miss)
    printf 'no job id here\n'
    exit 0
    ;;
  *)
    printf 'backgrounded \xc2\xb7 deadbeef\n'
    exit 0
    ;;
esac
SH
  chmod +x "$TMP/bin/claude"
}

# --- helper: invariant tmux shim (sentinel-file marker if dispatcher uses it) -
mkdir -p "$TMP/notmux-bin"
cat > "$TMP/notmux-bin/tmux" <<SH
#!/usr/bin/env bash
touch "$TMP/tmux.invoked"
exit 0
SH
chmod +x "$TMP/notmux-bin/tmux"

# ---------------------------------------------------------------------------
# 1. Happy path
# ---------------------------------------------------------------------------
make_claude_mock happy
rm -f "$TMP/claude.args" "$TMP/claude.env" "$TMP/claude.prompt" "$TMP/tmux.invoked"
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CLAUDE_ARGS_FILE="$TMP/claude.args" CLAUDE_ENV_FILE="$TMP/claude.env" CLAUDE_PROMPT_FILE="$TMP/claude.prompt" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/out" 2> "$TMP/err"
grep -q '^\[claudex\] Build running as backgrounded claude agent$' "$TMP/out"
grep -q 'Job:       deadbeef' "$TMP/out"
grep -q 'Dashboard: claude agents' "$TMP/out"
grep -q 'Attach:    claude attach deadbeef' "$TMP/out"
grep -q 'Logs:      claude logs deadbeef' "$TMP/out"
grep -q 'Stop:      claude stop deadbeef' "$TMP/out"
grep -q "Summary:   $TMP/run/99-final-summary.md" "$TMP/out"
grep -q "Run trail: $TMP/run/" "$TMP/out"
grep -q 'Run-id: 2026-01-01-0000-demo' "$TMP/out"
grep -qx -- '--bg' "$TMP/claude.args"
grep -qx -- '--permission-mode' "$TMP/claude.args"
grep -qx -- 'bypassPermissions' "$TMP/claude.args"
grep -qx -- '--name' "$TMP/claude.args"
grep -qx -- 'claudex-build-mem-2026-01-01-0000-demo' "$TMP/claude.args"
grep -qx -- '-p' "$TMP/claude.args"
[[ -f "$TMP/run/.bg-prompt.md" ]] || { echo "FAIL: .bg-prompt.md not written"; exit 1; }
grep -q "^/claudex:build $TMP/spec.md\$" "$TMP/run/.bg-prompt.md"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked on happy path"; exit 1; }

# ---------------------------------------------------------------------------
# 2. Prompt file semantics — large prompt round-trips byte-for-byte
# ---------------------------------------------------------------------------
make_claude_mock happy
rm -f "$TMP/claude.prompt" "$TMP/run/.bg-prompt.md"
# Generate >=4096 byte / >=80 line fixture and use it as the spec body
python3 - <<PY > "$TMP/big-spec.md"
import sys
lines = []
lines.append("# Big spec fixture")
for i in range(1, 120):
    lines.append(f"line {i:03d} " + ("payload " * 12).rstrip())
out = "\n".join(lines) + "\n"
sys.stdout.write(out)
PY
SIZE=$(wc -c < "$TMP/big-spec.md")
LINES=$(wc -l < "$TMP/big-spec.md")
[[ "$SIZE" -ge 4096 ]] || { echo "FAIL: fixture size $SIZE < 4096"; exit 1; }
[[ "$LINES" -ge 80 ]] || { echo "FAIL: fixture lines $LINES < 80"; exit 1; }
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CLAUDE_ARGS_FILE="$TMP/claude.args" CLAUDE_ENV_FILE="$TMP/claude.env" CLAUDE_PROMPT_FILE="$TMP/claude.prompt" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/big-spec.md" \
  bash "$SCRIPT" > "$TMP/out2" 2> /dev/null
# .bg-prompt.md must be: /claudex:build <path>\n (optionally followed by hook)
head -1 "$TMP/run/.bg-prompt.md" | grep -q "^/claudex:build $TMP/big-spec.md\$"
# Mock's -p capture must equal the .bg-prompt.md content modulo trailing newline
# (bash $(cat) strips trailing newlines; not meaningful to claude's prompt parser).
diff <(printf '%s' "$(cat "$TMP/run/.bg-prompt.md")") "$TMP/claude.prompt" >/dev/null \
  || { echo "FAIL: -p prompt content mismatch with .bg-prompt.md (modulo trailing newline)"; exit 1; }
# Sanity: the path itself is preserved verbatim
grep -qF "$TMP/big-spec.md" "$TMP/claude.prompt"

# ---------------------------------------------------------------------------
# 3. CLI-version miss — claude --help omits --bg
# ---------------------------------------------------------------------------
make_claude_mock help-no-bg
rm -f "$TMP/tmux.invoked"
set +e
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/cli-out" 2> "$TMP/cli-err"
status=$?
set -e
[[ "$status" -eq 3 ]] || { echo "FAIL: CLI-version miss exit=$status, expected 3"; exit 1; }
grep -q 'claude install --version stable' "$TMP/cli-err"
grep -q '≥2.1.140' "$TMP/cli-err"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked on CLI-version miss"; exit 1; }

# ---------------------------------------------------------------------------
# 4. Disclaimer miss — claude --bg stderr matches canonical string
# ---------------------------------------------------------------------------
make_claude_mock disclaimer
rm -f "$TMP/tmux.invoked"
set +e
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/dc-out" 2> "$TMP/dc-err"
status=$?
set -e
[[ "$status" -eq 3 ]] || { echo "FAIL: disclaimer miss exit=$status, expected 3"; exit 1; }
grep -qF 'Run `claude --dangerously-skip-permissions` once interactively.' "$TMP/dc-err"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked on disclaimer miss"; exit 1; }

# ---------------------------------------------------------------------------
# 5. Generic launch failure
# ---------------------------------------------------------------------------
make_claude_mock generic-fail
rm -f "$TMP/tmux.invoked"
set +e
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/gf-out" 2> "$TMP/gf-err"
status=$?
set -e
[[ "$status" -eq 4 ]] || { echo "FAIL: generic-fail exit=$status, expected 4"; exit 1; }
grep -q 'something unrelated went wrong' "$TMP/gf-err"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked on generic launch failure"; exit 1; }

# ---------------------------------------------------------------------------
# 6. Job-id parse failure
# ---------------------------------------------------------------------------
make_claude_mock parse-miss
rm -f "$TMP/tmux.invoked"
set +e
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/pm-out" 2> "$TMP/pm-err"
status=$?
set -e
[[ "$status" -eq 4 ]] || { echo "FAIL: parse-miss exit=$status, expected 4"; exit 1; }
grep -q 'could not parse job id' "$TMP/pm-err"
grep -q 'no job id here' "$TMP/pm-err"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked on parse miss"; exit 1; }

# ---------------------------------------------------------------------------
# 7. Name sanitization — weird CXMEM_PROJECT collapses to allowed chars
# ---------------------------------------------------------------------------
make_claude_mock happy
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CLAUDE_ARGS_FILE="$TMP/claude.args" CLAUDE_ENV_FILE="$TMP/claude.env" \
  CXMEM_PROJECT='weird/name with space' RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > /dev/null 2> /dev/null
NAME_LINE=$(grep -A1 -- '--name' "$TMP/claude.args" | tail -1)
echo "$NAME_LINE" | grep -qE '^[A-Za-z0-9._-]+$' || { echo "FAIL: sanitized name has illegal chars: $NAME_LINE"; exit 1; }
[[ "${#NAME_LINE}" -le 64 ]] || { echo "FAIL: sanitized name length ${#NAME_LINE} > 64"; exit 1; }
case "$NAME_LINE" in *' '*) echo "FAIL: name contains space"; exit 1;; esac
case "$NAME_LINE" in */*) echo "FAIL: name contains slash"; exit 1;; esac

# ---------------------------------------------------------------------------
# 8. Required input validation
# ---------------------------------------------------------------------------
set +e
env -i bash "$SCRIPT" >/dev/null 2>"$TMP/usage-err"
status=$?
set -e
[[ "$status" -eq 2 ]] || { echo "FAIL: no env exit=$status, expected 2"; exit 1; }

set +e
RUN_ID="x" RUN_DIR="$TMP/nope" CANONICAL_SPEC_PATH="$TMP/spec.md" bash "$SCRIPT" >/dev/null 2>"$TMP/rd-err"
status=$?
set -e
[[ "$status" -eq 2 ]] || { echo "FAIL: missing RUN_DIR exit=$status, expected 2"; exit 1; }

set +e
RUN_ID="x" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/no-spec.md" bash "$SCRIPT" >/dev/null 2>"$TMP/cs-err"
status=$?
set -e
[[ "$status" -eq 2 ]] || { echo "FAIL: missing CANONICAL_SPEC_PATH exit=$status, expected 2"; exit 1; }

# ---------------------------------------------------------------------------
# 9. Environment propagation
# ---------------------------------------------------------------------------
make_claude_mock happy
HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CLAUDE_ARGS_FILE="$TMP/claude.args" CLAUDE_ENV_FILE="$TMP/claude.env" \
  CXMEM_HOME="$TMP/cxmem-home" CXMEM_PROJECT=mem CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY \
  CXMEM_SESSION_SLUG=slug-x SESSIONS_ROOT="$TMP/sessions" MAIN_ROUND_SEQ=7 \
  RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > /dev/null
for var in RUN_ID RUN_DIR CANONICAL_SPEC_PATH CXMEM_HOME CXMEM_PROJECT CXMEM_HOST_STATE CXMEM_SESSION_SLUG SESSIONS_ROOT MAIN_ROUND_SEQ; do
  grep -qE "^${var}=" "$TMP/claude.env" || { echo "FAIL: $var not propagated to claude --bg env"; exit 1; }
done
grep -qx 'RUN_ID=2026-01-01-0000-demo' "$TMP/claude.env"
grep -qx 'CXMEM_PROJECT=mem' "$TMP/claude.env"
grep -qx 'CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY' "$TMP/claude.env"
grep -qx 'MAIN_ROUND_SEQ=7' "$TMP/claude.env"

# ---------------------------------------------------------------------------
# 10. No-tmux invariant — re-running every failure branch leaves the sentinel absent
# ---------------------------------------------------------------------------
for mode in help-no-bg disclaimer generic-fail parse-miss; do
  rm -f "$TMP/tmux.invoked"
  make_claude_mock "$mode"
  set +e
  HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
    CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
    bash "$SCRIPT" > /dev/null 2> /dev/null
  set -e
  [[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked under failure mode $mode"; exit 1; }
done

# ---------------------------------------------------------------------------
# 11. Replaced-mock invariant — script under test refs claude --bg, not tmux launch
# ---------------------------------------------------------------------------
# Check the dispatcher itself (not this test, which mocks `tmux` to assert the
# no-tmux invariant — those references are intentional).
LEGACY_PATTERN='tmux'' new-session'  # split to avoid self-match in this file
if grep -q "$LEGACY_PATTERN" "$SCRIPT"; then
  echo "FAIL: dispatcher still invokes tmux"
  exit 1
fi
grep -q -- '--bg' "$SCRIPT" || { echo "FAIL: dispatcher does not invoke claude --bg"; exit 1; }

echo "PASS: start-bg-build dispatcher contract (11 cases)"
