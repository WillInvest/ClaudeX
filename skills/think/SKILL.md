---
name: claudex-think
description: Design-first workflow for turning a user idea into an approved implementation spec, with audited decision turns, Codex challenge where available, Opus spec review, and unchanged claudex-build handoff.
---

# claudex-think
Use `/claudex:think` when the user has an idea that needs framing, tradeoffs, design approval, and an implementation-ready spec before build. The terminal output of this skill is an accepted spec written to a project-relative path (see "Spec destination resolution" in Stage 0) and the same spec copied to `${HOME}/vault/projects/claudex/audits/${RUN_ID}/00-spec.md` for the audit trail.

Every user-decision-requesting turn requires a 2nd-opinion dispatch before showing the turn to the user. The dispatch uses `scripts/dispatch-codex-2nd-opinion.sh`. If `CODEX_STATE=READY` (Stage 0 probe), the dispatch invokes `codex exec`. If `CODEX_STATE=MISSING`, the dispatch invokes a Claude subagent (Agent tool, model='sonnet') with the same prompt template, and the verdict line is labeled `[Codex(fallback)] AGREE/DISAGREE/ANGLE-MISSED: ...` in audit and user-visible output. In both modes the closed-schema verdict tokens are the same; an unparsable verdict (exit 5) halts in both modes.

## Stage 0 — Setup

Create `RUN_ID="$(date -u +%Y-%m-%d-%H%M)-<slug>"`, `RUN_DIR="${HOME}/vault/projects/claudex/audits/${RUN_ID}"`, and initialize `00-setup.md`, `02-transcript.md`, and `03-decisions.md`; use a short kebab-case slug from the user's goal. (`${HOME}/vault/projects/claudex/audits/` is the unified home for all run trails — earlier paths were `/tmp/claudex/` and `${HOME}/claudex-audits/`.)

### Spec destination resolution

The canonical spec lands in a project-relative location based on cwd, resolved at Stage 0. Resolution rules in priority order:

