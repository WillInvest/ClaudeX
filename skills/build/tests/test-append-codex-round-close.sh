#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/append-codex-round-close.sh"
FIXTURES="$ROOT/skills/build/tests/fixtures/codex-recording"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
SESSIONS="$SCRATCH/CXMem/projects/mem/sessions"
mkdir -p "$SESSIONS/demo/rounds"
trap 'echo "FAIL: append-codex-round-close failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

cat > "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md" <<'EOF'
# Round 1 codex

## Summary

Implemented scoped change.

## Reviewer 2nd-opinion

fix-and-proceed: accepted with notes
EOF

bash "$SCRIPT" "$SESSIONS" mem demo 1 > "$SCRATCH/out"
grep -F 'ok: appended Round close to 1 codex rounds (0 unchanged)' "$SCRATCH/out" >/dev/null
diff -u "$FIXTURES/append-close-basic.md" "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md"

before="$(sha256sum "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md" | awk '{print $1}')"
bash "$SCRIPT" "$SESSIONS" mem demo 1 > "$SCRATCH/out2"
after="$(sha256sum "$SESSIONS/demo/rounds/round-1-codex-impl-r1.md" | awk '{print $1}')"
[[ "$before" == "$after" ]]
grep -F 'ok: unchanged' "$SCRATCH/out2" >/dev/null

mkdir -p "$SESSIONS/empty/rounds"
bash "$SCRIPT" "$SESSIONS" mem empty 2 > "$SCRATCH/empty.out"
grep -F 'ok: unchanged' "$SCRATCH/empty.out" >/dev/null

cat > "$SESSIONS/demo/rounds/round-1-codex-plan-r2.md" <<'EOF'
# Round 1 codex

## Summary

Plan summary.

## Reviewer 2nd-opinion

skipped: reviewer not required
EOF
bash "$SCRIPT" "$SESSIONS" mem demo 1 >/dev/null
tail -n 3 "$SESSIONS/demo/rounds/round-1-codex-plan-r2.md" | grep -F 'Plan summary. skipped: reviewer not required fix accepted under stage protocol' >/dev/null

cat > "$SESSIONS/demo/rounds/round-1-codex-spec-r3.md" <<'EOF'
# Round 1 codex

## Summary

Spec summary.

## Reviewer 2nd-opinion

unavailable: reviewer service timeout
EOF
bash "$SCRIPT" "$SESSIONS" mem demo 1 >/dev/null
tail -n 3 "$SESSIONS/demo/rounds/round-1-codex-spec-r3.md" | grep -F 'Spec summary. unavailable: reviewer service timeout reviewer unavailable: reviewer service timeout' >/dev/null

cat > "$SESSIONS/demo/rounds/round-1-codex-impl-r4.md" <<'EOF'
# Round 1 codex

## Summary

Heading substring case.

```text
## Round close
```

## Reviewer 2nd-opinion

fix-and-proceed: fenced heading ignored
EOF
bash "$SCRIPT" "$SESSIONS" mem demo 1 >/dev/null
grep -F 'Heading substring case. fix-and-proceed: fenced heading ignored' "$SESSIONS/demo/rounds/round-1-codex-impl-r4.md" >/dev/null
[[ "$(grep -c '^## Round close$' "$SESSIONS/demo/rounds/round-1-codex-impl-r4.md")" -eq 2 ]]

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: append codex round close cases"
