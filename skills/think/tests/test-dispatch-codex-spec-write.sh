#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/dispatch-codex-spec-write.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

set +e
bash "$SCRIPT" >"$TMP/usage-out" 2>"$TMP/usage-err"
status=$?
set -e
if [[ "$status" -ne 1 ]]; then
  echo "FAIL: usage error exited $status, expected 1"
  exit 1
fi

touch "$TMP/02-transcript.md" "$TMP/03-decisions.md"
printf 'design\n' > "$TMP/04-design.md"
printf 'approaches\n' > "$TMP/05-approaches.md"

set +e
bash "$SCRIPT" "$TMP" 1 "$TMP/missing-design.md" "$TMP/05-approaches.md" "$TMP/canonical.md" >"$TMP/missing-out" 2>"$TMP/missing-err"
status=$?
set -e
if [[ "$status" -ne 2 ]]; then
  echo "FAIL: missing design exited $status, expected 2"
  exit 1
fi

STUB="$TMP/bin"
mkdir -p "$STUB"
cat > "$STUB/codex" <<'SH'
#!/usr/bin/env bash
printf 'codex banner\n'
printf 'WRONG-DIRECTION: test reason\n'
SH
chmod +x "$STUB/codex"

set +e
PATH="$STUB:$PATH" bash "$SCRIPT" "$TMP" 1 "$TMP/04-design.md" "$TMP/05-approaches.md" "$TMP/canonical.md" >"$TMP/wrong-out" 2>"$TMP/wrong-err"
status=$?
set -e
if [[ "$status" -ne 3 ]]; then
  echo "FAIL: WRONG-DIRECTION exited $status, expected 3"
  exit 1
fi
grep -q 'WRONG-DIRECTION: test reason' "$TMP/wrong-err"

echo "PASS: dispatch-codex-spec-write usage, missing-file, wrong-direction paths"
