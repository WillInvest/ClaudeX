---
name: claudex-build
description: Autonomous plan→implement pipeline invoked after a brainstorm has produced a spec. Codex (latest model, via `codex exec`) writes the plan and the implementation; a fresh Opus 4.7 subagent reviews each artifact for DRIFT (faithfulness to source) and QUALITY (Minimal / Consistent / Verifiable); orchestrator (main Claude) decides convergence per the canonical loop. Use after the claudex-brainstorming skill has produced a spec; user typically invokes via `/claudex-build` or by being handed off from claudex-brainstorming. Skips per-stage user gates by design — escalates only on hard blockers. Audit trail at `~/vault/projects/claudex/audits/<run-id>/`.
---

# claudex-build — autonomous plan→impl pipeline

## Definition of done

An approved plan + an implementation that passes review, both produced by Codex, judged by an independent Opus 4.7 reviewer, with a clean audit trail under `~/vault/projects/claudex/audits/<run-id>/`. The main session ends with at most a few short status lines, not a transcript of review traffic.

If the run finishes without that, the skill failed, even if code was written.

## When this skill applies

Invoke after a brainstorm has produced a spec — typically via the claudex-brainstorming skill, which hands off here automatically. The skill is right when:

- The feature is non-trivial (multi-file, ≥ a few hours of work).
- A spec exists and you can locate its path.
- The user wants Codex-authored plan + implementation, with you as orchestrator.

The skill is wrong when:

- It's a one-line fix or trivial edit — just do it directly.
- The spec is unclear or still being shaped — finish brainstorming first.
- The work is pure exploration or debugging — handle it conversationally; this skill is for already-specified plan→impl work.

## Codex availability probe (run first)

**Before any dispatch**, probe codex availability ONCE per skill invocation:

```bash
command -v codex >/dev/null && echo CODEX_READY || echo CODEX_MISSING
```

- If `CODEX_READY`: proceed with `codex exec` dispatches as written.
- If `CODEX_MISSING`: notify the user ONCE with this exact line (no preamble, no other text):

  > Codex CLI not detected — a Claude subagent will play Codex's writer role for this build. Dual-vendor diversity is degraded; the Opus reviewer remains independent. Install codex (`npm install -g @openai/codex`) for the full dual-model behavior.

  Then in EVERY codex dispatch site below, dispatch the equivalent prompt via the `Agent` tool with `subagent_type: "general-purpose"`, `model: "opus"`, and the prompt body passed as `prompt`. The subagent's reply is the artifact for that round. Round-2 codex-resume mechanics are skipped in this mode — round-2 dispatches are fresh Agent calls with the round-1 artifact + reviewer feedback embedded inline (this is already how the codex prompts are built, so no re-templating needed).

If codex is `READY` but a runtime call fails (auth/network), do the same Agent fallback inline for that one call and note the failure to the user.

## Assumptions

- **Codex CLI ≥ 0.122.0** (preferred path), with `codex exec resume` available for round-2 session continuity. Verify with `codex --version`. If the resume command is unavailable, the skill falls back to fresh sessions — prompts always embed prior artifacts inline so the fallback is safe. If codex itself is missing, see the availability probe above.
- **Latest Opus is available via `model: "opus"`** in the `Agent` tool. Today that resolves to `claude-opus-4-7`. If the harness changes that binding, the skill still works — it just uses whatever "opus" means.
- **Latest codex model** is what `codex` selects by default at invocation. If a newer model flag is announced (e.g., `gpt-5.5`), the skill auto-uses whatever is current.
- **Spec exists at a known path** before invocation. The skill does not run a brainstorm.

## The contract — who does what

This is the rule that makes the skill work. Do not soften it.

| Role | Who | What they do | What they NEVER do |
|---|---|---|---|
| Orchestrator | Main Claude (you) | Dispatch Codex; dispatch reviewer subagent; read verdict; decide next dispatch; escalate when blocked; report terse summary | Write the plan; write the implementation; write a competing review; override the reviewer's verdict without escalating |
| Worker | `codex exec` (latest model) | Draft the plan; draft the implementation; write tests for the change | Review own output |
| Reviewer | Fresh Claude Opus 4.7 subagent (Agent tool, `model: "opus"`) | Independent review against three quality criteria, returning DRIFT + QUALITY + VERDICT | Edit artifacts; run codex; carry state across rounds; propose specific edits (FLAG ONLY) |
| User | The human | Stays out of the loop unless escalated to | Be pinged for routine convergence |

