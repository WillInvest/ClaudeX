#!/usr/bin/env bash
# Probes whether the current host has CXMem project/session prerequisites.
# Uses lib-cxmem-slug.sh as the single parser for the active-session slug.
# Usage: probe-cxmem-host.sh
#
# Reads:
#   ${CXMEM_HOME:-${HOME}/CXMem}/projects/<project>/project-memory.md   active session marker
#   ${CXMEM_HOME:-${HOME}/CXMem}/docs/project-memory-template.md        bootstrap template
#   ${RUN_DIR}/.codex-state                         optional warning target
# Writes:
#   ${RUN_DIR}/.codex-state when RUN_DIR is set and writable and session metadata is malformed
# Stdout:
#   CXMEM_HOST_MISSING | CXMEM_HOST_NO_PROJECT | CXMEM_HOST_PROJECT_NO_MEMORY |
#   CXMEM_HOST_PROJECT_NO_SESSION | CXMEM_HOST_PROJECT_READY
# Exit:
#   0 success
#   2 usage
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib-cxmem-slug.sh"

if [[ "$#" -ne 0 ]]; then
  echo "error: usage: probe-cxmem-host.sh" >&2
  exit 2
fi

CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
RESOLVER="$SCRIPT_DIR/resolve-cxmem-project.sh"

warn_no_session() {
  if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" && -w "$RUN_DIR" ]]; then
    printf 'warning: CXMem active session slug missing or empty; using sessionless run path\n' >> "$RUN_DIR/.codex-state"
  fi
}

if [[ ! -d "$CXMEM_ROOT" ]]; then
  echo "CXMEM_HOST_MISSING"
  exit 0
fi

set +e
project="$(CXMEM_HOME="$CXMEM_ROOT" RUN_DIR="${RUN_DIR:-}" bash "$RESOLVER" 2>"${TMPDIR:-/tmp}/probe-cxmem-project.err.$$")"
status=$?
resolver_err="$(cat "${TMPDIR:-/tmp}/probe-cxmem-project.err.$$" 2>/dev/null || true)"
rm -f "${TMPDIR:-/tmp}/probe-cxmem-project.err.$$"
set -e
if [[ "$status" -eq 3 ]]; then
  echo "CXMEM_HOST_NO_PROJECT"
  exit 0
elif [[ "$status" -ne 0 ]]; then
  [[ -n "$resolver_err" ]] && printf '%s\n' "$resolver_err" >&2
  exit "$status"
fi

PROJECT_DIR="$CXMEM_ROOT/projects/$project"
PROJECT_MEMORY="$PROJECT_DIR/project-memory.md"
TEMPLATE="$CXMEM_ROOT/docs/project-memory-template.md"

if [[ ! -f "$PROJECT_MEMORY" ]]; then
  if [[ ! -f "$TEMPLATE" ]]; then
    echo "error: project-memory template missing: $TEMPLATE" >&2
    exit 4
  fi
  tmp="$(mktemp "$PROJECT_DIR/.project-memory.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  python3 - "$TEMPLATE" "$project" "$(date +%F)" > "$tmp" <<'PY'
import sys
template, project, date = sys.argv[1:]
text = open(template, encoding="utf-8").read()
text = text.replace("{{PROJECT}}", project).replace("{{DATE}}", date)
sys.stdout.write(text)
PY
  mv "$tmp" "$PROJECT_MEMORY"
  trap - EXIT
  echo "CXMEM_HOST_PROJECT_NO_MEMORY"
  exit 0
fi

slug="$(parse_cxmem_active_slug "$PROJECT_MEMORY")"
if [[ -n "$slug" ]]; then
  echo "CXMEM_HOST_PROJECT_READY"
else
  warn_no_session
  echo "CXMEM_HOST_PROJECT_NO_SESSION"
fi
