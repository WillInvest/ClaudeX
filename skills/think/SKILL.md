---
name: claudex-think
description: Design-first workflow for turning a user idea into an approved design, frozen decisions, and a detached claudex-build handoff.
---

# claudex-think

Use `/claudex:think` when the user has an idea that needs framing, tradeoffs, and design approval before autonomous build. Think does not write the implementation spec and does not create transcript files. It records decisions, approves design, freezes those decisions immediately, then asks whether to launch `/claudex:build` in detached tmux.

Every user-decision-requesting turn requires a 2nd-opinion dispatch before showing the turn to the user. The dispatch uses `scripts/dispatch-codex-2nd-opinion.sh`; the transcript slot is populated by projecting CXMem main rounds with `scripts/cxmem-rounds-to-transcript.sh <sessions-root> <slug>`, or left empty for stateless mode. `02-transcript.md` is not created.

## Stage 0 — Setup

Create `RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-<slug>}"`, resolve `RUN_DIR="${RUN_DIR:-$(bash ../build/scripts/resolve-run-dir.sh "$RUN_ID")}"`, and initialize `00-setup.md` and `03-decisions.md`; use a short kebab-case slug from the user's goal when `RUN_ID` is not inherited. Do not initialize `02-transcript.md`.

Resolved run paths:

| Host state | `RUN_DIR` |
|---|---|
| `CXMEM_HOST_PROJECT_READY` | `${CXMEM_HOME}/projects/<project>/sessions/<slug>/runs/<run-id>` |
| `CXMEM_HOST_PROJECT_NO_SESSION` | `${CXMEM_HOME}/projects/<project>/runs/<run-id>` |
| `CXMEM_HOST_MISSING` | `${HOME}/vault/projects/claudex/audits/<run-id>` |

Resolve `CANONICAL_SPEC_PATH` once at Stage 0 using the existing project-relative rules:

1. If cwd or any parent is `${HOME}/vault/projects/<X>/`, write to `${HOME}/vault/projects/<X>/specs/<date>-<topic>-design.md`.
2. Else if `git rev-parse --show-toplevel` succeeds outside `${HOME}/vault/`, write to `<git-toplevel>/docs/claudex/specs/<date>-<topic>-design.md`.
3. Else write to `${HOME}/vault/projects/claudex/specs/<date>-<topic>-design.md`.

### Inputs

- `RUN_ID`: stable run identifier for the think/build chain.
- `RUN_DIR`: resolved run trail directory for the host state.
- `CANONICAL_SPEC_PATH`: destination build will write during SPEC.
- `${SESSIONS_ROOT:-${HOME}/CXMem/projects/<project>/sessions}` and session slug: source for projected 2nd-opinion context when present.

### Dispatch

```bash
RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-<slug>}"
RUN_DIR="${RUN_DIR:-$(bash ../build/scripts/resolve-run-dir.sh "$RUN_ID")}"
mkdir -p "$RUN_DIR"
: > "$RUN_DIR/00-setup.md"
: > "$RUN_DIR/03-decisions.md"
CODEX_PROBE="$(bash scripts/probe.sh codex)"
case "$CODEX_PROBE" in CODEX_READY) printf 'READY\n' > "$RUN_DIR/.codex-state" ;; CODEX_MISSING) printf 'MISSING\n' > "$RUN_DIR/.codex-state" ;; esac
bash scripts/probe.sh claudex-build
```

### Verdict → next step

| Output | Next step |
|---|---|
| `CODEX_READY` | Continue; Codex roles use `codex exec`. |
| `CODEX_MISSING` | Continue with Claude subagent fallback for 2nd opinion, same closed tokens. |
| `CLAUDEX_BUILD_PRESENT` | Continue to Stage 1. |
| `CLAUDEX_BUILD_MISSING` | Halt; build handoff target is unavailable. |
| exit 2 | Halt for script usage repair. |

## Stage 1 — Dialogue