1. **Vault project.** If cwd or any parent is `${HOME}/vault/projects/<X>/` for some `<X>`, the spec destination is `${HOME}/vault/projects/<X>/specs/<date>-<topic>-design.md` (no `docs/claudex/` prefix; matches the convention that vault projects own their `specs/`).
2. **Other project repo.** Else if `git rev-parse --show-toplevel` succeeds and produces a path outside `${HOME}/vault/`, the spec destination is `<git-toplevel>/docs/claudex/specs/<date>-<topic>-design.md` (preserves today's behavior for plugin-source checkouts and external project repos).
3. **No project context (or vault cwd outside `projects/<X>/`).** Else — including cwd inside `${HOME}/vault/` but not under any `projects/<X>/` (e.g. `${HOME}/vault/`, `${HOME}/vault/agent-log/`, `${HOME}/vault/teaching/`), and cwd outside the vault with no enclosing project — fall back to `${HOME}/vault/projects/claudex/specs/<date>-<topic>-design.md`. Claudex meta-work specs land here.

Compute the destination once at Stage 0 and store it as `CANONICAL_SPEC_PATH`; downstream stages use that variable. Print the resolved path to the user once during Stage 0 so they know where the spec will land.

### Inputs

- `RUN_ID`: stable audit identifier for the whole think/build chain.
- `RUN_DIR`: `${HOME}/vault/projects/claudex/audits/${RUN_ID}` audit directory.
- `PATH`: used by probe scripts.
- `skills/build/SKILL.md`: build handoff must remain reachable.

### Dispatch

```bash
CODEX_PROBE="$(bash scripts/probe.sh codex)"
case "$CODEX_PROBE" in CODEX_READY) printf 'READY\n' > "$RUN_DIR/.codex-state" ;; CODEX_MISSING) printf 'MISSING\n' > "$RUN_DIR/.codex-state" ;; esac
bash scripts/probe.sh claudex-build
```

### Verdict → next step

| Output | Next step |
|---|---|
| `CODEX_READY` | Write `READY` to `${RUN_DIR}/.codex-state`; true Codex roles use copied dispatch scripts. |
| `CODEX_MISSING` | Write `MISSING` to `${RUN_DIR}/.codex-state`; true Codex roles use Claude subagent fallback with `model='sonnet'`, same prompt template, same closed tokens, and `[Codex(fallback)]` labels. |
| `CLAUDEX_BUILD_PRESENT` | Continue to Stage 1. |
| `CLAUDEX_BUILD_MISSING` | Halt; build handoff target is unavailable. |
| exit 2 | Halt for script usage repair. |

## Stage 1 — Dialogue

Ask one focused question at a time. Append every user-visible question, second-opinion verdict, and answer as it happens; append decisions immediately when made. Pure factual or informational replies do not need a second opinion.

Before any pick, confirm, approve, prefer, accept, proceed, revisit, or stop turn, write the drafted question to `${RUN_DIR}/.q.md` and Claude's recommendation or neutral framing to `${RUN_DIR}/.r.md`; do not show it yet. Run the 2nd-opinion path, then show one message in this exact order:

1. The question text from `.q.md`.
2. Claude's recommendation or neutral framing from `.r.md`.
3. A blank line, then the line `[Codex 2nd opinion]: <verdict>` (or `[Codex(fallback)] <verdict>` in MISSING mode).
4. A blank line, then `Your call.`

The Codex verdict must never appear before the question and recommendation. If you find yourself about to print the verdict first, stop and re-order.

### Inputs

- `${RUN_DIR}/02-transcript.md`: dialogue log.
- `${RUN_DIR}/03-decisions.md`: decisions log.
- `${RUN_DIR}/.q.md`: drafted user-decision turn.
- `${RUN_DIR}/.r.md`: recommendation or neutral framing.
- `${RUN_DIR}/.codex-state`: dispatch mode persisted by Stage 0.

### Dispatch

```bash
bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
bash scripts/record-turn.sh "$RUN_DIR" "$TURN_NUMBER" "$SPEAKER" "$TURN_FILE"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE"
```

### Verdict → next step

| Output | Next step |
|---|---|
| `AGREE: ...` | Present the turn with `[Codex 2nd opinion]: AGREE: ...`; record transcript and decision if the user decides. |
| `DISAGREE: ...` | Present the turn with disagreement visible; record the user's choice and any picked-over rationale. |
| `ANGLE-MISSED: ...` | Present the missed angle; ask the user to decide with the angle included. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use Agent fallback, `model='sonnet'`, same prompt; label `[Codex(fallback)] AGREE/DISAGREE/ANGLE-MISSED: ...`. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt; surface stderr tail from the dispatch script. |
| dispatch exit 5 | Halt; verdict was unparsable. |
| record exit 0 | Continue the dialogue loop or Stage 2 when enough is known. |
| record exit 2/4/5 | Halt for audit repair; do not reconstruct later. |

## Stage 2 — Approaches

Prepare `05-approaches.md` with 2-3 viable approaches scaled to the problem, attribution for any model-sourced recommendation, and Claude's current pick. Approach selection is a user-decision-requesting turn, so the Stage 1 2nd-opinion rule applies before showing options.

### Inputs

- `${RUN_DIR}/02-transcript.md`: current dialogue.
- `${RUN_DIR}/03-decisions.md`: current decisions.
- `${RUN_DIR}/05-approaches.md`: approach options, written before the user selection turn.
- `${RUN_DIR}/.q.md` and `${RUN_DIR}/.r.md`: approach-selection turn and recommendation.
- `${RUN_DIR}/.codex-state`: READY or MISSING route.

### Dispatch

```bash
bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
cat "$RUN_DIR/.approaches.md" > "$RUN_DIR/05-approaches.md"
bash scripts/record-turn.sh "$RUN_DIR" "$TURN_NUMBER" "$SPEAKER" "$TURN_FILE"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE"
```

### Verdict → next step

| Output | Next step |
|---|---|
| `AGREE: ...` | Present approaches and recommendation; user picks; record selected approach. |
| `DISAGREE: ...` | Present both positions; user picks; record picked-over rationale when applicable. |
| `ANGLE-MISSED: ...` | Add the angle to the options before asking; record resulting decision. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use `[Codex(fallback)]` sonnet subagent path, then present. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt with stderr tail; do not switch dispatcher. |
| dispatch exit 5 | Halt on schema failure. |
| record exit 0 | Continue to Stage 3 after approach decision is recorded. |
| record exit 2/4/5 | Halt for audit repair. |

## Stage 3 — Design

Write the design in sections sized to the task: problem, success criteria, selected approach, architecture, components, data flow, error handling, testing, and out of scope. Each section approval is a user-decision-requesting turn; run the second opinion before showing the approval request. After final approval, create `${RUN_DIR}/.design-approved`.

### Inputs

- `${RUN_DIR}/02-transcript.md`: full dialogue.
- `${RUN_DIR}/03-decisions.md`: decisions up to design approval.
- `${RUN_DIR}/05-approaches.md`: selected approach context.
- `${RUN_DIR}/04-design.md`: approved design narrative.
- `${RUN_DIR}/.design-approved`: final user approval marker.

### Dispatch

```bash
bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
bash scripts/record-turn.sh "$RUN_DIR" "$TURN_NUMBER" "$SPEAKER" "$TURN_FILE"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE"
bash scripts/gate-design-approval.sh "$RUN_DIR"
```

### Verdict → next step

| Output | Next step |
|---|---|
| `AGREE: ...` | Present section approval turn with verdict; record approval or redirect. |
| `DISAGREE: ...` | Present disagreement; user chooses whether to revise or approve. |
| `ANGLE-MISSED: ...` | Address the missed angle before approval. |
| `DESIGN_APPROVED` | Continue to Stage 4. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use `[Codex(fallback)]` sonnet subagent path, then present. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt with stderr tail. |
| dispatch exit 5 | Halt on schema failure. |
| gate exit 3 | Halt; design has not been approved. |
| record/gate exit 2/4/5 | Halt for audit or script repair. |

## Stage 4 — Spec Write + Opus Review

Freeze decisions, then dispatch Codex to write the spec. The accepted spec is written to `$CANONICAL_SPEC_PATH` (resolved at Stage 0 — see "Spec destination resolution"). The orchestrator does not author spec body text. Opus review uses Agent tool with `model='opus'` in both Codex states.

Review loop: round 1 spec, Opus review, optional fix or round 2, final Opus review if needed. If round 2 still returns `re-review-needed` or `escalate`, halt; do not start a third review round.

### Inputs

- `${RUN_DIR}/02-transcript.md`: dialogue source.
- `${RUN_DIR}/03-decisions.md`: frozen decisions source.
- `${RUN_DIR}/03-decisions.frozen`: freeze marker.
- `${RUN_DIR}/04-design.md`: approved design.
- `${RUN_DIR}/05-approaches.md`: approach context.
- `$CANONICAL_SPEC_PATH`: canonical accepted spec destination (resolved at Stage 0).

### Dispatch

```bash
bash scripts/gate-design-approval.sh "$RUN_DIR"
bash scripts/freeze-decisions.sh "$RUN_DIR"
bash scripts/dispatch-codex-spec-write.sh "$RUN_DIR" "$ROUND" "$RUN_DIR/04-design.md" "$RUN_DIR/05-approaches.md" "$CANONICAL_SPEC_PATH"
bash scripts/build-opus-spec-review-prompt.sh "$RUN_DIR" "$REVIEW_ROUND" "$RUN_DIR/05-approaches.md"
```

### Verdict → next step

| Output | Next step |
|---|---|
| `DESIGN_APPROVED` | Freeze decisions, then dispatch spec round 1. |
| freeze exit 0 | Decisions are closed; continue to spec dispatch. |
| spec exit 0 | Dispatch Opus reviewer with generated prompt; parse `VERDICT`. |
| spec exit 3 / `WRONG-DIRECTION:` | Halt and present user options: revisit design, proceed anyway, or stop. |
| spec exit 4 and `CODEX_STATE=READY` | Halt with stderr tail; no runtime fallback. |
| spec exit 4 and `CODEX_STATE=MISSING` | Use sonnet subagent fallback for spec writer with same prompt and `[Codex(fallback)]` audit label. |
| spec exit 5/6 | Halt; cleanup or decisions preamble check failed. |
| review `ready-to-execute` | Accept canonical spec and continue to Stage 5. |
| review `fix-and-proceed` | Dispatch `fix1` or `fix2`, then accept without another review. |
| review `re-review-needed` round 1 | Dispatch round 2 and Opus review round 2. |
| review `re-review-needed` round 2 or `escalate` | Halt for user; no round 3. |
| gate/freeze/review-prompt exit 2/4/5 | Halt for repair. |

## Stage 5 — Handoff

Copy the accepted canonical spec to `${HOME}/vault/projects/claudex/audits/${RUN_ID}/00-spec.md`, export `RUN_ID`, and ask the user whether to launch build inline or detached. The build-choice presentation is a user-decision-requesting turn, so run the second opinion before showing choices. The user must answer literal `1` or `2`; write it to `${RUN_DIR}/.user-build-choice`. Stage 5 dispatch order is: cp → 2nd-opinion → user-choice gate → probe-tmux → invoke.

### Inputs

- `RUN_ID`: exported for `claudex:build`.
- `${RUN_DIR}/00-spec.md`: build handoff copy.
- `${RUN_DIR}/.user-build-choice`: literal `1` or `2`.
- `$CANONICAL_SPEC_PATH`: accepted spec from Stage 4.
- `tmux`: optional detached build launcher dependency.

### Dispatch

```bash
cp "$CANONICAL_SPEC_PATH" "$RUN_DIR/00-spec.md"
bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
bash scripts/gate-user-build-choice.sh "$RUN_DIR"
bash scripts/probe.sh tmux
bash scripts/start-tmux-build.sh "$CANONICAL_SPEC_PATH" "$RUN_ID"
```

### Verdict → next step

| Output | Next step |
|---|---|
| copy success | Export `RUN_ID`; prepare build-choice turn. |
| `AGREE: ...` / `DISAGREE: ...` / `ANGLE-MISSED: ...` | Present choice prompt with verdict; user answers `1` or `2`. |
| `USER_BUILD_CHOICE_1` | Invoke `/claudex:build $CANONICAL_SPEC_PATH` inline with exported `RUN_ID`. |
| `USER_BUILD_CHOICE_2` + `TMUX_PRESENT` | Run `start-tmux-build.sh`; report tmux session and audit path. |
| `USER_BUILD_CHOICE_2` + `TMUX_MISSING` | Halt and offer inline build or stop. |
| gate exit 3 | Halt; only literal `1` or `2` is accepted. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use `[Codex(fallback)]` sonnet subagent path, then present. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt with stderr tail. |
| dispatch exit 5 | Halt on schema failure. |
| script exit 2/4/5 | Halt for repair. |
