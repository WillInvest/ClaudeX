#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/write-cxmem-round.sh"
FIXTURES="$ROOT/skills/build/tests/fixtures/codex-recording"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SCRATCH="$TMP/scratch"
mkdir -p "$SCRATCH/CXMem/projects/mem/sessions"
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR EXIT

normalize_created() {
  sed -E 's/^created: [0-9]{4}-[0-9]{2}-[0-9]{2}$/created: DATE/' "$1"
}

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
printf 'Prompt line\n' > "$SCRATCH/prompt.md"
printf 'Clean output line\n' > "$SCRATCH/clean.md"
printf 'intro\nfix-and-proceed: use this verdict\nready-to-execute: later ignored\nreview tail\n' > "$SCRATCH/review.md"

bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-a" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-skipped "review accepted by protocol" >/dev/null
target="$SCRATCH/CXMem/projects/mem/sessions/slug-a/rounds/round-9-codex-impl-r1.md"
normalize_created "$target" > "$SCRATCH/normal-render.md"
diff -u "$FIXTURES/writer-normal-skipped.md" "$SCRATCH/normal-render.md"

python3 - "$target" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
order = [
    "## Codex prompt (rendered)", "## Codex output (verbatim)",
    "## Reviewer 2nd-opinion", "## Index", "## Records", "## Summary",
]
positions = [text.index(item) for item in order]
assert positions == sorted(positions), positions
PY

cat > "$SCRATCH/prompt-fence.md" <<'EOF'
prompt start
````
literal prompt fence
````
EOF
printf 'output start\n```\nliteral output fence\n```\ntrailing stays\n\n' > "$SCRATCH/output-fence.md"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-bytes" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt-fence.md" --clean-output "$SCRATCH/output-fence.md" --reviewer-unavailable "review tool down" >/dev/null
bytes_target="$SCRATCH/CXMem/projects/mem/sessions/slug-bytes/rounds/round-9-codex-impl-r1.md"
grep -F '`````' "$bytes_target" >/dev/null
python3 - "$bytes_target" "$SCRATCH/prompt-fence.md" "$SCRATCH/output-fence.md" <<'PY'
import re, sys
round_text = open(sys.argv[1], encoding="utf-8").read()
prompt = open(sys.argv[2], encoding="utf-8").read()
output = open(sys.argv[3], encoding="utf-8").read()
pm = re.search(r"## Codex prompt \(rendered\)\n\n`{5}\n(.*?)\n`{5}\n", round_text, re.S)
om = re.search(r"## Codex output \(verbatim\)\n\n`{4}\n(.*?)`{4}\n", round_text, re.S)
assert pm and pm.group(1) + "\n" == prompt
assert om and om.group(1) == output
PY

bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-review" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-review "$SCRATCH/review.md" >/dev/null
review_target="$SCRATCH/CXMem/projects/mem/sessions/slug-review/rounds/round-9-codex-impl-r1.md"
normalize_created "$review_target" > "$SCRATCH/review-render.md"
diff -u "$FIXTURES/writer-review.md" "$SCRATCH/review-render.md"

bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-unavailable" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-unavailable "network unavailable" >/dev/null
normalize_created "$SCRATCH/CXMem/projects/mem/sessions/slug-unavailable/rounds/round-9-codex-impl-r1.md" > "$SCRATCH/unavailable-render.md"
diff -u "$FIXTURES/writer-unavailable.md" "$SCRATCH/unavailable-render.md"

bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-legacy" 9 impl 1 "$parsed" >/dev/null
legacy_target="$SCRATCH/CXMem/projects/mem/sessions/slug-legacy/rounds/round-9-codex-impl-r1.md"
grep -F 'unavailable: reviewer artifact unavailable (legacy writer call)' "$legacy_target" >/dev/null
python3 - "$legacy_target" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
order = [
    "## Codex prompt (rendered)", "## Codex output (verbatim)",
    "## Reviewer 2nd-opinion", "## Index", "## Records", "## Summary",
]
positions = [text.index(item) for item in order]
assert positions == sorted(positions), positions
assert re.search(r"## Codex prompt \(rendered\)\n\n```\n```\n", text)
assert re.search(r"## Codex output \(verbatim\)\n\n```\n```\n", text)
PY

