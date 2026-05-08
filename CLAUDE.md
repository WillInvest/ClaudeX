# claudex — usage notes

These skills (`/claudex:think`, `/claudex:build`, `/claudex:auto`) cooperate closely with **CXMem** (`~/CXMem/`), the central memory store. Personal info, project context, and learned preferences live there — not in plugin source.

CXMem records the raw transcript per round: the user prompt, verbatim assistant output, the agent's plan and reasoning, tool calls and findings, and a concise summary indexed in `session-memory.md` and `project-memory.md`. Future agents read `project-memory.md` first, then drill into the active session.

Source files for each project live under `~/vault/projects/<X>/` (each is its own git repo); transcripts live under `~/CXMem/projects/<X>/`. After `claudex:build` finishes IMPLEMENT, commit source changes in the vault repo *before* writing `99-summary.md`; reference the commit SHA in the summary.

Auto mode (`/claudex:auto`, sentinel `${RUN_DIR}/.mode-auto`) launches `claudex:build` in a detached tmux session named `claudex-build-${CXMEM_PROJECT}-${RUN_ID}`. A session is finished when its run directory contains `99-summary.md` — those tmux sessions are safe to kill; do not kill mid-stage ones.
