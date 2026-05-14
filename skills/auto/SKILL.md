---
name: auto
description: Opt-in wrapper that marks a claudex run as auto mode, then delegates to claudex-think.
---

# claudex — usage notes

These skills (`/claudex:think`, `/claudex:build`, `/claudex:auto`) cooperate closely with **CXMem** (`~/CXMem/`), the central memory store. Personal info, project context, and learned preferences live there — not in plugin source.

CXMem records the raw transcript per round: the user prompt, verbatim assistant output, the agent's plan and reasoning, tool calls and findings, and a concise summary indexed in `session-memory.md` and `project-memory.md`. Future agents read `project-memory.md` first, then drill into the active session.

Source files for each project live under `~/vault/projects/<X>/` (each is its own git repo); transcripts live under `~/CXMem/projects/<X>/`. After `claudex:build` finishes IMPLEMENT, commit source changes in the vault repo *before* writing `99-summary.md`; reference the commit SHA in the summary.

Auto mode (`/claudex:auto`, sentinel `${RUN_DIR}/.mode-auto`) launches `claudex:build` as a backgrounded `claude --bg` session displayed as `claudex-build-${CXMEM_PROJECT}-${RUN_ID}` in `claude agents` / the agent monitor. A session is finished when its run directory contains `99-summary.md` — those backgrounded agents are safe to `claude stop`; do not stop mid-stage ones.

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
