---
name: auto
description: Opt-in wrapper that marks a claudex run as auto mode, then delegates to claudex-think.
---

# auto

Use `/auto <topic>` when the user wants the normal `/claudex:think` workflow to auto-accept safe second-opinion gates and conditionally launch `/claudex:build`.

Follow the same Stage 0 setup and path-resolution rules as `~/.claude/plugins/claudex/skills/think/SKILL.md`: derive `SLUG` as a short kebab-case slug from `<topic>`, create `RUN_ID`, resolve `RUN_DIR`, and pass both to think.

Before delegating, create only the persistent auto-mode sentinel:

```bash
SLUG="<short-kebab-case-topic>"
export RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-$SLUG}"
RUN_DIR="$(bash ../build/scripts/resolve-run-dir.sh "$RUN_ID")"
export RUN_DIR
mkdir -p "$RUN_DIR"
: > "$RUN_DIR/.mode-auto"
```

Then invoke `/claudex:think <topic>` with the exported `RUN_ID` and `RUN_DIR` in scope. Never delete `${RUN_DIR}/.mode-auto`; it is part of the audit trail.
