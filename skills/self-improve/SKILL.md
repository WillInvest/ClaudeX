---
name: claudex-self-improve
description: Advisory self-improvement workflow for projecting CXMem run records into audited, non-applied improvement proposals.
---

# claudex — usage notes

These skills (`/claudex:think`, `/claudex:build`, `/claudex:auto`, `/claudex:self-improve`) cooperate closely with **CXMem** (`~/CXMem/`), the central memory store. Personal info, project context, and learned preferences live there — not in plugin source.

CXMem records raw transcript and Codex-derived rounds per project. Self-improve reads only through the projection seam, writes improvement artifacts under CXMem project state, and never modifies source files.

# claudex-self-improve — advisory improvement workflow

Use `/claudex:self-improve` when a specific prior run should be inspected for process, skill, prompt, test, or documentation improvements. This skill is advisory-only: no auto-application of accepted or refined proposals, no `.mode-auto` integration, no source edits, and no cross-project input support.

The command requires an explicit selector. With no selector, show no-selector help and stop. Valid selectors are a CXMem run path of shape `projects/<X>/sessions/<slug>/runs/<run-id>/` or a same-project run selector resolved by the orchestrator. Invalid selector and cross-project input stop before any output directory is created.

Supported flows:

| Flow | Meaning |
|---|---|
| `claude-advises-codex` | Claude prepares advisor proposals; Codex audits each proposal. |
| `codex-advises-claude` | Codex prepares advisor proposals; Claude audits each proposal. |
| `both` | Run both advisory directions into the same self-improve run. |

The literal `flow-short` mapping table is:

| flow-short | Flow |
|---|---|
| `cac` | `claude-advises-codex` |
| `caclaude` | `codex-advises-claude` |
| `both` | `both` |

Create `SELF_IMPROVE_RUN_ID="$(date -u +%Y-%m-%d-%H%M)-<flow-short>-<topic-slug>"` and resolve `IMPROVE_RUN_DIR` with `scripts/resolve-improve-run-dir.sh`. The output layout is `projects/<X>/improvements/<self-improve-run-id>/`.

## Stage 0 — Setup

Parse arguments before side effects:

- `--flow <claude-advises-codex|codex-advises-claude|both>` is required unless a default was explicitly supplied by the caller.
- `--target-kind <skill-prompt|recording-protocol|design-heuristic|script|other>` is optional; unsupported target-kind flag stops with a usage error.
- `--max-items <N>` is optional and bounds parseable proposals per advisor output.
- The selector is required; missing selector prints no-selector help.

Resolve the active project through `skills/build/scripts/resolve-cxmem-project.sh`, verify the selector belongs to the same project, and compute `MISSION_ID="$(bash scripts/record-mission-id.sh "$SOURCE_RUN_DIR")"`. Mission ID collision is checked before projection: if any proposal, audit, or projection record already names that mission, exit before any projections are populated. This specific sequence is mandatory: Mission ID collision, exit before any projections are populated.

Probe Codex through `scripts/probe-codex.sh`. On `CODEX_MISSING`, continue only on the Claude-owned fallback role path and write `.last-codex-fallback-<role>-<mission_id>-<seq>.raw`; fallback records carry the `[Codex(fallback)]` label. On Codex exec failure, mark the role degraded and preserve the `.err` tail.

## Stage 1 — Projection

Write `00-inputs.md` with selector, flow, target-kind, max-items, mission id, source path, and projection status. Then run `scripts/project-mission-inputs.sh "$SOURCE_RUN_DIR" claude > "$IMPROVE_RUN_DIR/01-projections/$MISSION_ID-claude.md"` for Claude-side inputs and `scripts/project-mission-inputs.sh "$SOURCE_RUN_DIR" codex > "$IMPROVE_RUN_DIR/01-projections/$MISSION_ID-codex.md"` for Codex-side inputs. For the `both` flow, the orchestrator calls both sides and writes both projection files. The projection seam is the only reader of raw trails. It writes exactly `# CXMEM-CLAUDE-ROUNDS v1` or `# CXMEM-CODEX-RECORDS v1`, then `# Mission: <mission_id>`, then `# Source: <run-trail-path>`, then a blank line and chronological flattened bodies.

Unknown Codex projection version stops the reader with `degraded:unknown-codex-record-version=<N>` on stdout. The orchestrator catches the non-zero exit and marks the mission degraded in `00-inputs.md`. Empty projection is allowed but marked degraded in `00-inputs.md` and summarized as zero input records.

## Stage 2 — Advisor

Use `advisor-prompt.md` for Claude-side roles, Codex-side roles, fallback roles, and stubbed role execution. Fill `{{MISSION_PROJECTION}}`, `{{ADVISOR_SIDE}}`, `{{TARGET_KIND_FILTER}}`, `{{MAX_ITEMS}}`, `{{ADVISEE_SOURCE_PATHS}}`, mission id, and CXMem recording-rule splice. For Codex prompts, splice `skills/build/prompts/cxmem-recording-rule-block.md` only when `CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY`; otherwise the slot is empty.

