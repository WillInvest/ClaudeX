---
name: claudex-build
description: Autonomous spec→plan→implement pipeline invoked after claudex-think has approved design and frozen decisions. Codex writes SPEC, PLAN, and IMPLEMENT artifacts; Opus reviews each stage.
---

# claudex — usage notes

These skills (`/claudex:think`, `/claudex:build`, `/claudex:auto`) cooperate closely with **CXMem** (`~/CXMem/`), the central memory store. Personal info, project context, and learned preferences live there — not in plugin source.

CXMem records the raw transcript per round: the user prompt, verbatim assistant output, the agent's plan and reasoning, tool calls and findings, and a concise summary indexed in `session-memory.md` and `project-memory.md`. Future agents read `project-memory.md` first, then drill into the active session.

Source files for each project live under `~/vault/projects/<X>/` (each is its own git repo); transcripts live under `~/CXMem/projects/<X>/`. After `claudex:build` finishes IMPLEMENT, commit source changes in the vault repo *before* writing `99-summary.md`; reference the commit SHA in the summary.

Auto mode (`/claudex:auto`, sentinel `${RUN_DIR}/.mode-auto`) launches `claudex:build` in a detached tmux session named `claudex-build-${CXMEM_PROJECT}-${RUN_ID}`. A session is finished when its run directory contains `99-summary.md` — those tmux sessions are safe to kill; do not kill mid-stage ones.

# claudex-build — autonomous spec→plan→impl pipeline

Definition of done: an accepted SPEC, an approved PLAN, and an implementation that passes Opus review, with a clean run trail under the resolved `RUN_DIR`. The main session reports terse progress only.

## Stage 0 — Setup

Read handoff env first:

```bash
RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-<slug>}"
if [[ -z "${RUN_DIR:-}" ]]; then
  RUN_DIR="$(bash skills/build/scripts/resolve-run-dir.sh "$RUN_ID")"
fi
CANONICAL_SPEC_PATH="${CANONICAL_SPEC_PATH:-<cwd-derived-spec-path>}"
test -f "$RUN_DIR/03-decisions.frozen"
CXMEM_HOST_STATE="$(bash skills/build/scripts/probe-cxmem-host.sh)"
if [[ -z "${TMUX:-}" ]]; then
  echo "[claudex-build][test-only/manual] running outside tmux; continuing for manual/test invocation"
fi
```

When env vars are absent, derive `CANONICAL_SPEC_PATH` from the existing cwd rules used by think. Normal `/claudex:think` handoff supplies `RUN_ID`, `RUN_DIR`, and `CANONICAL_SPEC_PATH` and runs inside detached tmux; inherited `RUN_DIR` wins so an in-flight run cannot move if CXMem state changes. Direct/manual build invocation resolves fresh artifacts through `resolve-run-dir.sh`.

Resolved run paths:

| Host state | `RUN_DIR` |
|---|---|
| `CXMEM_HOST_PROJECT_READY` | `${CXMEM_HOME}/projects/<project>/sessions/<slug>/runs/<run-id>` |
| `CXMEM_HOST_PROJECT_NO_SESSION` | `${CXMEM_HOME}/projects/<project>/runs/<run-id>` |
| `CXMEM_HOST_MISSING` | `${HOME}/vault/projects/claudex/audits/<run-id>` |

### Verdict → next step

| Output | Next step |
|---|---|
| frozen marker exists | Continue to Stage 1. |
| missing frozen marker | Halt; think did not freeze decisions after design approval. |
| `CXMEM_HOST_PROJECT_READY` | Splice `prompts/cxmem-recording-rule-block.md` into SPEC/PLAN/IMPLEMENT prompts and record codex-derived rounds after each codex exec. |
| `CXMEM_HOST_PROJECT_NO_SESSION` | Continue run-trail-only inside CXMem; skip parser/writer. |
| `CXMEM_HOST_MISSING` | Continue run-trail-only in the legacy audit fallback; skip parser/writer. |
| empty `TMUX` | Warn `[test-only/manual]` and continue; normal think handoff must not use this lane. |

