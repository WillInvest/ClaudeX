#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/dispatch-codex-2nd-opinion.sh"
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
printf 'recommendation\n' > "$TMP/r.md"

set +e
bash "$SCRIPT" "$TMP" "$TMP/missing-q.md" "$TMP/r.md" >"$TMP/missing-out" 2>"$TMP/missing-err"
status=$?
set -e
if [[ "$status" -ne 2 ]]; then
  echo "FAIL: missing question exited $status, expected 2"
  exit 1
fi

printf 'question\n' > "$TMP/q.md"
SAFE_BIN="$TMP/safe-bin"
mkdir -p "$SAFE_BIN"
for tool in bash dirname pwd mktemp python3 grep tail rm cat; do
  ln -s "$(command -v "$tool")" "$SAFE_BIN/$tool"
done
set +e
PATH="$SAFE_BIN" bash "$SCRIPT" "$TMP" "$TMP/q.md" "$TMP/r.md" >"$TMP/codex-missing-out" 2>"$TMP/codex-missing-err"
status=$?
set -e
if [[ "$status" -ne 3 ]]; then
  echo "FAIL: codex missing exited $status, expected 3"
  exit 1
fi

STUB="$TMP/bin"
mkdir -p "$STUB"
cat > "$STUB/codex" <<'SH'
#!/usr/bin/env bash
printf 'unrelated output\n'
SH
chmod +x "$STUB/codex"

set +e
PATH="$STUB:$PATH" bash "$SCRIPT" "$TMP" "$TMP/q.md" "$TMP/r.md" >"$TMP/unparse-out" 2>"$TMP/unparse-err"
status=$?
set -e
if [[ "$status" -ne 5 ]]; then
  echo "FAIL: unparsable codex output exited $status, expected 5"
  exit 1
fi
grep -q 'did not contain a verdict line' "$TMP/unparse-err"

echo "PASS: dispatch-codex-2nd-opinion usage, missing-file, codex-missing, unparsable paths"
