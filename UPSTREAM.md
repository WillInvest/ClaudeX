# Upstream merge log

ClaudeX is a fork of `superpowers`. Every upstream release should
trigger a merge pass. Record each merge here.

## Fork base

- Upstream: `superpowers@claude-plugins-official` version `5.0.7`
- Source path at fork time: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
- Fork date: 2026-04-30

## Scope: Claude Code only

ClaudeX targets Claude Code exclusively. Upstream supports multiple
harnesses (Codex CLI as a host, OpenCode, Cursor, Gemini); ClaudeX uses
Codex CLI only as a *worker* dispatched by the orchestrator (`codex
exec`), not as a host harness. The following upstream surfaces are
dropped at fork and stay dropped on every merge:

- `.codex/`, `.codex-plugin/`, `.cursor-plugin/`, `.opencode/`
- `gemini-extension.json`, `GEMINI.md`, `AGENTS.md`
- `docs/README.codex.md`, `docs/README.opencode.md`
- `tests/codex-plugin-sync/`, `tests/opencode/`, `tests/brainstorm-server/`
- `scripts/sync-to-codex-plugin.sh`
- `hooks/hooks-cursor.json`, `hooks/run-hook.cmd` (Windows polyglot)
- `docs/windows/`

Upstream governance/history that points at obra is also dropped:

- `RELEASE-NOTES.md`, `CODE_OF_CONDUCT.md`
- `.github/FUNDING.yml`, `.github/PULL_REQUEST_TEMPLATE.md`,
  `.github/ISSUE_TEMPLATE/`
- `docs/plans/`, `docs/superpowers/`
- `assets/superpowers-small.svg`

## Modification surface

Files in the fork that diverge from upstream (every divergence is
wrapped in `<!-- CLAUDEX:BEGIN -->` / `<!-- CLAUDEX:END -->` markers):

- `package.json` — full file diverges (name, version, no opencode `main`)
- `hooks/hooks.json` — `command` points at `hooks/session-start` directly
  (upstream uses the polyglot `run-hook.cmd` wrapper)
- `.gitattributes` — no `*.cmd` rule
- `.version-bump.json` — only the three Claude Code manifests
- `skills/brainstorming/SKILL.md` — three insertion blocks
- `commands/brainstorm.md` — single insertion block (deprecation-stub redirect)
- New, no upstream counterpart:
  - `README.md`, `UPSTREAM.md`
  - `skills/claudex-build/` (entire directory)
  - `commands/claudex-build.md`

## Merge procedure

When upstream releases a new version (e.g., `5.1.0`):

1. Clone the new upstream version locally for diffing.
2. **Skip every path in the "Scope: Claude Code only" section above.**
   Don't merge them in even if upstream changed them.
3. For files NOT in the modification list and NOT in the dropped scope,
   copy upstream-new into `~/.claude/plugins/claudex/` directly — no
   conflicts possible.
4. For each modified file, do a 3-way merge:
   - Old upstream (e.g., `5.0.7`)
   - New upstream (e.g., `5.1.0`)
   - This fork
   The `CLAUDEX:BEGIN`/`CLAUDEX:END` markers make the fork's additions
   trivially identifiable; conflicts only arise when upstream rewrote
   the surrounding sections.
5. Append a section to this file: `## Merged: <date> upstream <ver>`
   listing any conflicts resolved and how.
6. Bump claudex version in `package.json` (e.g., `0.1.0` → `0.1.1`).

## Merge log

(none yet — initial fork)