Ask one focused question at a time. Append decisions immediately when made. Pure factual or informational replies do not need a second opinion.

Before any pick, confirm, approve, prefer, accept, proceed, revisit, or stop turn, write the drafted question to `${RUN_DIR}/.q.md` and Claude's recommendation or neutral framing to `${RUN_DIR}/.r.md`; do not show it yet. Project CXMem main rounds into the transcript slot, run the 2nd-opinion path, then show one message in this exact order: question, recommendation/framing, blank line, `[Codex 2nd opinion]: <verdict>`, blank line, `Your call.`

Auto mode is active only when `${RUN_DIR}/.mode-auto` exists. Before showing the user-decision block, auto-record and continue only on `AGREE` with `--decided-by auto --foldability n/a --high-blast no`, or on `ANGLE-MISSED` when the angle is folded without changing the structural answer, using `--decided-by auto --foldability folded --high-blast no`. Halt and show this canonical halt block on `DISAGREE`, structural `ANGLE-MISSED`, Codex failure, unparsable verdicts, high-blast decisions, or ambiguous touched-file sets:
`Auto mode halted.`
`Reason: <halt reason>.`
`Review the Codex 2nd opinion above.`
`Choose Claude, Codex, revise, or stop.`
`Your call.`

If Claude's recommendation lacks explicit paths and the touched-file set is ambiguous, halt conservatively. After user resolution, record `--decided-by user --foldability n/a --high-blast ambiguous-halted`; for other halt resolutions, record `--decided-by user`, `--foldability structural` only for structural missed angles or `n/a` otherwise, and `--high-blast yes` for high-blast or `no` otherwise. Never remove `${RUN_DIR}/.mode-auto`.

### Dispatch

```bash
bash scripts/cxmem-rounds-to-transcript.sh "${SESSIONS_ROOT:-${HOME}/CXMem/projects/<project>/sessions}" "$CXMEM_SESSION_SLUG" |
  bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE" ${AUTO_DECISION_FLAGS:-}
```

### Verdict → next step

| Output | Next step |
|---|---|
| `AGREE: ...` | Present the turn with `[Codex 2nd opinion]: AGREE: ...`; record decision if the user decides. |
| `DISAGREE: ...` | Present disagreement; record the user's choice and rationale. |
| `ANGLE-MISSED: ...` | Include the angle before asking the user to decide. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use `[Codex(fallback)]` sonnet subagent path, then present. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt; surface stderr tail. |
| dispatch exit 5 | Halt; verdict was unparsable. |
| record exit 0 | Continue dialogue or Stage 2. |
| record exit 2/4/5 | Halt for audit repair. |

## Stage 2 — Approaches

Prepare `05-approaches.md` with 2-3 viable approaches scaled to the problem, attribution for any model-sourced recommendation, and Claude's current pick. Approach selection is a user-decision-requesting turn, so run the second opinion before showing options.

Auto mode is active only when `${RUN_DIR}/.mode-auto` exists. Before showing the user-decision block, auto-record and continue only on `AGREE` with `--decided-by auto --foldability n/a --high-blast no`, or on `ANGLE-MISSED` when the angle is folded without changing the structural answer, using `--decided-by auto --foldability folded --high-blast no`. Halt and show this canonical halt block on `DISAGREE`, structural `ANGLE-MISSED`, Codex failure, unparsable verdicts, high-blast decisions, or ambiguous touched-file sets:
`Auto mode halted.`
`Reason: <halt reason>.`
`Review the Codex 2nd opinion above.`
`Choose Claude, Codex, revise, or stop.`
`Your call.`

If Claude's recommendation lacks explicit paths and the touched-file set is ambiguous, halt conservatively. After user resolution, record `--decided-by user --foldability n/a --high-blast ambiguous-halted`; for other halt resolutions, record `--decided-by user`, `--foldability structural` only for structural missed angles or `n/a` otherwise, and `--high-blast yes` for high-blast or `no` otherwise. Never remove `${RUN_DIR}/.mode-auto`.

