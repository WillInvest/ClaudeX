# Upstream merge log

ClaudeX is a fork of `superpowers`. Every upstream release should
trigger a merge pass. Record each merge here.

## Fork base

- Upstream: `superpowers@claude-plugins-official` version `5.0.7`
- Source path at fork time: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
- Fork date: 2026-04-30

## Modification surface

Files in the fork that diverge from upstream (every divergence is
wrapped in `<!-- CLAUDEX:BEGIN -->` / `<!-- CLAUDEX:END -->` markers):

- `package.json` — full file diverges (name, version)
- `skills/brainstorming/SKILL.md` — three insertion blocks
- `commands/brainstorm.md` — single insertion block (deprecation-stub redirect)
- New, no upstream counterpart:
  - `README.md`, `UPSTREAM.md`
  - `skills/claudex-build/` (entire directory)
  - `commands/claudex-build.md`

## Merge procedure

When upstream releases a new version (e.g., `5.1.0`):

1. Clone the new upstream version locally for diffing.
2. For files NOT in the modification list above, copy upstream-new into
   `~/.claude/plugins/claudex/` directly — no conflicts possible.
3. For each modified file, do a 3-way merge:
   - Old upstream (e.g., `5.0.7`)
   - New upstream (e.g., `5.1.0`)
   - This fork
   The `CLAUDEX:BEGIN`/`CLAUDEX:END` markers make the fork's additions
   trivially identifiable; conflicts only arise when upstream rewrote
   the surrounding sections.
4. Append a section to this file: `## Merged: <date> upstream <ver>`
   listing any conflicts resolved and how.
5. Bump claudex version in `package.json` (e.g., `0.1.0` → `0.1.1`).

## Merge log

(none yet — initial fork)