Raw role files use these exact schemas:

- `.last-codex-advise-<mission_id>-<seq>.raw`
- `.last-claude-advise-<mission_id>-<seq>.raw`
- `.last-codex-fallback-<role>-<mission_id>-<seq>.raw`

Codex advisor dispatch uses `codex exec --sandbox read-only --skip-git-repo-check -C "$RUN_DIR" -`. Stub env var `CLAUDEX_SI_STUB_ADVISOR_OUTPUT` bypasses Codex when readable and fails before any Codex call when unreadable.

Parse advisor output with `scripts/parse-advisor-proposals.sh <advisor-output-file> <output-dir> <mission_id> <self_improve_run_id> <advisor_model> [--target-kind <kind>] [--max-items <N>]`, writing to `10-advice-by-claude/` and/or `10-advice-by-codex/`. Valid proposal records are named `<mission_id>--<NNN>-<slug>.md`; their frontmatter contains exactly `mission_id`, `self_improve_run_id`, `advisor_model`, `target_path`, `target_section`, `target_kind`, `change_type`, `slug`, and `verdict`. The `target_kind` enum is exactly `skill-prompt|recording-protocol|design-heuristic|script|other`; the `change_type` enum is exactly `add|remove|replace|clarify`. Proposal body sections are exactly `## Observation`, `## Proposed change`, `## Rationale`, `## Risk`, and `## Audit verdict`. Malformed advisor blocks are ignored without poisoning valid blocks. Zero parseable proposals writes a placeholder or equivalent summary entry. Target-kind filter excluding all proposals is represented as zero parseable proposals.

## Stage 3 — Audit

Audit each proposal independently. Use `auditor-prompt.md` for Claude-side roles, Codex-side roles, fallback roles, and stubbed role execution. Proposal files store bodies without `<<<SI-PROPOSAL>>>` sentinels; pass the proposal body verbatim into the prompt slot.

Raw role files use these exact schemas:

- `.last-codex-audit-<mission_id>-<NNN>.raw`
- `.last-claude-audit-<mission_id>-<NNN>.raw`
- `.last-codex-fallback-<role>-<mission_id>-<seq>.raw`

Codex auditor dispatch uses `codex exec --sandbox read-only --skip-git-repo-check -C "$RUN_DIR" -`. Stub env var `CLAUDEX_SI_STUB_AUDITOR_OUTPUT` bypasses Codex when readable and fails before any Codex call when unreadable.

Parse audit output with `scripts/parse-auditor-verdict.sh <proposal-file> <auditor-output> <output-dir> <mission-id> <self-improve-run-id> <advisor-model> <auditor-model>`, writing paired audit records to `20-audit-by-codex/` and/or `20-audit-by-claude/`. Audit records are named `<mission_id>--<NNN>-<slug>.md`; their frontmatter contains `mission_id`, `self_improve_run_id`, `auditor_model`, `advisor_model`, `proposal_path`, and `verdict`. Missing auditor verdict marks `degraded:auditor-no-verdict`. Multiple auditor verdict lines use last-match behavior. Proposal frontmatter keeps `verdict:` single-line; `ACCEPT`, `REJECT`, and `REFINE` map to `accepted`, `rejected`, and `refined`; `REFINE:` stores only the one-line reason in frontmatter and overwrites `## Proposed change` with the refined body.

## Stage 4 — Index And Summary

Write `index.md` listing projection status, advisor raw artifacts, advice records, paired audit records, degraded states, and dry-run skip status. Write `99-summary.md` with counts by verdict and explicit confirmation that no source files were modified.

The output layout is:

```text
00-inputs.md
01-projections/<mission_id>-claude.md
01-projections/<mission_id>-codex.md
10-advice-by-claude/<mission_id>--<NNN>-<slug>.md
10-advice-by-codex/<mission_id>--<NNN>-<slug>.md
20-audit-by-codex/<mission_id>--<NNN>-<slug>.md
20-audit-by-claude/<mission_id>--<NNN>-<slug>.md
index.md
99-summary.md
```

Dry run performs setup, projection, advisor dispatch, parsing, and summary writing, then records dry-run skip instead of auditing. No auto-apply behavior exists in any mode.

## Error Handling Contract

Handle these cases explicitly: missing selector, invalid flow, invalid selector, cross-project input, Mission ID collision, Codex missing, Codex exec failure, unknown Codex projection version, empty projection, malformed advisor blocks, zero parseable proposals with placeholder or equivalent summary entry, missing auditor verdict, multiple auditor verdict lines with last-match behavior, dry run, target-kind filter excluding all proposals, unsupported target-kind flag, and unreadable stub output file.
