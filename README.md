# claudex

Fork of `superpowers/5.0.7` that adds OpenAI Codex as a second-model
collaborator for brainstorming and as the worker in an
autonomous-after-brainstorm plan-then-implement pipeline.

## What's different from superpowers

Three modified files and one new skill directory; everything else is
upstream verbatim. Modified files are bracketed with
`<!-- CLAUDEX:BEGIN -->` and `<!-- CLAUDEX:END -->` markers so future
merges from upstream are mechanical.

- `skills/brainstorming/SKILL.md` — three insertions:
  1. At each multi-choice / "I recommend X" question, Claude dispatches
     Codex via `codex exec` and shows a side-by-side
     counter-recommendation (≤60 words).
  2. After the design converges and before the spec is written, Codex
     gets one shot at the full transcript + design and returns a
     `READY | FIX | WRONG-DIRECTION` verdict (≤200 words).
  3. The upstream "user reviews spec" gate is removed; brainstorming
     hands off directly to `claudex-build` instead of `writing-plans`.
- `commands/brainstorm.md` — deprecation stub points at the claudex
  brainstorming skill instead of the superpowers one.
- `package.json` — name changed to `claudex`, version `0.1.0`.

## What's new

- `skills/claudex-build/` — autonomous plan→impl skill. Codex (latest
  model) writes plan and implementation; a fresh Opus 4.7 subagent
  reviews each with DRIFT (vs source artifact) + QUALITY (against three
  criteria: Minimal, Consistent, Verifiable). Loop on verdict, max 2
  review rounds per stage. Audit trail at `/tmp/claudex/<run-id>/`.
- `commands/claudex-build.md` — slash command `/claudex-build`.

## Install

This plugin lives at `~/.claude/plugins/claudex/`. Discovery is via
symlinks to `~/.claude/skills/` and `~/.claude/commands/`. To install,
run:

```bash
ln -s ~/.claude/plugins/claudex/skills/brainstorming   ~/.claude/skills/claudex-brainstorming
ln -s ~/.claude/plugins/claudex/skills/claudex-build   ~/.claude/skills/claudex-build
ln -s ~/.claude/plugins/claudex/commands/brainstorm.md ~/.claude/commands/claudex-brainstorm.md
ln -s ~/.claude/plugins/claudex/commands/claudex-build.md ~/.claude/commands/claudex-build.md
```

Coexists with the upstream `superpowers` plugin — both can be installed
at the same time. The prefixed names (`claudex-...`) prevent collision.

## Requirements

- `codex` CLI ≥ `0.122.0` (for `codex exec resume`).
- Claude Code with the `Agent` tool and `model: "opus"` resolution.

## Source of truth

- Spec: `~/vault/projects/claudex/specs/2026-04-30-claudex-plugin-design.md`
- Implementation plan: `~/vault/projects/claudex/plans/2026-04-30-claudex-plugin-impl.md`
