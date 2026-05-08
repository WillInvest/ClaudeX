#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${HOME}/CXMem/projects/mem/artifacts/migrate-r12.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/sessions/s1" "$CXMEM_HOME/projects/mem"
git -C "$TMP" init -q cxmem
git -C "$CXMEM_HOME" config user.email test@example.invalid
git -C "$CXMEM_HOME" config user.name Test
printf 'tracked\n' > "$CXMEM_HOME/sessions/s1/file.md"
git -C "$CXMEM_HOME" add sessions/s1/file.md
git -C "$CXMEM_HOME" commit -q -m initial

CXMEM_HOME="$CXMEM_HOME" bash "$SCRIPT" --force >/dev/null
git -C "$CXMEM_HOME" status --short > "$TMP/status"
grep -q '^R  sessions/s1/file.md -> projects/mem/sessions/s1/file.md' "$TMP/status"

echo "PASS: migrate-r12 uses git mv for tracked files"
