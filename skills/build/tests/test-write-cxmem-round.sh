#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/write-cxmem-round.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
mkdir -p "$SCRATCH/CXMem/projects/mem/sessions"
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

parsed="$SCRATCH/parsed.json"
cat > "$parsed" <<'EOF'
{
  "records": [
    {
      "version": 1,
      "stage": "impl",
      "round": 9,
      "seq": 1,
      "tool": "Read",
      "plan": "Inspect.",
      "tool_summary": "Inspected",
      "findings": ["Found pattern"],
      "next_plan": "Write."
    }
  ],
  "index": "| ID | Summary | Source |\n|---|---|---|\n| 9.1 | Inspected | log |\n",
  "summary": "Normal summary.\n",
  "warnings": ["parser warning one"]
}
EOF

bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-a" 9 impl 1 "$parsed" >/dev/null
target="$SCRATCH/CXMem/projects/mem/sessions/slug-a/rounds/round-9-codex-impl-r1.md"
[[ -f "$target" ]]
grep -F 'type: round-memory' "$target" >/dev/null
grep -F 'session-id: slug-a' "$target" >/dev/null
grep -F 'project: mem' "$target" >/dev/null
grep -F 'round: 9' "$target" >/dev/null
grep -F 'created:' "$target" >/dev/null
grep -F '## Index' "$target" >/dev/null
grep -F '## Records' "$target" >/dev/null
grep -F '### Record 9.1' "$target" >/dev/null
grep -F '## Summary' "$target" >/dev/null
grep -F 'Parser warnings:' "$target" >/dev/null
grep -F 'parser warning one' "$target" >/dev/null

jq '.records[0].round = 4' "$parsed" > "$SCRATCH/mismatch.json"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-b" 9 impl 1 "$SCRATCH/mismatch.json" >/dev/null
grep -F 'codex-emitted round=4 differs from orchestrator round=9' "$SCRATCH/CXMem/projects/mem/sessions/slug-b/rounds/round-9-codex-impl-r1.md" >/dev/null

log="$SCRATCH/codex.log"
diff="$SCRATCH/diff.txt"
printf 'line one\nline two\nline three\n' > "$log"
printf ' file.txt | 2 ++\n 1 file changed, 2 insertions(+)\n' > "$diff"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-c" 10 impl 2 --degraded "$log" "$diff" >/dev/null
degraded="$SCRATCH/CXMem/projects/mem/sessions/slug-c/rounds/round-10-codex-impl-r2.md"
grep -F 'type: round-memory' "$degraded" >/dev/null
grep -F 'project: mem' "$degraded" >/dev/null
grep -F 'codex exec' "$degraded" >/dev/null
grep -F 'Fallback was used' "$degraded" >/dev/null
grep -F "Raw log path: \`$log\`" "$degraded" >/dev/null
grep -F 'file.txt | 2 ++' "$degraded" >/dev/null
grep -F 'line three' "$degraded" >/dev/null

before="$(sha256sum "$target" | awk '{print $1}')"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-a" 9 impl 1 "$parsed" >/dev/null
after="$(sha256sum "$target" | awk '{print $1}')"
[[ "$before" == "$after" ]]

stub="$SCRATCH/stubbin"
mkdir -p "$stub"
cat > "$stub/mv" <<'EOF'
#!/usr/bin/env bash
echo invoked > "$CLAUDEX_MV_STUB_LOG"
exit 1
EOF
chmod +x "$stub/mv"

set +e
trap - ERR
CLAUDEX_MV_STUB_LOG="$SCRATCH/mv-new.log" PATH="$stub:$PATH" bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-d" 11 impl 1 "$parsed" >/dev/null 2>/dev/null
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -ne 0 ]]
[[ -f "$SCRATCH/mv-new.log" ]]
[[ ! -f "$SCRATCH/CXMem/projects/mem/sessions/slug-d/rounds/round-11-codex-impl-r1.md" ]]

pre="$SCRATCH/CXMem/projects/mem/sessions/slug-e/rounds/round-12-codex-impl-r1.md"
mkdir -p "$(dirname "$pre")"
printf 'preexisting\n' > "$pre"
pre_hash="$(sha256sum "$pre" | awk '{print $1}')"
set +e
trap - ERR
CLAUDEX_MV_STUB_LOG="$SCRATCH/mv-existing.log" PATH="$stub:$PATH" bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-e" 12 impl 1 "$parsed" >/dev/null 2>/dev/null
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -ne 0 ]]
[[ -f "$SCRATCH/mv-existing.log" ]]
post_hash="$(sha256sum "$pre" | awk '{print $1}')"
[[ "$pre_hash" == "$post_hash" ]]

mkdir -p "$SCRATCH/CXMem/sessions"
set +e
trap - ERR
bash "$SCRIPT" "$SCRATCH/CXMem/sessions" mem "slug-x" 13 impl 1 "$parsed" >"$SCRATCH/escape.out" 2>"$SCRATCH/escape.err"
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -eq 2 ]]
grep -q 'outside projects/mem/sessions' "$SCRATCH/escape.err"

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: cxmem round writer normal degraded idempotent atomic"
