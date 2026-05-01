#!/usr/bin/env bash
# Launches /claudex:build for SPEC_PATH inside a detached tmux session.
# Prints the session name and operating instructions to stdout.
# Usage: start-tmux-build.sh <spec-path>
set -euo pipefail

SPEC_PATH="${1:?usage: start-tmux-build.sh <spec-path>}"
[[ -f "$SPEC_PATH" ]] || { echo "error: spec not found: $SPEC_PATH" >&2; exit 1; }
command -v tmux >/dev/null || { echo "error: tmux not on PATH" >&2; exit 1; }
command -v claude >/dev/null || { echo "error: claude CLI not on PATH" >&2; exit 1; }

# Derive slug from spec basename.
spec_base="$(basename "$SPEC_PATH" .md)"
# Match brainstorming spec filenames: YYYY-MM-DD-<topic>-design.md -> <topic>.
slug="$(echo "$spec_base" \
  | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//' \
  | sed -E 's/-design$//')"

# Compute run-id and tmux session name.
RUN_ID="$(date -u +%Y-%m-%d-%H%M)-${slug}"
HMS="$(date +%H%M%S)"
SESSION_NAME="claudex-build-${slug}-${HMS}"

# Collision guard: if SESSION_NAME already exists, append -2, -3, ...
n=2
while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
  SESSION_NAME="claudex-build-${slug}-${HMS}-${n}"
  n=$((n+1))
done

# Build the prompt as a tmpfile (no shell substitution into tmux command).
PROMPT_FILE="$(mktemp -t claudex-prompt.XXXXXX)"
trap 'rm -f "$PROMPT_FILE"' EXIT

{
  printf '/claudex:build %s\n' "$SPEC_PATH"
  HOOK="$HOME/.claude/claudex/post-build-hook.md"
  if [[ -s "$HOOK" ]]; then
    printf '\n--- post-build hook (%s) ---\n' "$HOOK"
    cat "$HOOK"
  fi
} > "$PROMPT_FILE"

# Launch detached with a stable prompt path for stdin redirection.
STABLE_PROMPT="/tmp/claudex/prompts/${RUN_ID}.prompt.md"
mkdir -p "$(dirname "$STABLE_PROMPT")"
cp "$PROMPT_FILE" "$STABLE_PROMPT"

# bypassPermissions is required for unattended detached runs — `auto` and
# `acceptEdits` still raise interactive prompts (reads outside cwd, network,
# MCP tools), and there is no user attached to answer them.
tmux new-session -d -s "$SESSION_NAME" \
  "RUN_ID='${RUN_ID}' claude --permission-mode bypassPermissions < '${STABLE_PROMPT}' ; exec bash"

cat <<EOF
[claudex] Build running in tmux session: ${SESSION_NAME}
  Attach:    tmux attach -t ${SESSION_NAME}
  Detach:    Ctrl-b d
  Summary:   /tmp/claudex/${RUN_ID}/99-final-summary.md  (after build)
  Audit:     /tmp/claudex/${RUN_ID}/
  Kill:      tmux kill-session -t ${SESSION_NAME}

Run-id: ${RUN_ID}
EOF
