#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/skills/self-improve/SKILL.md"

grep -q 'Mission ID collision' "$SKILL" || { echo "FAIL: collision phrase missing"; exit 1; }
grep -q 'exit before any projections are populated' "$SKILL" || { echo "FAIL: collision ordering missing"; exit 1; }
grep -q 'checked before projection' "$SKILL" || { echo "FAIL: pre-projection collision check missing"; exit 1; }

echo "PASS: mission id collision"
