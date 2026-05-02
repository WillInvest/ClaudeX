#!/usr/bin/env bash
# Probes local tools and skill handoff targets for /claudex:think.
# Usage: probe.sh <codex|tmux|claudex-build>
#
# Reads:
#   PATH                              command lookup path for codex/tmux
#   ../../build/SKILL.md              canonical claudex-build skill location
# Writes:
#   none
# Stdout:
#   One allowed token:
#   codex: CODEX_READY | CODEX_MISSING
#   tmux: TMUX_PRESENT | TMUX_MISSING
#   claudex-build: CLAUDEX_BUILD_PRESENT | CLAUDEX_BUILD_MISSING
# Exit:
#   0 success; token emitted
#   2 usage / unknown probe
#   3 unused
#   4 unused
#   5 unused
# SKILL.md next-step contract: route from the emitted token table in Stage 0/5.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "error: usage: probe.sh <codex|tmux|claudex-build>" >&2
  exit 2
fi

NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$NAME" in
  codex)
    command -v codex >/dev/null && echo "CODEX_READY" || echo "CODEX_MISSING"
    ;;
  tmux)
    command -v tmux >/dev/null && echo "TMUX_PRESENT" || echo "TMUX_MISSING"
    ;;
  claudex-build)
    [[ -f "$SCRIPT_DIR/../../build/SKILL.md" ]] && echo "CLAUDEX_BUILD_PRESENT" || echo "CLAUDEX_BUILD_MISSING"
    ;;
  *)
    echo "error: unknown probe: $NAME" >&2
    exit 2
    ;;
esac
