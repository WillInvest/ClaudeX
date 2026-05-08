#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/dispatch-codex-spec-write.sh"
REAL_PYTHON="$(command -v python3)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_run() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/03-decisions.md" <<'EOF'
## Decision D1
Keep the byte-stable decision.
EOF
  printf '# Design\n' > "$dir/04-design.md"
  printf '# Approaches\n' > "$dir/05-approaches.md"
}

install_codex() {
  local mode="$1"
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/codex" <<SH
#!/usr/bin/env bash
while [[ "\$#" -gt 0 ]]; do
  case "\$1" in
    -) cat >/dev/null ;;
  esac
  shift
done
case "$mode" in
  wrong)
    printf 'WRONG-DIRECTION: test reason\n'
    ;;
  cleanup)
    printf 'codex\nno markdown header here\n'
    ;;
  good)
    cat <<'EOF'
codex
# r10 — design

## Decisions preamble

## Problem
Problem.
## Approach (selected)
Approach.
## Architecture
Architecture.
## Components
Components.
## Data flow
Flow.
## Error handling
Errors.
## Testing
Tests.
## Out of scope
Out.
tokens used
EOF
    ;;
esac
SH
  chmod +x "$TMP/bin/codex"
}

make_run "$TMP/wrong"
install_codex wrong
set +e
PATH="$TMP/bin:$PATH" bash "$SCRIPT" "$TMP/wrong" 1 "$TMP/wrong/04-design.md" "$TMP/wrong/05-approaches.md" "$TMP/wrong/canonical.md" >"$TMP/wrong.out" 2>"$TMP/wrong.err"
status=$?
set -e
[[ "$status" -eq 3 ]] || { echo "FAIL: WRONG-DIRECTION exited $status, expected 3"; exit 1; }
grep -q 'WRONG-DIRECTION: test reason' "$TMP/wrong.err"

make_run "$TMP/cleanup"
install_codex cleanup
set +e
PATH="$TMP/bin:$PATH" bash "$SCRIPT" "$TMP/cleanup" 1 "$TMP/cleanup/04-design.md" "$TMP/cleanup/05-approaches.md" "$TMP/cleanup/canonical.md" >"$TMP/cleanup.out" 2>"$TMP/cleanup.err"
status=$?
set -e
[[ "$status" -eq 5 ]] || { echo "FAIL: cleanup failure exited $status, expected 5"; exit 1; }
grep -q 'cleanup or preamble splice failed' "$TMP/cleanup.err"

make_run "$TMP/drift"
install_codex good
cat > "$TMP/bin/python3" <<SH
#!/usr/bin/env bash
if [[ "\$#" -eq 3 && "\$1" == "-" && "\$2" == *".clean.md" && "\$3" == *"03-decisions.md" ]]; then
  printf 'forced preamble drift\n' >&2
  exit 1
fi
exec "$REAL_PYTHON" "\$@"
SH
chmod +x "$TMP/bin/python3"
set +e
PATH="$TMP/bin:$PATH" bash "$SCRIPT" "$TMP/drift" 1 "$TMP/drift/04-design.md" "$TMP/drift/05-approaches.md" "$TMP/drift/canonical.md" >"$TMP/drift.out" 2>"$TMP/drift.err"
status=$?
set -e
[[ "$status" -eq 6 ]] || { echo "FAIL: byte-match drift exited $status, expected 6"; exit 1; }
grep -q 'post-splice preamble byte-match FAILED' "$TMP/drift.err"

echo "PASS: dispatch-codex-spec-write covers WRONG-DIRECTION cleanup and byte-match failures"
