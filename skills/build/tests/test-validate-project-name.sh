#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/build/scripts/resolve-cxmem-project.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CXMEM_HOME="$TMP/cxmem"
mkdir -p "$CXMEM_HOME/projects/valid-1" "$CXMEM_HOME/projects/claudex.imp" "$CXMEM_HOME/projects/.hidden" "$CXMEM_HOME/projects/bad..name" "$CXMEM_HOME/projects/_under"

[[ "$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=valid-1 bash "$SCRIPT")" == "valid-1" ]]
[[ "$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=claudex.imp bash "$SCRIPT")" == "claudex.imp" ]]
[[ "$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=.hidden bash "$SCRIPT")" == ".hidden" ]]
[[ "$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=bad..name bash "$SCRIPT")" == "bad..name" ]]
[[ "$(CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT=_under bash "$SCRIPT")" == "_under" ]]

for bad in '.' '..' '../escape' 'bad/name'; do
  set +e
  CXMEM_HOME="$CXMEM_HOME" CXMEM_PROJECT="$bad" bash "$SCRIPT" >"$TMP/out" 2>"$TMP/err"
  status=$?
  set -e
  [[ "$status" -eq 2 ]]
  grep -q 'invalid CXMEM_PROJECT' "$TMP/err"
done

echo "PASS: cxmem project name validation follows canonical regex and rejects dot sentinels/escapes"
