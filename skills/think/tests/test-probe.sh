#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/skills/think/scripts/probe.sh"

set +e
bash "$SCRIPT" >/tmp/claudex-probe-usage-out 2>/tmp/claudex-probe-usage-err
usage_status=$?
set -e
if [[ "$usage_status" -ne 2 ]]; then
  echo "FAIL: usage error exited $usage_status, expected 2"
  rm -f /tmp/claudex-probe-usage-out /tmp/claudex-probe-usage-err
  exit 1
fi
rm -f /tmp/claudex-probe-usage-out /tmp/claudex-probe-usage-err

expected_codex="$(command -v codex >/dev/null && echo CODEX_READY || echo CODEX_MISSING)"
codex_out="$(bash "$SCRIPT" codex)"
if [[ "$codex_out" != "$expected_codex" ]]; then
  echo "FAIL: codex probe emitted $codex_out, expected $expected_codex"
  exit 1
fi

expected_tmux="$(command -v tmux >/dev/null && echo TMUX_PRESENT || echo TMUX_MISSING)"
tmux_out="$(bash "$SCRIPT" tmux)"
if [[ "$tmux_out" != "$expected_tmux" ]]; then
  echo "FAIL: tmux probe emitted $tmux_out, expected $expected_tmux"
  exit 1
fi

build_out="$(bash "$SCRIPT" claudex-build)"
[[ "$build_out" == "CLAUDEX_BUILD_PRESENT" ]]

if bash "$SCRIPT" nope >/tmp/claudex-probe-out 2>/tmp/claudex-probe-err; then
  echo "FAIL: unknown probe was accepted"
  rm -f /tmp/claudex-probe-out /tmp/claudex-probe-err
  exit 1
fi
grep -q 'error: unknown probe: nope' /tmp/claudex-probe-err
rm -f /tmp/claudex-probe-out /tmp/claudex-probe-err

echo "PASS: probe verdicts and unknown refusal"