**Why a separate subagent reviews, not the orchestrator itself:** self-review is empirically weaker than independent review. The reviewer returns a short structured verdict; its working notes stay in its own context.

**Why the orchestrator never overrides the reviewer:** if the orchestrator quietly "decides the reviewer is wrong" and proceeds anyway, the second-pair-of-eyes property collapses. The only valid override path is escalation to the user.

**Why the reviewer flags only:** it preserves the role split. If Opus proposed specific edits, it would be co-authoring the artifact, blurring the independent-review boundary.

## The loop (canonical)

Each stage runs this loop. The orchestrator's only jobs are dispatch and decide.

```python
def run_stage(stage):                       # stage in {"plan", "implement"}

    artifact = dispatch_codex(stage, round=1)               # codex writes
    review   = dispatch_reviewer(artifact, round=1)         # opus 4.7 subagent

    match review.verdict:
        case "ready-to-execute":
            return artifact                                 # done, no fix needed
        case "fix-and-proceed":
            return dispatch_codex(stage,                    # codex applies fixes,
                                  round="fix1",             #   no re-review
                                  feedback=review,
                                  resume=True)
        case "escalate":
            escalate_to_user(stage, artifact, review)       # hard stop
        case "re-review-needed":
            pass                                            # fall through to round 2

    # ROUND 2 — final review allowed
    artifact = dispatch_codex(stage, round=2,
                              feedback=review, resume=True)
    review   = dispatch_reviewer(artifact, round=2)

    match review.verdict:
        case "ready-to-execute":
            return artifact
        case "fix-and-proceed":
            return dispatch_codex(stage,
                                  round="fix2",
                                  feedback=review,
                                  resume=True)
        case "re-review-needed" | "escalate":
            escalate_to_user(stage, artifact, review)       # NO round 3
```

**Verdict vocabulary** (use these exact strings — orchestrator parses them literally):

- `ready-to-execute` — DRIFT empty AND no critical QUALITY items. Proceed with no fix.
- `fix-and-proceed` — issues exist but are minor and clearly actionable; reviewer signs off in advance on Codex applying them. No re-review.
- `re-review-needed` — substantive issues that need judgment in fix. Round 2 follows. **Only valid as round-1 verdict** — round 2 is final.
- `escalate` — fundamental problem the reviewer can't resolve through more rounds (wrong direction, missing context, destructive risk, ambiguous architectural fork). Stop and surface to user.

The full pipeline:

```
spec (locate via path provided by claudex-brainstorming or user)
   │
   ▼
run_stage("plan")        ← max 2 reviews + at most 1 follow-up fix
   │
   ▼
run_stage("implement")   ← max 2 reviews + at most 1 follow-up fix
   │
   ▼
final summary in main session, pointer to audit trail
```

## Models — keep current

- **Codex worker:** latest available. Run `codex exec` without `-m` to let codex pick the latest model, or pass `-m` explicitly if a specific newer model is known. Fall back if rejected.
- **Reviewer subagent:** pass `model: "opus"` to the `Agent` tool. The harness resolves this to the latest Opus (currently `claude-opus-4-7`).
- **Override:** if the user explicitly names a different model in the request, honor it.

## Stage 1: PLAN

### 1a. Locate the spec, set up audit trail

Identify the spec path (provided by the brainstorming handoff or by the user). Compute `<run-id>` as `YYYY-MM-DD-HHMM-<slug>` where `<slug>` is a short kebab-case summary of the goal.

```bash
RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-<slug>}"
mkdir -p ${HOME}/vault/projects/claudex/audits/$RUN_ID
cp <spec-path> ${HOME}/vault/projects/claudex/audits/$RUN_ID/00-spec.md
```

### 1b. Build the plan prompt

The fixed-skeleton prompt is in `plan-codex-prompt.md` in this skill directory. Read it, fill the adaptive `[ADAPTIVE]` block (project context — existing patterns from CLAUDE.md, files most relevant, any clarifications from the brainstorm not in the spec), and write to `${HOME}/vault/projects/claudex/audits/$RUN_ID/10-plan-prompt.md`.