### Dispatch

```bash
bash scripts/cxmem-rounds-to-transcript.sh "${SESSIONS_ROOT:-${HOME}/CXMem/projects/<project>/sessions}" "$CXMEM_SESSION_SLUG" |
  bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
cat "$RUN_DIR/.approaches.md" > "$RUN_DIR/05-approaches.md"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE" ${AUTO_DECISION_FLAGS:-}
```

### Verdict → next step

| Output | Next step |
|---|---|
| `AGREE: ...` | Present approaches and recommendation; user picks; record selected approach. |
| `DISAGREE: ...` | Present both positions; user picks; record picked-over rationale when applicable. |
| `ANGLE-MISSED: ...` | Add the angle to the options before asking; record resulting decision. |
| dispatch/record exit 2/4/5 | Halt for repair. |

## Stage 3 — Design

Write the design in sections sized to the task: problem, success criteria, selected approach, architecture, components, data flow, error handling, testing, and out of scope. Each section approval is a user-decision-requesting turn; run the second opinion before showing the approval request.

Auto mode is active only when `${RUN_DIR}/.mode-auto` exists. Before showing the user-decision block, auto-record and continue only on `AGREE` with `--decided-by auto --foldability n/a --high-blast no`, or on `ANGLE-MISSED` when the angle is folded without changing the structural answer, using `--decided-by auto --foldability folded --high-blast no`. Halt and show this canonical halt block on `DISAGREE`, structural `ANGLE-MISSED`, Codex failure, unparsable verdicts, high-blast decisions, or ambiguous touched-file sets:
`Auto mode halted.`
`Reason: <halt reason>.`
`Review the Codex 2nd opinion above.`
`Choose Claude, Codex, revise, or stop.`
`Your call.`

If Claude's recommendation lacks explicit paths and the touched-file set is ambiguous, halt conservatively. After user resolution, record `--decided-by user --foldability n/a --high-blast ambiguous-halted`; for other halt resolutions, record `--decided-by user`, `--foldability structural` only for structural missed angles or `n/a` otherwise, and `--high-blast yes` for high-blast or `no` otherwise. Never remove `${RUN_DIR}/.mode-auto`.

After final approval, create `${RUN_DIR}/.design-approved`, then immediately freeze decisions with `scripts/freeze-decisions.sh`, which writes `${RUN_DIR}/03-decisions.frozen`.

### Dispatch

```bash
bash scripts/cxmem-rounds-to-transcript.sh "${SESSIONS_ROOT:-${HOME}/CXMem/projects/<project>/sessions}" "$CXMEM_SESSION_SLUG" |
  bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE" ${AUTO_DECISION_FLAGS:-}
bash scripts/gate-design-approval.sh "$RUN_DIR"
bash scripts/freeze-decisions.sh "$RUN_DIR"
```

### Verdict → next step

| Output | Next step |
|---|---|
| `DESIGN_APPROVED` | Freeze decisions immediately, then continue to Stage 4. |
| freeze exit 0 | Decisions are closed; continue to handoff. |
| gate exit 3 | Halt; design has not been approved. |
| dispatch/gate/freeze/record exit 2/4/5 | Halt for repair. |

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

Copy the accepted canonical spec to `${RUN_DIR}/00-spec.md`, export `RUN_ID`, and decide whether to launch `/claudex:build` in detached tmux now. Derive the latest Stage 3 verdict before D15 from the last `Codex 2nd-opinion verdict:` row in `${RUN_DIR}/03-decisions.md`, which is written before `.design-approved`. In auto mode, evaluate D15 before the user prompt: `mode_auto=yes` when `${RUN_DIR}/.mode-auto` exists, `no_user_decisions=yes` when `${RUN_DIR}/03-decisions.md` has no `Decided-by: user` rows, and `stage3_agree=yes` when the latest Stage 3 second-opinion verdict is `AGREE`. If all three are true, write `${RUN_DIR}/.auto-launch-decision`, append a Stage 5 auto decision row with `Decided-by: auto`, `Foldability: n/a`, `High-blast: no`, and invoke the existing `start-tmux-build.sh` path. If `${RUN_DIR}/.auto-launch-decision` cannot be written, treat `auto_launch=no`, append a decision body that captures the write-failure note, and continue to the legacy yes/no prompt.

