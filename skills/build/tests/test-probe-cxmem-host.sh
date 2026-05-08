#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/probe-cxmem-host.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

missing="$TMP/missing-cxmem"
out="$(CXMEM_HOME="$missing" bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_MISSING" ]]

cxmem="$TMP/cxmem"
mkdir -p "$cxmem/projects/mem" "$cxmem/docs"
out="$(CXMEM_HOME="$cxmem" PWD="$TMP" bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_NO_PROJECT" ]]

cat > "$cxmem/docs/project-memory-template.md" <<'EOF'
# {{PROJECT}}
**Active session**: ``, last round 0
{{DATE}}
EOF
out="$(CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_PROJECT_NO_MEMORY" ]]
grep -q '# mem' "$cxmem/projects/mem/project-memory.md"
cp "$cxmem/projects/mem/project-memory.md" "$TMP/project-memory.after-first"
out="$(CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_PROJECT_NO_SESSION" ]]
cp "$cxmem/projects/mem/project-memory.md" "$TMP/project-memory.after-second"
cmp -s "$TMP/project-memory.after-first" "$TMP/project-memory.after-second"

run_dir="$TMP/run"
mkdir -p "$run_dir"
out="$(CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem RUN_DIR="$run_dir" bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_PROJECT_NO_SESSION" ]]
grep -q 'warning: CXMem active session slug missing or empty' "$run_dir/.codex-state"

printf '**Active session**: `2026-05-07-demo`, last round 2\n' > "$cxmem/projects/mem/project-memory.md"
out="$(CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem bash "$SCRIPT")"
[[ "$out" == "CXMEM_HOST_PROJECT_READY" ]]

mkdir -p "$cxmem/projects/other" "$run_dir/mismatch"
printf '**Active session**: `other-session`, last round 1\n' > "$cxmem/projects/other/project-memory.md"
( cd "$cxmem/projects/other" && CXMEM_HOME="$cxmem" CXMEM_PROJECT=mem RUN_DIR="$run_dir/mismatch" bash "$SCRIPT" >/dev/null )
grep -q 'CXMEM_PROJECT=mem differs from cwd-derived project other' "$run_dir/mismatch/.codex-state"

no_template="$TMP/no-template"
mkdir -p "$no_template/projects/mem"
set +e
CXMEM_HOME="$no_template" CXMEM_PROJECT=mem bash "$SCRIPT" >"$TMP/notemplate.out" 2>"$TMP/notemplate.err"
status=$?
set -e
[[ "$status" -eq 4 ]]
grep -q 'project-memory template missing' "$TMP/notemplate.err"

set +e
CXMEM_HOME="$TMP/usage-cxmem" bash "$SCRIPT" unexpected >"$TMP/usage-out" 2>"$TMP/usage-err"
status=$?
set -e
[[ "$status" -eq 2 ]]
grep -q 'usage: probe-cxmem-host.sh' "$TMP/usage-err"

echo "PASS: cxmem host probe emits R12 project states, bootstrap, mismatch, and template diagnostics"