jq '.records[0].round = 4' "$parsed" > "$SCRATCH/mismatch.json"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-mismatch" 9 impl 1 "$SCRATCH/mismatch.json" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-skipped "review accepted by protocol" >/dev/null
grep -F 'codex-emitted round=4 differs from orchestrator round=9' "$SCRATCH/CXMem/projects/mem/sessions/slug-mismatch/rounds/round-9-codex-impl-r1.md" >/dev/null

before="$(sha256sum "$target" | awk '{print $1}')"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-a" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-skipped "review accepted by protocol" >/dev/null
after="$(sha256sum "$target" | awk '{print $1}')"
[[ "$before" == "$after" ]]

log="$SCRATCH/codex.log"
diff="$SCRATCH/diff.txt"
printf 'line one\nline two\nline three\n' > "$log"
printf ' file.txt | 2 ++\n 1 file changed, 2 insertions(+)\n' > "$diff"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-c" 10 impl 2 --degraded "$log" "$diff" >/dev/null
degraded="$SCRATCH/CXMem/projects/mem/sessions/slug-c/rounds/round-10-codex-impl-r2.md"
normalize_created "$degraded" > "$SCRATCH/degraded-render.md"
sed -e "s|$log|LOGPATH|g" "$SCRATCH/degraded-render.md" > "$SCRATCH/degraded-normalized.md"
diff -u "$FIXTURES/writer-degraded.md" "$SCRATCH/degraded-normalized.md"

empty_summary="$SCRATCH/empty-summary.json"
jq '.summary = "\n"' "$parsed" > "$empty_summary"
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-empty" 9 impl 1 "$empty_summary" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-skipped "review accepted by protocol" >/dev/null
grep -F '# Round 9 codex-impl-r1 — Codex CXMem emissions' "$SCRATCH/CXMem/projects/mem/sessions/slug-empty/rounds/round-9-codex-impl-r1.md" >/dev/null

set +e
trap - ERR
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-bad" 9 impl 1 "$parsed" --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" >"$SCRATCH/usage.out" 2>"$SCRATCH/usage.err"
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -eq 2 ]]
grep -F 'exactly one reviewer flag is required' "$SCRATCH/usage.err" >/dev/null

printf 'no verdict here\n' > "$SCRATCH/no-verdict.md"
set +e
trap - ERR
bash "$SCRIPT" "$SCRATCH/CXMem/projects/mem/sessions" mem "slug-bad2" 9 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-review "$SCRATCH/no-verdict.md" >"$SCRATCH/no-verdict.out" 2>"$SCRATCH/no-verdict.err"
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -eq 2 ]]
grep -F 'no verdict line' "$SCRATCH/no-verdict.err" >/dev/null

mkdir -p "$SCRATCH/CXMem/sessions"
set +e
trap - ERR
bash "$SCRIPT" "$SCRATCH/CXMem/sessions" mem "slug-x" 13 impl 1 "$parsed" \
  --prompt "$SCRATCH/prompt.md" --clean-output "$SCRATCH/clean.md" --reviewer-skipped "x" >"$SCRATCH/escape.out" 2>"$SCRATCH/escape.err"
status=$?
set -e
trap 'echo "FAIL: write-cxmem-round failed; scratch: '"$SCRATCH"'"; exit 1' ERR
[[ "$status" -eq 2 ]]
grep -q 'outside projects/mem/sessions' "$SCRATCH/escape.err"

trap - ERR EXIT
rm -rf "$TMP"
echo "PASS: cxmem round writer normal degraded evidence idempotent"
