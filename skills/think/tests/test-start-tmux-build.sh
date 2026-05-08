#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/start-tmux-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set +e
env -i bash "$SCRIPT" >"$TMP/usage-out" 2>"$TMP/usage-err"
status=$?
set -e
[[ "$status" -eq 2 ]] || { echo "FAIL: missing env exited $status, expected 2"; exit 1; }

mkdir -p "$TMP/run"
mkdir -p "$TMP/home"
printf '# spec\n' > "$TMP/spec.md"

SAFE_BIN="$TMP/safe-bin"
mkdir -p "$SAFE_BIN"
for tool in bash dirname mkdir basename cat date printf; do
  ln -s "$(command -v "$tool")" "$SAFE_BIN/$tool"
done
set +e
PATH="$SAFE_BIN" RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" bash "$SCRIPT" >"$TMP/missing-out" 2>"$TMP/missing-err"
status=$?
set -e
[[ "$status" -eq 3 ]] || { echo "FAIL: missing tmux exited $status, expected 3"; exit 1; }
grep -q 'apt install tmux' "$TMP/missing-err"
grep -q 'brew install tmux' "$TMP/missing-err"

STUB="$TMP/bin"
mkdir -p "$STUB"
cat > "$STUB/claude" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$STUB/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TMUX_ARGS_FILE"
case "$TMUX_MODE" in
  fail) exit 1 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$STUB/claude" "$STUB/tmux"

HOME="$TMP/home" TMUX_ARGS_FILE="$TMP/tmux.args" TMUX_MODE=ok PATH="$STUB:$PATH" CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" bash "$SCRIPT" >"$TMP/out"
grep -q 'tmux attach -t claudex-build-mem-2026-01-01-0000-demo' "$TMP/out"
grep -q -- '-s claudex-build-mem-2026-01-01-0000-demo' "$TMP/tmux.args"
grep -q -- '-e RUN_ID=2026-01-01-0000-demo' "$TMP/tmux.args"
grep -q -- '-e CXMEM_PROJECT=mem' "$TMP/tmux.args"
grep -q -- "-e RUN_DIR=$TMP/run" "$TMP/tmux.args"
grep -q -- "-e CANONICAL_SPEC_PATH=$TMP/spec.md" "$TMP/tmux.args"
! grep -Eq 'claudex-build-[^-]+-[0-9]{6}(-[0-9]+)?' "$TMP/tmux.args"

set +e
HOME="$TMP/home" TMUX_ARGS_FILE="$TMP/tmux-fail.args" TMUX_MODE=fail PATH="$STUB:$PATH" CXMEM_PROJECT=mem RUN_ID="2026-01-01-0000-demo" RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" bash "$SCRIPT" >"$TMP/fail-out" 2>"$TMP/fail-err"
status=$?
set -e
[[ "$status" -eq 4 ]] || { echo "FAIL: tmux creation failure exited $status, expected 4"; exit 1; }
grep -q 'failed to create tmux session' "$TMP/fail-err"

echo "PASS: start-tmux-build uses env handoff and exact detached tmux session"
