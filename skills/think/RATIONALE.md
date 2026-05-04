# claudex-think rationale

## Script/prose boundary

Scripts own gates and append-only audit mutations because those behaviors need repeatable checks. SKILL.md owns the conversation shape, Agent dispatches, and user-facing text because shell cannot call the Claude Agent tool or decide how much design detail a user needs.

## Safety-rule inventory

Design approval is mandatory before spec writing. Decisions freeze before Codex writes the spec. Duplicate transcript turns and decision IDs are refused. Build launch requires a literal user choice of `1` or `2`. The accepted spec is preserved in both destinations: the canonical docs path and `${HOME}/claudex-audits/${RUN_ID}/00-spec.md`.

Maintainer note: the approved-design file is named `04-design.md` in `claudex:think` (was `.design.md` in `skills/brainstorming/`) so the file appears in audit listings instead of being hidden.

## Recommendation trigger

Every user-decision-requesting turn requires a 2nd-opinion dispatch before showing the turn to the user. The dispatch uses `scripts/dispatch-codex-2nd-opinion.sh`. If `CODEX_STATE=READY` (Stage 0 probe), the dispatch invokes `codex exec`. If `CODEX_STATE=MISSING`, the dispatch invokes a Claude subagent (Agent tool, model='sonnet') with the same prompt template, and the verdict line is labeled `[Codex(fallback)] AGREE/DISAGREE/ANGLE-MISSED: ...` in audit and user-visible output. In both modes the closed-schema verdict tokens are the same; an unparsable verdict (exit 5) halts in both modes.

Trigger test: is the orchestrator asking the user to decide, choose, confirm, approve, accept, proceed, revisit, or stop? If yes, dispatch first. Pure status updates or factual answers do not trigger it.

## Codex failure model

`CODEX_STATE=MISSING` is chosen once in Stage 0 and persisted as `MISSING` in `${RUN_DIR}/.codex-state`; `CODEX_STATE=READY` is persisted as `READY` in the same file. Later stages read that file to choose true Codex roles: decision-turn second opinion and spec writing. The Opus reviewer is already a Claude/Opus role and is unchanged. If Stage 0 found Codex ready but a later dispatch fails at runtime, the run halts instead of silently changing dispatcher identity.

## Visual companion removal

The visual sidecar was removed from this workflow to keep the skill focused on auditable design decisions, spec authorship, and build handoff. Visual exploration can still happen in normal conversation before or after this skill, but it is not load-bearing here.
