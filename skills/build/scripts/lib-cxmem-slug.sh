#!/usr/bin/env bash
# Shared CXMem active-session slug parser for probe-cxmem-host.sh and resolve-run-dir.sh.

parse_cxmem_active_slug() {
  local project_memory="${1:-}"
  local active_line
  local slug

  if [[ -z "$project_memory" || ! -f "$project_memory" ]]; then
    return 0
  fi

  active_line="$(grep -m 1 '^\*\*Active session\*\*: `' "$project_memory" 2>/dev/null || true)"
  slug="${active_line#**Active session**: \`}"
  slug="${slug%%\`*}"

  if [[ -n "$active_line" && -n "$slug" && "$slug" != "$active_line" ]]; then
    printf '%s\n' "$slug"
  fi
}
