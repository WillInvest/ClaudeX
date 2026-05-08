#!/usr/bin/env bash
# Resolves the run artifact directory for a claudex run.
# Uses lib-cxmem-slug.sh as the single parser for the active-session slug.
# Usage: resolve-run-dir.sh <run-id>
#
# Reads:
#   ${CXMEM_HOST_STATE}                            optional override; if unset, probe-cxmem-host.sh is invoked
#   ${CXMEM_HOME:-${HOME}/CXMem}/projects/<project>/project-memory.md  active session pointer (READY case)
#   ${RUN_DIR}                                     transitively, when probe runs
# Writes:
#   ${RUN_DIR}/.codex-state                        transitively, when probe finds malformed session metadata
# Stdout:
#   absolute run directory path
# Exit:
#   0 success
#   2 usage / invalid host state
#   3 no project / no memory
set -euo pipefail

if [[ "$#" -ne 1 || -z "${1:-}" ]]; then
  echo "error: usage: resolve-run-dir.sh <run-id>" >&2
  exit 2
fi

RUN_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib-cxmem-slug.sh"
CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
STATE="${CXMEM_HOST_STATE:-}"
RESOLVER="$SCRIPT_DIR/resolve-cxmem-project.sh"

if [[ -z "$STATE" ]]; then
  STATE="$(CXMEM_HOME="$CXMEM_ROOT" bash "$SCRIPT_DIR/probe-cxmem-host.sh")"
fi

case "$STATE" in
  CXMEM_HOST_PROJECT_READY)
    PROJECT="$(CXMEM_HOME="$CXMEM_ROOT" RUN_DIR="${RUN_DIR:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" bash "$RESOLVER")"
    PROJECT_MEMORY="$CXMEM_ROOT/projects/$PROJECT/project-memory.md"
    slug="$(parse_cxmem_active_slug "$PROJECT_MEMORY")"
    if [[ -n "$slug" ]]; then
      printf '%s\n' "$CXMEM_ROOT/projects/$PROJECT/sessions/$slug/runs/$RUN_ID"
    else
      printf '%s\n' "$CXMEM_ROOT/projects/$PROJECT/runs/$RUN_ID"
    fi
    ;;
  CXMEM_HOST_PROJECT_NO_SESSION)
    PROJECT="$(CXMEM_HOME="$CXMEM_ROOT" RUN_DIR="${RUN_DIR:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" bash "$RESOLVER")"
    printf '%s\n' "$CXMEM_ROOT/projects/$PROJECT/runs/$RUN_ID"
    ;;
  CXMEM_HOST_NO_PROJECT)
    echo "error: CXMem host has no resolved project; cannot resolve project-scoped run dir" >&2
    exit 3
    ;;
  CXMEM_HOST_PROJECT_NO_MEMORY)
    echo "error: CXMem project memory is missing or was just bootstrapped; cannot resolve run dir" >&2
    exit 3
    ;;
  CXMEM_HOST_MISSING)
    printf '%s\n' "$HOME/vault/projects/claudex/audits/$RUN_ID"
    ;;
  *)
    echo "error: invalid CXMEM_HOST_STATE: $STATE" >&2
    exit 2
    ;;
esac