The adaptive section is REFERENCE MATERIAL ONLY. Do not editorialize, do not add instructions, do not tell Codex what to do beyond what the fixed skeleton already says.

### 1c. Invoke Codex (round 1)

```bash
codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  -C ${HOME}/vault/projects/claudex/audits/$RUN_ID \
  - < ${HOME}/vault/projects/claudex/audits/$RUN_ID/10-plan-prompt.md \
  > ${HOME}/vault/projects/claudex/audits/$RUN_ID/11-plan-r1.md \
  2>&1
```

Strip codex's wrapper output (any preamble before the actual plan markdown) and save the cleaned body as `12-plan-r1.clean.md`. If codex crashed or refused, fix the prompt and re-run — don't ship a broken artifact to review.

### 1d. Dispatch the reviewer subagent

Use the `Agent` tool:

- `subagent_type: "general-purpose"`
- `model: "opus"`
- `description`: "Review codex plan for DRIFT and QUALITY"
- `prompt`: read the template at `reviewer-prompt.md` in this skill directory, substitute `{{stage}}` with `plan`, fill the SOURCE DOCUMENT slot with the spec contents, fill the ARTIFACT TO REVIEW slot with `12-plan-r1.clean.md` contents, and dispatch.

Save the reviewer's response as `13-plan-r1-review.md`.

### 1e. Apply the loop

If round 1 verdict is `re-review-needed`, build `14-plan-r2-prompt.md` containing the round-1 review items + the previous plan, and resume the codex session:

```bash
( cd ${HOME}/vault/projects/claudex/audits/$RUN_ID && \
  codex exec resume --last \
    - < ${HOME}/vault/projects/claudex/audits/$RUN_ID/14-plan-r2-prompt.md \
    > ${HOME}/vault/projects/claudex/audits/$RUN_ID/15-plan-r2.md \
    2>&1 )
```

Note: `codex exec resume` does not accept `-C/--cd` (only `codex exec` does), so cd into the run dir in a subshell instead.

If `resume --last` picks the wrong session, fall back to a fresh `codex exec` — the prompt embeds the previous plan inline, so the fallback is safe.

A `fix-and-proceed` follow-up dispatch (round 1 or round 2 final fix) uses the same resume pattern but the reviewer is NOT re-dispatched.

## Stage 2: IMPLEMENT

### 2a. Build the implementation prompt

The fixed-skeleton prompt is in `impl-codex-prompt.md`. Read it, fill the adaptive `[ADAPTIVE]` block (project context + any plan-execution gotchas Claude noticed during plan review), and write to `${HOME}/vault/projects/claudex/audits/$RUN_ID/20-impl-prompt.md`.

Derive the "Files you MAY modify" list from the approved plan. Derive the "Files explicitly OUT of scope" list from the plan's out-of-scope confirmation section.

### 2b. Invoke Codex (round 1)

Implementation needs write access — use `workspace-write`. Run inside the target repo so codex edits the right files:

```bash
codex exec \
  --sandbox workspace-write \
  -C <repo-root> \
  - < ${HOME}/vault/projects/claudex/audits/$RUN_ID/20-impl-prompt.md \
  > ${HOME}/vault/projects/claudex/audits/$RUN_ID/21-impl-r1.log \
  2>&1
```

Capture the diff for review:

```bash
( cd <repo-root> && git diff --stat ) > ${HOME}/vault/projects/claudex/audits/$RUN_ID/21-impl-r1.stat
( cd <repo-root> && git diff )        > ${HOME}/vault/projects/claudex/audits/$RUN_ID/21-impl-r1.diff
```

Sanity-check before dispatching the reviewer:

- Codex didn't crash mid-edit (look at log tail).
- Files outside the "MAY modify" list weren't touched (compare `21-impl-r1.stat` to the allowed list).
- Tests actually ran (check log tail for test output).

### 2c. Dispatch the reviewer subagent

Same `Agent` invocation pattern as Stage 1, but:

- Substitute `{{stage}}` with `implement`.
- SOURCE DOCUMENT is the approved plan.
- ARTIFACT TO REVIEW is the **diff** (not full files), plus `git diff --stat`, plus the codex log's tail (test output).

Save as `22-impl-r1-review.md`.

