#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 1 ]] || { echo "error: usage: resolve-improve-run-dir.sh <self-improve-run-id>" >&2; exit 2; }

RUN_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT="$(bash "$ROOT/skills/build/scripts/resolve-cxmem-project.sh")"
CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"

printf '%s\n' "$CXMEM_ROOT/projects/$PROJECT/improvements/$RUN_ID"