## Canonical Loop

Each stage runs Codex round 1, Opus review round 1, optional Codex fix or round 2, and final Opus review if needed. The orchestrator never writes the artifact and never overrides Opus without escalating.

Reviewer verdicts are parsed literally: `ready-to-execute`, `fix-and-proceed`, `re-review-needed`, `escalate`. Round 2 is final; `re-review-needed` or `escalate` after round 2 escalates to the user.

Auto mode is active only when `${RUN_DIR}/.mode-auto` exists. At every reviewer/implementer convergence decision, check the sentinel before showing any user-decision block. Continue and append a convergence row through `~/.claude/plugins/claudex/skills/think/scripts/record-decision.sh` only on `AGREE` with `--decided-by auto --foldability n/a --high-blast no`, or on `ANGLE-MISSED` when the angle is folded without changing the structural answer, using `--decided-by auto --foldability folded --high-blast no`. Halt without an auto-recorded convergence row on `DISAGREE`, structural `ANGLE-MISSED`, high-blast, Codex failure, unparsable verdict, or ambiguous touched-file sets; show this canonical halt block:
`Auto mode halted.`
`Reason: <halt reason>.`
`Review the Codex 2nd opinion above.`
`Choose Claude, Codex, revise, or stop.`
`Your call.`

If the implementer/reviewer recommendation lacks explicit paths and the touched-file set is ambiguous, halt conservatively. After user resolution, record `--decided-by user --foldability n/a --high-blast ambiguous-halted`; for other halt resolutions, record `--decided-by user`, `--foldability structural` only for structural missed angles or `n/a` otherwise, and `--high-blast yes` for high-blast or `no` otherwise. Never remove `${RUN_DIR}/.mode-auto`.

After every Codex exec in SPEC, PLAN, or IMPLEMENT:

```bash
if [[ "$CXMEM_HOST_STATE" == "CXMEM_HOST_PROJECT_READY" ]]; then
  bash skills/build/scripts/parse-codex-cxmem-emissions.sh "$CODEX_LOG" > "$RUN_DIR/$STAGE-r$CODEX_ROUND.cxmem.json"
  if jq -e '.degraded_recommended == true' "$RUN_DIR/$STAGE-r$CODEX_ROUND.cxmem.json" >/dev/null; then
    bash skills/build/scripts/write-cxmem-round.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND" --degraded "$CODEX_LOG" "$GIT_DIFF_OR_EMPTY_STAT"
  else
    reviewer_args=()
    if [[ -f "$REVIEWER_REVIEW_PATH" ]]; then
      reviewer_args=(--reviewer-review "$REVIEWER_REVIEW_PATH")
    elif [[ -n "${REVIEWER_SKIPPED_SUMMARY:-}" ]]; then
      reviewer_args=(--reviewer-skipped "$REVIEWER_SKIPPED_SUMMARY")
    else
      reviewer_args=(--reviewer-unavailable "${REVIEWER_UNAVAILABLE_REASON:-reviewer artifact unavailable}")
    fi
    bash skills/build/scripts/write-cxmem-round.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ" "$STAGE" "$CODEX_ROUND" "$RUN_DIR/$STAGE-r$CODEX_ROUND.cxmem.json" \
      --prompt "$CODEX_PROMPT_PATH" \
      --clean-output "$CODEX_CLEAN_OUTPUT_PATH" \
      "${reviewer_args[@]}"
  fi
fi
```

Codex-derived round files receive prompt/output/reviewer evidence immediately after the codex exec/parser/writer sequence completes. Their `## Round close` section is deferred until the parent main round closes, so it can summarize the final close context. When the parent main round closes, codex-derived summaries are promoted as nested sub-list items under that parent in `session-memory.md`; `project-memory.md` receives only the parent main-round session-log row, not separate rows for codex-derived rounds.