When D15 is false or auto-launch marker writing fails, keep the existing yes/no handoff behavior. The build-choice presentation is a user-decision-requesting turn, so run the second opinion before showing choices. The user must answer yes or no; write it to `${RUN_DIR}/.user-build-choice`. On yes, export `RUN_ID`, `RUN_DIR`, `CANONICAL_SPEC_PATH`, `CXMEM_HOME`, `CXMEM_PROJECT`, `CXMEM_HOST_STATE`, `CXMEM_SESSION_SLUG`, `SESSIONS_ROOT`, and `MAIN_ROUND_SEQ`; `start-tmux-build.sh` launches exactly one detached session named `claudex-build-${CXMEM_PROJECT}-${RUN_ID}`.

### Inputs

- `RUN_ID`: exported for `claudex:build`.
- `${RUN_DIR}/00-spec.md`: build handoff copy.
- `${RUN_DIR}/.user-build-choice`: `y`, `yes`, `n`, or `no`.
- `$CANONICAL_SPEC_PATH`: accepted spec from Stage 4.
- `CXMEM_HOME`, `CXMEM_PROJECT`, `CXMEM_HOST_STATE`, `CXMEM_SESSION_SLUG`, `SESSIONS_ROOT`, `MAIN_ROUND_SEQ` when present.
- `tmux`: required for detached build launcher.

### Dispatch

