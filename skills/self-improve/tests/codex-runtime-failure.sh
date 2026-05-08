#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RUN="$TMP/run"
mkdir -p "$RUN" "$TMP/bin"
printf '# projection\n' > "$TMP/projection.md"
cat > "$TMP/bin/codex" <<'SH'
#!/usr/bin/env bash
echo "simulated failure" >&2
exit 9
SH
chmod +x "$TMP/bin/codex"

set +e
PATH="$TMP/bin:$PATH" bash "$ROOT/skills/self-improve/scripts/dispatch-advisor-codex.sh" "$RUN" m__r 001 "$TMP/projection.md" codex any 5 "skills/self-improve/SKILL.md" > "$TMP/stdout" 2> "$TMP/stderr"
code="$?"
set -e
[[ "$code" -eq 4 ]] || { echo "FAIL: expected exit 4, got $code"; exit 1; }
grep -q 'codex exec failed' "$TMP/stderr" || { echo "FAIL: runtime failure not surfaced"; exit 1; }
[[ -f "$RUN/.last-codex-advise-m__r-001.err" ]] || { echo "FAIL: err file missing"; exit 1; }

echo "PASS: codex runtime failure"
