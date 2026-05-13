#!/usr/bin/env bash
# Launches /claudex:build as a backgrounded `claude --bg` agent so the build
# session registers in `claude agents` / the agent monitor / the dashboard.
# Usage: RUN_ID=<id> RUN_DIR=<dir> CANONICAL_SPEC_PATH=<path> start-bg-build.sh
#
# Reads:
#   RUN_ID
#   RUN_DIR
#   CANONICAL_SPEC_PATH
#   CXMEM_HOME, CXMEM_PROJECT, CXMEM_HOST_STATE, CXMEM_SESSION_SLUG,
#   SESSIONS_ROOT, MAIN_ROUND_SEQ              (inherited and propagated)
# Writes:
#   ${RUN_DIR}/.bg-prompt.md                   stable prompt file
#   ${RUN_DIR}/.bg-launch.out                  captured launch stdout
#   ${RUN_DIR}/.bg-launch.err                  captured launch stderr
# Stdout:
#   claudex-flavored post-launch block (job id, attach/logs/stop, Run-id)
# Exit:
#   0 launched
#   2 usage / missing-file
#   3 `claude --bg` unavailable (CLI lacks flag, or bypass-disclaimer not accepted)
#   4 launch failed (claude returned non-zero, or job-id parse miss)
set -euo pipefail

[[ "$#" -eq 0 ]] || { echo "error: usage: RUN_ID=<id> RUN_DIR=<dir> CANONICAL_SPEC_PATH=<path> start-bg-build.sh" >&2; exit 2; }

RUN_ID="${RUN_ID:-}"
RUN_DIR="${RUN_DIR:-}"
CANONICAL_SPEC_PATH="${CANONICAL_SPEC_PATH:-}"

[[ -n "$RUN_ID" ]]               || { echo "error: RUN_ID is required" >&2; exit 2; }
[[ -n "$RUN_DIR" ]]              || { echo "error: RUN_DIR is required" >&2; exit 2; }
[[ -n "$CANONICAL_SPEC_PATH" ]]  || { echo "error: CANONICAL_SPEC_PATH is required" >&2; exit 2; }
[[ -d "$RUN_DIR" ]]              || { echo "error: RUN_DIR not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$CANONICAL_SPEC_PATH" ]]  || { echo "error: canonical spec not found: $CANONICAL_SPEC_PATH" >&2; exit 2; }

if ! command -v claude >/dev/null; then
  echo "error: claude CLI not on PATH" >&2
  exit 3
fi
if ! claude --help 2>/dev/null | grep -q -- '--bg'; then
  echo "error: claude CLI lacks --bg (need ≥2.1.140). Run: claude install --version stable" >&2
  exit 3
fi

CXMEM_PROJECT_TOKEN="${CXMEM_PROJECT:-unknown-project}"
SANITIZED_NAME="$(printf '%s' "claudex-build-${CXMEM_PROJECT_TOKEN}-${RUN_ID}" | LC_ALL=C tr -c '[:alnum:]._-' '_' | cut -c1-64)"

STABLE_PROMPT="$RUN_DIR/.bg-prompt.md"
LAUNCH_OUT="$RUN_DIR/.bg-launch.out"
LAUNCH_ERR="$RUN_DIR/.bg-launch.err"

{
  printf '/claudex:build %s\n' "$CANONICAL_SPEC_PATH"
  HOOK="$HOME/.claude/claudex/post-build-hook.md"
  if [[ -s "$HOOK" ]]; then
    printf '\n--- post-build hook (%s) ---\n' "$HOOK"
    cat "$HOOK"
  fi
} > "$STABLE_PROMPT"

PROMPT_BODY="$(cat "$STABLE_PROMPT")"

# Launch. Capture stdout and stderr to run-local files.
set +e
RUN_ID="$RUN_ID" RUN_DIR="$RUN_DIR" CANONICAL_SPEC_PATH="$CANONICAL_SPEC_PATH" \
  CXMEM_HOME="${CXMEM_HOME:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" \
  CXMEM_HOST_STATE="${CXMEM_HOST_STATE:-}" CXMEM_SESSION_SLUG="${CXMEM_SESSION_SLUG:-}" \
  SESSIONS_ROOT="${SESSIONS_ROOT:-}" MAIN_ROUND_SEQ="${MAIN_ROUND_SEQ:-}" \
  claude --bg --permission-mode bypassPermissions --name "$SANITIZED_NAME" -p "$PROMPT_BODY" \
  >"$LAUNCH_OUT" 2>"$LAUNCH_ERR"
LAUNCH_STATUS=$?
set -e

if [[ $LAUNCH_STATUS -ne 0 ]]; then
  if grep -q 'requires accepting the disclaimer' "$LAUNCH_ERR" 2>/dev/null; then
    echo 'error: claude --bg requires accepting the bypass-permissions disclaimer first.' >&2
    echo 'Run `claude --dangerously-skip-permissions` once interactively.' >&2
    exit 3
  fi
  echo "error: claude --bg launch failed (exit $LAUNCH_STATUS)" >&2
  if [[ -s "$LAUNCH_ERR" ]]; then
    tail -20 "$LAUNCH_ERR" >&2
  fi
  exit 4
fi

# Strip ANSI escapes from launch stdout for stable parsing.
# `set -e + pipefail` would propagate grep's no-match (exit 1) before we can
# translate it to exit 4 below — relax the trap for this single extraction.
set +e
SHORT_ID="$(sed -E 's/\x1B\[[0-9;]*[mGKHF]//g' "$LAUNCH_OUT" | head -1 | grep -oE 'backgrounded · [0-9a-f]{8}' | awk '{print $NF}')"
set -e

if [[ -z "$SHORT_ID" ]]; then
  echo "error: could not parse job id from claude --bg stdout" >&2
  echo "--- launch stdout ---" >&2
  cat "$LAUNCH_OUT" >&2
  exit 4
fi

cat <<EOF
[claudex] Build running as backgrounded claude agent
  Job:       ${SHORT_ID} (name: ${SANITIZED_NAME})
  Dashboard: claude agents          # also: the agent monitor in the TUI
  Attach:    claude attach ${SHORT_ID}
  Logs:      claude logs ${SHORT_ID}
  Summary:   ${RUN_DIR}/99-final-summary.md  (after build)
  Run trail: ${RUN_DIR}/
  Stop:      claude stop ${SHORT_ID}
Run-id: ${RUN_ID}
EOF
