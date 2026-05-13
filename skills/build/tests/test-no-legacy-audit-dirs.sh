#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESOLVER="$ROOT/skills/build/scripts/resolve-run-dir.sh"
HANDOFF="$ROOT/skills/think/scripts/start-bg-build.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

home="$TMP/home"
legacy="$home/vault/projects/claudex/audits"
mkdir -p "$legacy" "$TMP/bin"

cat > "$TMP/bin/claude" <<'SH'
#!/usr/bin/env bash
case "$1" in
  --help)
    printf '%s\n' '  --bg backgrounded'
    exit 0
    ;;
esac
ARGS_FILE="${CLAUDE_ARGS_FILE:-/dev/null}"
printf '%s\n' "$@" > "$ARGS_FILE"
printf 'backgrounded \xc2\xb7 deadbeef\n'
exit 0
SH
chmod +x "$TMP/bin/claude"

snapshot() {
  find "$legacy" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

run_case() {
  local state="$1"
  local run_id="$2"
  local cxmem="$TMP/cxmem-$state"
  mkdir -p "$cxmem/projects/mem"
  if [[ "$state" == "CXMEM_HOST_PROJECT_READY" ]]; then
    printf '**Active session**: `session-slug`, last round 1\n' > "$cxmem/projects/mem/project-memory.md"
  fi
  snapshot > "$TMP/before-$state"
  run_dir="$(HOME="$home" CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE="$state" bash "$RESOLVER" "$run_id")"
  mkdir -p "$run_dir"
  touch "$run_dir/.design-approved" "$run_dir/03-decisions.frozen"
  printf '# spec\n' > "$run_dir/spec.md"
  HOME="$home" CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE="$state" \
    CXMEM_SESSION_SLUG="session-slug" SESSIONS_ROOT="$cxmem/projects/mem/sessions" MAIN_ROUND_SEQ="1" \
    CLAUDE_ARGS_FILE="$TMP/claude-$state.args" PATH="$TMP/bin:$PATH" \
    RUN_ID="$run_id" RUN_DIR="$run_dir" CANONICAL_SPEC_PATH="$run_dir/spec.md" \
    bash "$HANDOFF" > "$TMP/handoff-$state.out"
  snapshot > "$TMP/after-$state"
  cmp "$TMP/before-$state" "$TMP/after-$state"
  [[ "$run_dir" != "$legacy/"* ]]
  [[ -f "$run_dir/.bg-prompt.md" ]]
  grep -qx -- '--bg' "$TMP/claude-$state.args"
}

run_case CXMEM_HOST_PROJECT_READY run-ready
run_case CXMEM_HOST_PROJECT_NO_SESSION run-sessionless

echo "PASS: ready and sessionless CXMem handoff creates no new legacy audit directories"
