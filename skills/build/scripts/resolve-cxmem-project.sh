#!/usr/bin/env bash
# Resolves the active CXMem project name.
# Usage: resolve-cxmem-project.sh
#
# Reads:
#   ${CXMEM_HOME:-${HOME}/CXMem}/projects/<project>
#   ${CXMEM_PROJECT}                         optional env override
#   ${PWD}                                   cwd-derived project fallback
#   ${RUN_DIR}/.codex-state                  optional warning target
# Writes:
#   ${RUN_DIR}/.codex-state when env/cwd project mismatch is detected
# Stdout:
#   project name
# Exit:
#   0 success
#   2 usage / invalid CXMEM_PROJECT
#   3 no project could be resolved
#   4 CXMem host/project runtime failure
set -euo pipefail

if [[ "$#" -ne 0 ]]; then
  echo "error: usage: resolve-cxmem-project.sh" >&2
  exit 2
fi

CXMEM_ROOT="${CXMEM_HOME:-${HOME}/CXMem}"
PROJECTS_DIR="$CXMEM_ROOT/projects"

validate_project_name() {
  local name="${1:-}"
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ && "$name" != "." && "$name" != ".." ]]
}

append_warning() {
  local msg="$1"
  if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" && -w "$RUN_DIR" ]]; then
    printf '%s\n' "$msg" >> "$RUN_DIR/.codex-state"
  fi
}

if [[ ! -d "$CXMEM_ROOT" ]]; then
  echo "error: CXMem host missing: $CXMEM_ROOT" >&2
  exit 4
fi
if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "error: CXMem projects directory missing: $PROJECTS_DIR" >&2
  exit 4
fi

real_projects="$(realpath "$PROJECTS_DIR")" || { echo "error: cannot resolve projects dir: $PROJECTS_DIR" >&2; exit 4; }

cwd_project=""
cwd_real="$(realpath "${PWD:-.}" 2>/dev/null || true)"
if [[ -n "$cwd_real" ]]; then
  case "$cwd_real/" in
    "$real_projects"/*)
      rel="${cwd_real#"$real_projects"/}"
      cwd_project="${rel%%/*}"
      ;;
  esac
fi
if [[ -z "$cwd_project" && -n "${PWD:-}" ]]; then
  case "${PWD%/}/" in
    "$PROJECTS_DIR"/*)
      rel="${PWD#"$PROJECTS_DIR"/}"
      cwd_project="${rel%%/*}"
      ;;
  esac
fi

guard_project_path() {
  local name="$1"
  local path="$PROJECTS_DIR/$name"
  [[ -d "$path" ]] || { echo "error: CXMem project directory missing: $path" >&2; exit 3; }
  local real_project
  real_project="$(realpath "$path")" || { echo "error: cannot resolve project directory: $path" >&2; exit 4; }
  case "$real_project/" in
    "$real_projects"/*) ;;
    *) echo "error: CXMem project path escapes projects root: $path -> $real_project" >&2; exit 3 ;;
  esac
}

if [[ -n "${CXMEM_PROJECT:-}" ]]; then
  if ! validate_project_name "$CXMEM_PROJECT"; then
    echo "error: invalid CXMEM_PROJECT: $CXMEM_PROJECT" >&2
    echo "error: project names must match ^[A-Za-z0-9._-]+$ and must not be '.' or '..'" >&2
    exit 2
  fi
  guard_project_path "$CXMEM_PROJECT"
  if [[ -n "$cwd_project" && "$cwd_project" != "$CXMEM_PROJECT" ]]; then
    append_warning "warning: CXMEM_PROJECT=$CXMEM_PROJECT differs from cwd-derived project $cwd_project"
  fi
  printf '%s\n' "$CXMEM_PROJECT"
  exit 0
fi

if [[ -n "$cwd_project" ]]; then
  if ! validate_project_name "$cwd_project"; then
    echo "error: invalid cwd-derived CXMem project: $cwd_project" >&2
    exit 3
  fi
  guard_project_path "$cwd_project"
  printf '%s\n' "$cwd_project"
  exit 0
fi

cat >&2 <<EOF
error: no CXMem project resolved for cwd: ${PWD:-}
error: cwd is not under ${PROJECTS_DIR}/<project>/; no projects/<X>/ ancestor found
hint: cd into ${PROJECTS_DIR}/<project>/...
hint: or set CXMEM_PROJECT=<name>
EOF
exit 3
