#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/start-tmux-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/run" "$TMP/home" "$TMP/bin"
printf '# spec\n' > "$TMP/spec.md"
cat > "$TMP/bin/claude" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TMP/bin/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$TMUX_ARGS_FILE"
exit 0
SH
chmod +x "$TMP/bin/claude" "$TMP/bin/tmux"

HOME="$TMP/home" TMUX_ARGS_FILE="$TMP/tmux.args" PATH="$TMP/bin:$PATH" \
  CXMEM_PROJECT=claudex-imp RUN_ID=run-123 RUN_DIR="$TMP/run" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$SCRIPT" > "$TMP/out"

grep -q -- '-s claudex-build-claudex-imp-run-123' "$TMP/tmux.args"
grep -q -- '-e CXMEM_PROJECT=claudex-imp' "$TMP/tmux.args"
grep -q 'tmux attach -t claudex-build-claudex-imp-run-123' "$TMP/out"

echo "PASS: tmux build handoff propagates CXMEM_PROJECT and project-scopes session name"