### 2d. Apply the loop

Round 2 prompt (`23-impl-r2-prompt.md`) references the round-1 diff and review. Resume the codex session so it remembers the implementation context:

```bash
( cd <repo-root> && \
  codex exec resume --last --full-auto \
    - < ${HOME}/vault/projects/claudex/audits/$RUN_ID/23-impl-r2-prompt.md \
    > ${HOME}/vault/projects/claudex/audits/$RUN_ID/24-impl-r2.log \
    2>&1 )
```

Note: `codex exec resume` does not accept `-C/--cd` or `--sandbox` (only `codex exec` does). Use `--full-auto` (the workspace-write alias) and cd into `<repo-root>` in a subshell.

The reviewer for round 2 should focus on **what changed since round 1** and verify each round-1 finding was addressed — pass both the round-1 review and the new diff.

## Codex session continuity

Prefer `codex exec resume --last` for any follow-up dispatch within a stage, so codex retains its reasoning context. Reset (fresh `codex exec`) when crossing stage boundaries (plan → implement) — that's a clean handoff.

If `resume --last` picks the wrong session (e.g., the user ran codex between rounds), the prompts always embed the previous artifact inline, so a fresh-session fallback gives correct results. When in doubt, fall back.

## Escalation: when to stop and ask the user

Escalate when:

1. **Loop says escalate** — round 2 verdict is `re-review-needed` or `escalate`, OR round 1 verdict is `escalate`.
2. **Destructive risk** — data loss, secret exposure, irreversible external action, scope explosion (>2× the file count codex was authorized to touch), or a security-sensitive change the brainstorm did not anticipate.
3. **Ambiguous architectural fork** — the artifact requires a choice between paths with material tradeoffs not pinned down by the brainstorm.
4. **Codex itself fails repeatedly** — two failed invocations in a row that aren't fixable by tweaking the prompt.

Escalation format in the main session:

```
[claudex-build] Escalating at <stage>, round <N>.

Issue: <≤2 sentences>

Options:
1. <continue iterating with X>
2. <override and proceed>
3. <revise scope to Y>
4. <abort>

Audit trail: ~/vault/projects/claudex/audits/<run-id>/
```

Wait for the user's response. Silence is not approval.

## Reporting back to the main session

Keep main-session output terse. After each stage:

```
[claudex-build] PLAN: round <N> verdict=<v>. <one-sentence summary>. Proceeding.
```

After Stage 2:

```
[claudex-build] IMPLEMENT: round <N> verdict=<v>. <K> files changed, tests <pass/fail>. Done.
Audit trail: ~/vault/projects/claudex/audits/<run-id>/
```

If you proceeded with deferred items (`fix-and-proceed` after round 2 with remaining IMPORTANT or SUGGESTIONS), include a one-line `deferred:` note pointing at the review file.

## Audit trail layout

Everything lives under `~/vault/projects/claudex/audits/<run-id>/`:

```
00-spec.md
10-plan-prompt.md
11-plan-r1.md                    (raw codex output — wrapper noise included)
12-plan-r1.clean.md              (extracted plan body)
13-plan-r1-review.md
14-plan-r2-prompt.md             (only if round 2 was triggered)
15-plan-r2.md
16-plan-r2-review.md
20-impl-prompt.md
21-impl-r1.log
21-impl-r1.diff
21-impl-r1.stat
22-impl-r1-review.md
23-impl-r2-prompt.md             (only if round 2 was triggered)
24-impl-r2.log
24-impl-r2.diff
24-impl-r2.stat
25-impl-r2-review.md
99-final-summary.md              (your end-of-pipeline summary, ≤ 300 words)
```

The user can read any of these to audit your judgment after the fact. The `99-final-summary.md` is the file they're most likely to read — make it worth their time.

## What this skill is NOT

- A spec-writer — the spec already exists when this skill runs.
- A code-review skill for arbitrary diffs — review happens inline at each round here; for ad-hoc reviews use whatever review skill your harness provides.
- A debugging tool — use a debugging workflow (root-cause → minimal repro → fix); this skill assumes the spec is already correct.
- A way for the orchestrator to write code while saying "Codex did it." If you find yourself drafting plan content or writing implementation diffs in the main session, stop. The contract is the contract.
