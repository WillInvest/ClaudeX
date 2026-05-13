#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESOLVE_PROJECT="$ROOT/skills/build/scripts/resolve-cxmem-project.sh"
RESOLVE_RUN="$ROOT/skills/build/scripts/resolve-run-dir.sh"
TRANSCRIPT="$ROOT/skills/think/scripts/cxmem-rounds-to-transcript.sh"
HANDOFF="$ROOT/skills/think/scripts/start-bg-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/mem/sessions/ms/rounds" "$CXMEM_HOME/projects/claudex-imp/sessions/is/rounds" "$TMP/bin" "$TMP/home"
printf '**Active session**: `ms`, last round 1\n' > "$CXMEM_HOME/projects/mem/project-memory.md"
printf '**Active session**: `is`, last round 1\n' > "$CXMEM_HOME/projects/claudex-imp/project-memory.md"
printf '# Mem round\n' > "$CXMEM_HOME/projects/mem/sessions/ms/rounds/round-1.md"
printf '# Imp round\n' > "$CXMEM_HOME/projects/claudex-imp/sessions/is/rounds/round-1.md"
printf '# spec\n' > "$TMP/spec.md"
cat > "$TMP/bin/claude" <<'SH'
#!/usr/bin/env bash
case "$1" in
  --help) printf '%s\n' '  --bg backgrounded'; exit 0 ;;
esac
ARGS_FILE="${CLAUDE_ARGS_FILE:?}"
printf '%s\n' "$@" > "$ARGS_FILE"
printf 'backgrounded \xc2\xb7 c0ffee01\n'
exit 0
SH
chmod +x "$TMP/bin/claude"

out="$(cd "$CXMEM_HOME/projects/mem" && CXMEM_HOME="$CXMEM_HOME" bash "$RESOLVE_PROJECT")"
[[ "$out" == "mem" ]]
out="$(cd "$TMP" && CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=claudex-imp bash "$RESOLVE_PROJECT")"
[[ "$out" == "claudex-imp" ]]

run_ready="$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=mem CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY bash "$RESOLVE_RUN" run-a)"
[[ "$run_ready" == "$CXMEM_HOME/projects/mem/sessions/ms/runs/run-a" ]]
run_sessionless="$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=claudex-imp CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_NO_SESSION bash "$RESOLVE_RUN" run-b)"
[[ "$run_sessionless" == "$CXMEM_HOME/projects/claudex-imp/runs/run-b" ]]
[[ "$run_ready" != "$CXMEM_HOME/sessions/"* && "$run_sessionless" != "$CXMEM_HOME/runs/"* ]]

bash "$TRANSCRIPT" "$CXMEM_HOME/projects/mem/sessions" ms > "$TMP/transcript"
grep -q 'Mem round' "$TMP/transcript"
! grep -q 'Imp round' "$TMP/transcript"

mkdir -p "$run_ready"
HOME="$TMP/home" PATH="$TMP/bin:$PATH" CLAUDE_ARGS_FILE="$TMP/claude.args" \
  CXMEM_PROJECT=mem RUN_ID=run-a RUN_DIR="$run_ready" CANONICAL_SPEC_PATH="$TMP/spec.md" \
  bash "$HANDOFF" >/dev/null
grep -qx -- '--bg' "$TMP/claude.args"
grep -qx -- 'claudex-build-mem-run-a' "$TMP/claude.args"

echo "PASS: end-to-end multi-project routing stays project scoped"
