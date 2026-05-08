#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DISPATCH="$ROOT/skills/build/scripts/dispatch-codex-spec-write.sh"
REVIEW="$ROOT/skills/build/scripts/build-opus-spec-review-prompt.sh"
RESOLVE_RUN_DIR="$ROOT/skills/build/scripts/resolve-run-dir.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/run" "$TMP/bin"
cat > "$TMP/run/03-decisions.md" <<'EOF'
## Decision D1
Use the approved path.
EOF
cat > "$TMP/run/04-design.md" <<'EOF'
# Design
Build R10.
EOF
cat > "$TMP/run/05-approaches.md" <<'EOF'
# Approaches
Selected: minimal.
EOF
printf 'adaptive context\n' > "$TMP/run/adaptive.md"

cat > "$TMP/bin/codex" <<'SH'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -) cat > "$PROMPT_CAPTURE" ;;
  esac
  shift
done
cat <<'EOF'
codex
# r10 — design

## Decisions preamble

## Problem
Problem text.
## Approach (selected)
Approach text.
## Architecture
Architecture text.
## Components
Components text.
## Data flow
Data flow text.
## Error handling
Errors text.
## Testing
Testing text.
## Out of scope
Out text.
tokens used
EOF
SH
chmod +x "$TMP/bin/codex"

for state in CXMEM_HOST_PROJECT_READY CXMEM_HOST_PROJECT_NO_SESSION CXMEM_HOST_MISSING; do
  case "$state" in
    CXMEM_HOST_PROJECT_READY)
      run_id="run-ready"
      fixture_home="$TMP/home-ready"
      fixture_cxmem="$TMP/cxmem-ready"
      mkdir -p "$fixture_home" "$fixture_cxmem/projects/mem"
      printf '**Active session**: `session-slug`\n' > "$fixture_cxmem/projects/mem/project-memory.md"
      expected_run_dir="$fixture_cxmem/projects/mem/sessions/session-slug/runs/$run_id"
      ;;
    CXMEM_HOST_PROJECT_NO_SESSION)
      run_id="run-sessionless"
      fixture_home="$TMP/home-sessionless"
      fixture_cxmem="$TMP/cxmem-sessionless"
      mkdir -p "$fixture_home" "$fixture_cxmem/projects/mem"
      expected_run_dir="$fixture_cxmem/projects/mem/runs/$run_id"
      ;;
    CXMEM_HOST_MISSING)
      run_id="run-missing"
      fixture_home="$TMP/home-missing"
      fixture_cxmem="$TMP/cxmem-missing"
      mkdir -p "$fixture_home"
      expected_run_dir="$fixture_home/vault/projects/claudex/audits/$run_id"
      ;;
  esac
  run_dir="$(HOME="$fixture_home" CXMEM_HOME="$fixture_cxmem" CXMEM_PROJECT=mem CXMEM_HOST_STATE="$state" bash "$RESOLVE_RUN_DIR" "$run_id")"
  [[ "$run_dir" == "$expected_run_dir" ]] || { echo "FAIL: $state resolved $run_dir, expected $expected_run_dir"; exit 1; }
  mkdir -p "$run_dir"
  cp "$TMP/run/03-decisions.md" "$run_dir/03-decisions.md"
  cp "$TMP/run/04-design.md" "$run_dir/04-design.md"
  cp "$TMP/run/05-approaches.md" "$run_dir/05-approaches.md"
  printf 'adaptive context\n' > "$run_dir/adaptive.md"
  prompt_capture="$run_dir/prompt.md"
  canonical="$run_dir/canonical.md"
  PROMPT_CAPTURE="$prompt_capture" PATH="$TMP/bin:$PATH" CXMEM_HOST_STATE="$state" ADAPTIVE_CONTEXT_PATH="$run_dir/adaptive.md" \
    bash "$DISPATCH" "$run_dir" 1 "$run_dir/04-design.md" "$run_dir/05-approaches.md" "$canonical" > "$run_dir/dispatch.out"
  grep -q "ok: round=1" "$run_dir/dispatch.out"
  grep -q 'adaptive context' "$prompt_capture"
  grep -q "$canonical" "$prompt_capture"
  grep -q '## Decision D1' "$canonical"
  grep -q '## Problem' "$canonical"
  ! grep -q '02-transcript' "$prompt_capture"
  [[ -f "$run_dir/06-spec-r1.md" ]]
  [[ -f "$run_dir/06-spec-r1.clean.md" ]]
  if [[ "$state" == "CXMEM_HOST_PROJECT_READY" ]]; then
    grep -q '<<<CXMEM-RECORD>>>' "$prompt_capture"
  else
    ! grep -q '<<<CXMEM-RECORD>>>' "$prompt_capture"
  fi
done

bash "$REVIEW" "$TMP/cxmem-ready/projects/mem/sessions/session-slug/runs/run-ready" 1 "$TMP/cxmem-ready/projects/mem/sessions/session-slug/runs/run-ready/05-approaches.md" > "$TMP/review-path"
REVIEW_PROMPT="$(cat "$TMP/review-path")"
grep -q 'You are reviewing a spec produced by Codex' "$REVIEW_PROMPT"
grep -q '# APPROVED DESIGN' "$REVIEW_PROMPT"
grep -q '# FROZEN DECISIONS' "$REVIEW_PROMPT"
grep -q '# ARTIFACT TO REVIEW' "$REVIEW_PROMPT"

echo "PASS: SPEC stage writes artifacts under ready, sessionless, and missing run dirs"