Run the promotion helper after the parent close block is appended:

```bash
bash skills/build/scripts/append-codex-round-close.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ"
bash skills/build/scripts/promote-codex-round.sh "$SESSIONS_ROOT" "$CXMEM_PROJECT" "$CXMEM_SESSION_SLUG" "$MAIN_ROUND_SEQ"
```

## Stage 1 — SPEC

Codex materializes the implementation spec from the approved design and frozen decisions. Use `spec-codex-prompt.md`, filled with:

- `${RUN_DIR}/04-design.md`
- `${RUN_DIR}/03-decisions.md`
- `${RUN_DIR}/05-approaches.md`
- `CANONICAL_SPEC_PATH`
- adaptive project context
- `prompts/cxmem-recording-rule-block.md` only when `CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY`

Dispatch with:

```bash
CXMEM_HOST_STATE="$CXMEM_HOST_STATE" ADAPTIVE_CONTEXT_PATH="$RUN_DIR/adaptive-context.md" \
  bash skills/build/scripts/dispatch-codex-spec-write.sh "$RUN_DIR" "$ROUND" "$RUN_DIR/04-design.md" "$RUN_DIR/05-approaches.md" "$CANONICAL_SPEC_PATH"
bash skills/build/scripts/build-opus-spec-review-prompt.sh "$RUN_DIR" "$REVIEW_ROUND" "$RUN_DIR/05-approaches.md"
```

The reviewer prompt uses `reviewer-prompt.md` with `stage=spec`, source document = approved design + frozen decisions + approaches, and artifact = generated spec. Accepted SPEC proceeds to PLAN.

## Stage 2 — PLAN

Use `plan-codex-prompt.md`, fill `{{spec_contents}}` from `CANONICAL_SPEC_PATH`, fill the adaptive block from project context, and replace `{{recording_rule_block}}` with the R9 recording rule only when `CXMEM_HOST_STATE=CXMEM_HOST_PROJECT_READY`; otherwise replace it with an empty string.

Run Codex read-only in `RUN_DIR`, save raw and clean plan artifacts, dispatch Opus with `reviewer-prompt.md` using `stage=plan`, source document = accepted spec, artifact = clean plan, then apply the canonical loop.

## Stage 3 — IMPLEMENT

Use `impl-codex-prompt.md`, fill `{{plan_contents}}` from the approved plan, derive allowed/out-of-scope files from the plan, fill adaptive gotchas, and replace `{{recording_rule_block}}` exactly as in PLAN.

Run Codex with workspace write access in the target repo, capture log/stat/diff, dispatch Opus with `reviewer-prompt.md` using `stage=implement`, source document = approved plan, artifact = diff + stat + log tail, then apply the canonical loop.

## Run Trail

Everything lives under the resolved `RUN_DIR`:

```text
00-setup.md
03-decisions.md
<frozen-decisions-marker>
04-design.md
05-approaches.md
06-spec-r1.md
06-spec-r1.clean.md
07-spec-r1-review-prompt.md
10-plan-prompt.md
11-plan-r1.md
12-plan-r1.clean.md
13-plan-r1-review.md
20-impl-prompt.md
21-impl-r1.log
21-impl-r1.diff
21-impl-r1.stat
22-impl-r1-review.md
99-final-summary.md
```

`99-final-summary.md` must include the R12 warnings emitted by `scripts/render-final-summary-warnings.sh`; that generator is the source of truth. The current required lines are:

- branch is half-applied
- to finish R12, run `bash projects/mem/artifacts/migrate-r12.sh`
- after migration, run `bash projects/mem/sessions/<slug>/runs/<run-id>/run-tests.sh` for post-migration regression tests

The build skill is not a brainstorming tool, not an ad-hoc code review workflow, and not a way for the orchestrator to write code while attributing it to Codex.
