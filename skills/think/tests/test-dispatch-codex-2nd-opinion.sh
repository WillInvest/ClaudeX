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
[[ "$status" -eq 2 ]] || { echo "FAIL: usage error exited $status, expected 2"; exit 1; }

touch "$TMP/03-decisions.md"
printf 'recommendation\n' > "$TMP/r.md"
printf 'question\n' > "$TMP/q.md"

SAFE_BIN="$TMP/safe-bin"
mkdir -p "$SAFE_BIN"
for tool in bash dirname pwd mktemp python3 grep tail rm cat cp; do
  ln -s "$(command -v "$tool")" "$SAFE_BIN/$tool"
done
set +e
PATH="$SAFE_BIN" bash "$SCRIPT" "$TMP" "$TMP/q.md" "$TMP/r.md" </dev/null >"$TMP/codex-missing-out" 2>"$TMP/codex-missing-err"
status=$?
set -e
[[ "$status" -eq 3 ]] || { echo "FAIL: codex missing exited $status, expected 3"; exit 1; }

STUB="$TMP/bin"
mkdir -p "$STUB"
CAPTURED_PROMPT="$TMP/claudex-dispatch-prompt"
export CAPTURED_PROMPT
cat > "$STUB/codex" <<'SH'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -) cat > "$CAPTURED_PROMPT" ;;
  esac
  shift
done
printf 'codex\nAGREE: looks right\n'
SH
chmod +x "$STUB/codex"

printf 'stdin transcript\n' | PATH="$STUB:$PATH" bash "$SCRIPT" "$TMP" "$TMP/q.md" "$TMP/r.md" >"$TMP/stdin-out"
grep -q '^AGREE: looks right$' "$TMP/stdin-out"
grep -q 'stdin transcript' "$CAPTURED_PROMPT"

printf 'file transcript\n' > "$TMP/transcript.md"
PATH="$STUB:$PATH" bash "$SCRIPT" --transcript-file "$TMP/transcript.md" "$TMP" "$TMP/q.md" "$TMP/r.md" </dev/null >"$TMP/file-out"
grep -q '^AGREE: looks right$' "$TMP/file-out"
grep -q 'file transcript' "$CAPTURED_PROMPT"

rm -f "$TMP/02-transcript.md"
PATH="$STUB:$PATH" bash "$SCRIPT" "$TMP" "$TMP/q.md" "$TMP/r.md" </dev/null >"$TMP/empty-out"
grep -q '^AGREE: looks right$' "$TMP/empty-out"

echo "PASS: dispatch-codex-2nd-opinion supports stdin/file/stateless transcript"
