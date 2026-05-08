#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/CXMem/projects/proj"

out="$(CXMEM_HOME="$TMP/CXMem" CXMEM_PROJECT=proj bash "$ROOT/skills/self-improve/scripts/resolve-improve-run-dir.sh" 2026-01-01-0000-cac-topic)"
[[ "$out" == "$TMP/CXMem/projects/proj/improvements/2026-01-01-0000-cac-topic" ]] || { echo "FAIL: wrong improve run dir: $out"; exit 1; }

out="$(cd "$TMP/CXMem/projects/proj" && env -u CXMEM_PROJECT CXMEM_HOME="$TMP/CXMem" bash "$ROOT/skills/self-improve/scripts/resolve-improve-run-dir.sh" rid)"
[[ "$out" == "$TMP/CXMem/projects/proj/improvements/rid" ]] || { echo "FAIL: cwd project resolution failed"; exit 1; }

echo "PASS: project resolution"
