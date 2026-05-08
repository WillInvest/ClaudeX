#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUN_POST_MIGRATION_TESTS:-0}" != "1" ]]; then
  echo "PASS: skipped post-migration session project frontmatter check"
  exit 0
fi

CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
while IFS= read -r file; do
  rel="${file#"$CXMEM_ROOT/projects/"}"
  project="${rel%%/*}"
  grep -q "^project: $project$" "$file" || { echo "FAIL: missing project frontmatter in $file"; exit 1; }
done < <(find "$CXMEM_ROOT/projects" -path '*/sessions/*' \( -name '*.md' -o -name '.session-meta' \) -type f)

echo "PASS: all session files have matching project frontmatter"
