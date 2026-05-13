#!/usr/bin/env bash
# Focused test from claudex-build's perspective: bg dispatcher project-scopes
# the session name and propagates CXMEM_PROJECT into the spawned child.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/start-bg-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/run" "$TMP/home" "$TMP/bin" "$TMP/notmux-bin"
printf '# spec\n' > "$TMP/spec.md"

cat > "$TMP/bin/claude" <<'SH'
#!/usr/bin/env bash
ARGS_FILE="${CLAUDE_ARGS_FILE:?}"
ENV_FILE="${CLAUDE_ENV_FILE:?}"
printf '%s\n' "$@" > "$ARGS_FILE"
env > "$ENV_FILE"
case "$1" in
  --help)
    cat <<HELP
Usage: claude [options] [prompt]
  --bg         run as backgrounded agent
HELP
    exit 0
    ;;
esac
printf 'backgrounded \xc2\xb7 c0ffee01\n'
exit 0
SH
chmod +x "$TMP/bin/claude"

cat > "$TMP/notmux-bin/tmux" <<'SH'
#!/usr/bin/env bash
touch "$TMP/tmux.invoked"
exit 0
SH
chmod +x "$TMP/notmux-bin/tmux"

HOME="$TMP/home" PATH="$TMP/bin:$TMP/notmux-bin:/usr/bin:/bin" \
  CLAUDE_ARGS_FILE="$TMP/claude.args" CLAUDE_ENV_FILE="$TMP/claude.env" \
  CXMEM_PROJECT=claudex-imp RUN_ID=run-123 RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/out"

grep -qx -- '--bg' "$TMP/claude.args"
grep -qx -- 'claudex-build-claudex-imp-run-123' "$TMP/claude.args"
grep -q 'Job:       c0ffee01 (name: claudex-build-claudex-imp-run-123)' "$TMP/out"
grep -q 'Attach:    claude attach c0ffee01' "$TMP/out"
grep -qE '^CXMEM_PROJECT=claudex-imp$' "$TMP/claude.env"
grep -qE '^RUN_ID=run-123$' "$TMP/claude.env"
[[ ! -f "$TMP/tmux.invoked" ]] || { echo "FAIL: tmux invoked"; exit 1; }

echo "PASS: bg build handoff propagates CXMEM_PROJECT and project-scopes session name"