```bash
cp "$CANONICAL_SPEC_PATH" "$RUN_DIR/00-spec.md"
LATEST_STAGE3_VERDICT="$(grep -E '^Codex 2nd-opinion verdict:' "$RUN_DIR/03-decisions.md" | tail -1 | sed -E 's/^Codex 2nd-opinion verdict: ([A-Z-]+):.*/\1/')"
MODE_AUTO="no"; NO_USER_DECISIONS="no"; STAGE3_AGREE="no"
[[ -f "$RUN_DIR/.mode-auto" ]] && MODE_AUTO="yes"
grep -q '^Decided-by: user$' "$RUN_DIR/03-decisions.md" || NO_USER_DECISIONS="yes"
[[ "$LATEST_STAGE3_VERDICT" == "AGREE" ]] && STAGE3_AGREE="yes"
if [[ "$MODE_AUTO" == yes && "$NO_USER_DECISIONS" == yes && "$STAGE3_AGREE" == yes ]]; then
  if printf 'auto_launch=yes\nmode_auto=%s\nno_user_decisions=%s\nstage3_agree=%s\nlatest_stage3_verdict=%s\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE" "$LATEST_STAGE3_VERDICT" > "$RUN_DIR/.auto-launch-decision"; then
    DECISION_ID="stage5-auto-launch-$(date -u +%Y-%m-%d-%H%M)"
    DECISION_FILE="$RUN_DIR/.stage5-auto.md"
    printf 'Decision: auto-launch claudex-build\nPredicate: mode_auto=%s no_user_decisions=%s stage3_agree=%s\nCodex 2nd-opinion verdict: %s: latest Stage 3 design gate\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE" "$LATEST_STAGE3_VERDICT" > "$DECISION_FILE"
    bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE" --decided-by auto --foldability n/a --high-blast no
    RUN_ID="$RUN_ID" RUN_DIR="$RUN_DIR" CANONICAL_SPEC_PATH="$CANONICAL_SPEC_PATH" CXMEM_HOME="${CXMEM_HOME:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" CXMEM_HOST_STATE="${CXMEM_HOST_STATE:-}" CXMEM_SESSION_SLUG="${CXMEM_SESSION_SLUG:-}" SESSIONS_ROOT="${SESSIONS_ROOT:-}" MAIN_ROUND_SEQ="${MAIN_ROUND_SEQ:-}" bash scripts/start-tmux-build.sh
  else
    AUTO_LAUNCH_WRITE_FAILED="failed to write $RUN_DIR/.auto-launch-decision"
    DECISION_ID="stage5-auto-launch-write-failed-$(date -u +%Y-%m-%d-%H%M)"
    DECISION_FILE="$RUN_DIR/.stage5-auto.md"
    printf 'Decision: halt auto-launch for user handoff\nPredicate: mode_auto=%s no_user_decisions=%s stage3_agree=%s\nAuto-launch write failure: %s\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE" "$AUTO_LAUNCH_WRITE_FAILED" > "$DECISION_FILE"
    bash scripts/record-decision.sh "$RUN_DIR" "$DECISION_ID" "$DECISION_FILE" --decided-by user --foldability n/a --high-blast no
    bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
    bash scripts/gate-user-build-choice.sh "$RUN_DIR"
    RUN_ID="$RUN_ID" RUN_DIR="$RUN_DIR" CANONICAL_SPEC_PATH="$CANONICAL_SPEC_PATH" CXMEM_HOME="${CXMEM_HOME:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" CXMEM_HOST_STATE="${CXMEM_HOST_STATE:-}" CXMEM_SESSION_SLUG="${CXMEM_SESSION_SLUG:-}" SESSIONS_ROOT="${SESSIONS_ROOT:-}" MAIN_ROUND_SEQ="${MAIN_ROUND_SEQ:-}" bash scripts/start-tmux-build.sh
  fi
else
  printf 'auto_launch=no\nmode_auto=%s\nno_user_decisions=%s\nstage3_agree=%s\nlatest_stage3_verdict=%s\n' "$MODE_AUTO" "$NO_USER_DECISIONS" "$STAGE3_AGREE" "$LATEST_STAGE3_VERDICT" > "$RUN_DIR/.auto-launch-decision" 2>/dev/null || true
  bash scripts/dispatch-codex-2nd-opinion.sh "$RUN_DIR" "$RUN_DIR/.q.md" "$RUN_DIR/.r.md"
  bash scripts/gate-user-build-choice.sh "$RUN_DIR"
  RUN_ID="$RUN_ID" RUN_DIR="$RUN_DIR" CANONICAL_SPEC_PATH="$CANONICAL_SPEC_PATH" CXMEM_HOME="${CXMEM_HOME:-}" CXMEM_PROJECT="${CXMEM_PROJECT:-}" CXMEM_HOST_STATE="${CXMEM_HOST_STATE:-}" CXMEM_SESSION_SLUG="${CXMEM_SESSION_SLUG:-}" SESSIONS_ROOT="${SESSIONS_ROOT:-}" MAIN_ROUND_SEQ="${MAIN_ROUND_SEQ:-}" bash scripts/start-tmux-build.sh
fi
```

### Verdict → next step

| Output | Next step |
|---|---|
| `USER_BUILD_YES` | Invoke the detached tmux launch path. |
| `USER_BUILD_NO` | Stop quietly; the approved design and frozen decisions remain in the run trail. |
| tmux missing exit 3 | Halt with apt/brew install hints. |
| start exit 4 | Halt and surface tmux session creation failure. |
| gate exit 3 | Halt; only yes/no is accepted. |
| dispatch exit 3 and `CODEX_STATE=MISSING` | Use `[Codex(fallback)]` sonnet subagent path, then present. |
| dispatch exit 4 and `CODEX_STATE=READY` | Halt with stderr tail. |
| dispatch exit 5 | Halt on schema failure. |
| script exit 2/4/5 | Halt for repair. |
