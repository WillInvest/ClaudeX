#!/usr/bin/env bash
# Launches /claudex:build in a detached tmux session using handoff env vars.
# Usage: RUN_ID=<id> RUN_DIR=<dir> CANONICAL_SPEC_PATH=<path> start-tmux-build.sh
#
# Reads:
#   RUN_ID
#   RUN_DIR
#   CANONICAL_SPEC_PATH
#   CXMEM_PROJECT
# Writes:
#   ${RUN_DIR}/.tmux-prompt.md
# Stdout:
#   tmux attach instructions
# Exit:
#   0 launched
#   2 usage / missing-file
#   3 tmux or claude missing from PATH
#   4 tmux session creation failed
set -euo pipefail

[[ "$#" -eq 0 ]] || { echo "error: usage: RUN_ID=<id> RUN_DIR=<dir> CANONICAL_SPEC_PATH=<path> start-tmux-build.sh" >&2; exit 2; }

RUN_ID="${RUN_ID:-}"
RUN_DIR="${RUN_DIR:-}"
CANONICAL_SPEC_PATH="${CANONICAL_SPEC_PATH:-}"

[[ -n "$RUN_ID" ]] || { echo "error: RUN_ID is required" >&2; exit 2; }
[[ -n "$RUN_DIR" ]] || { echo "error: RUN_DIR is required" >&2; exit 2; }
[[ -n "$CANONICAL_SPEC_PATH" ]] || { echo "error: CANONICAL_SPEC_PATH is required" >&2; exit 2; }
[[ -d "$RUN_DIR" ]] || { echo "error: RUN_DIR not found: $RUN_DIR" >&2; exit 2; }
[[ -f "$CANONICAL_SPEC_PATH" ]] || { echo "error: canonical spec not found: $CANONICAL_SPEC_PATH" >&2; exit 2; }

if ! command -v tmux >/dev/null; then
  echo "error: tmux not on PATH; install with: sudo apt install tmux  # Debian/Ubuntu; brew install tmux  # macOS" >&2
  exit 3
fi
if ! command -v claude >/dev/null; then
  echo "error: claude CLI not on PATH" >&2
  exit 3
fi

CXMEM_PROJECT_TOKEN="${CXMEM_PROJECT:-unknown-project}"
SESSION_NAME="claudex-build-${CXMEM_PROJECT_TOKEN}-${RUN_ID}"
STABLE_PROMPT="$RUN_DIR/.tmux-prompt.md"

{
  printf '/claudex:build %s\n' "$CANONICAL_SPEC_PATH"
  HOOK="$HOME/.claude/claudex/post-build-hook.md"
  if [[ -s "$HOOK" ]]; then
    printf '\n--- post-build hook (%s) ---\n' "$HOOK"
    cat "$HOOK"
  fi
} > "$STABLE_PROMPT"

if ! tmux new-session -d -s "$SESSION_NAME" \
  -e "RUN_ID=$RUN_ID" \
  -e "RUN_DIR=$RUN_DIR" \
  -e "CANONICAL_SPEC_PATH=$CANONICAL_SPEC_PATH" \
  -e "CXMEM_HOME=${CXMEM_HOME:-}" \
  -e "CXMEM_PROJECT=${CXMEM_PROJECT:-}" \
  -e "CXMEM_HOST_STATE=${CXMEM_HOST_STATE:-}" \
  -e "CXMEM_SESSION_SLUG=${CXMEM_SESSION_SLUG:-}" \
  -e "SESSIONS_ROOT=${SESSIONS_ROOT:-}" \
  -e "MAIN_ROUND_SEQ=${MAIN_ROUND_SEQ:-}" \
  "claude --permission-mode bypassPermissions < '$STABLE_PROMPT' ; exec bash"; then
  echo "error: failed to create tmux session: $SESSION_NAME" >&2
  exit 4
fi

cat <<EOF
[claudex] Build running in tmux session: ${SESSION_NAME}
  Attach:    tmux attach -t ${SESSION_NAME}
  Detach:    Ctrl-b d
  Summary:   ${RUN_DIR}/99-final-summary.md  (after build)
  Run trail: ${RUN_DIR}/
  Kill:      tmux kill-session -t ${SESSION_NAME}

Run-id: ${RUN_ID}
EOF
