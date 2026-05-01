---
name: brainstorming
description: Claudex-native brainstorm pipeline for turning ideas into approved designs and Codex-authored specs with Opus review before build handoff.
---

# Brainstorming Ideas Into Designs

Help turn ideas into fully formed designs and implementation-ready specs through natural collaborative dialogue, dual-model challenge, and a shared audit trail.

## 1. When this skill applies

Use this before creative or product-shaping work: creating features, building components, adding functionality, changing behavior, or preparing work for `/claudex:build`.

The skill is right when:

- The user has an idea that needs framing, requirements, tradeoffs, or design.
- The work should become a spec before implementation.
- A wrong interpretation would waste meaningful implementation time.

The skill is wrong when:

- The user asks a direct factual question or requests a trivial one-line edit.
- The user has already supplied an approved, implementation-ready spec and wants build.
- The work is pure debugging with no product/design choice to settle.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

### Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## 2. Codex availability probe

**Before any dispatch**, probe codex availability ONCE per skill invocation and before any clarifying question:

```bash
command -v codex >/dev/null && echo CODEX_READY || echo CODEX_MISSING
```

- If `CODEX_READY`: use `codex exec` dispatches as written.
- If `CODEX_MISSING`: notify the user ONCE with this exact line, then use a fresh Claude subagent as the fallback writer/reviewer for each Codex role:

  > Codex CLI not detected — a Claude subagent will play Codex's role for this brainstorm. Dual-vendor diversity is degraded; independent-context review is preserved. Install codex (`npm install -g @openai/codex`) for the full dual-model behavior.

Fallback attribution is explicit: outputs produced by the fallback are labeled `[Codex(fallback)]` in audit artifacts. If Codex is available but a runtime dispatch fails, use the same fallback for that dispatch only and note the failure in one short line.

## 3. Role split

| Role | Who | What they do | What they NEVER do |
|---|---|---|---|
| Orchestrator | Main Claude (you) | Probe Codex; drive the user dialogue; write audit files; dispatch Codex and Opus; present questions, options, and design sections; enforce gates; decide loop control from reviewer verdicts | Implement; write or edit the spec body (Codex authors every byte of spec content); skip the approved design gate; let Claude-only recommendations silently drive final scope |
| Framing challenger | Codex A1 | Review initial framing before the first clarifying question using `intake-prompt.md` | See Claude's later questions; write the spec |
| Angle auditor | Codex A3 | Check for missed angles before independent approaches using `angle-audit-prompt.md` | Receive Claude's draft proposals |
| Independent proposer | Codex A2 | Produce independent approaches from transcript and decisions using `approaches-codex-prompt.md` | Read Claude's draft approaches; inherit main-session context |
| Second opinion | Codex | Challenge recommendation-bearing questions using `second-opinion-prompt.md` | Decide for the user |
| Spec writer | Codex | Write specs and fixes using `spec-codex-prompt.md`; copy the decisions preamble byte-for-byte | Review its own spec; edit `03-decisions.md` |
| Reviewer | Fresh Opus 4.7 subagent | Review Codex specs using `spec-reviewer-prompt.md` with DRIFT / QUALITY / VERDICT | Edit the spec; run Codex; carry state across rounds |
| User | The human | Answers questions, chooses among tradeoffs, approves design, resolves escalations | Be asked to review routine spec convergence unless they explicitly request it |

## 4. Pipeline overview

```
Stage 0 Setup
   │
   ▼
Stage 1 Intake framing       A1 before first clarifying question
   │
   ▼
Stage 2 Dialogue             transcript + decisions append as conversation proceeds
   │
   ▼
Stage 3 Approaches           A3 angle audit loop, then A2 independent proposal
   │
   ▼
Stage 4 Design convergence   user approves design sections one at a time
   │
   ▼
Stage 5 Spec write + review  Codex spec, Opus review, max 2 reviews
   │
   ▼
Stage 6 Handoff to build     inline or detached, same RUN_ID audit trail
```

The terminal state is invoking build. Do NOT invoke writing-plans, frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is build.

## 5. Stage 0: Setup

Create one run id and one audit directory before dialogue:

```bash
RUN_ID="$(date -u +%Y-%m-%d-%H%M)-<slug>"
mkdir -p "/tmp/claudex/${RUN_ID}"
```

Use a short kebab-case slug from the user's goal. Then:

- Probe Codex exactly once as described above.
- Start `/tmp/claudex/${RUN_ID}/02-transcript.md`.
- Start `/tmp/claudex/${RUN_ID}/03-decisions.md`.
- Record setup notes and project context in `/tmp/claudex/${RUN_ID}/00-setup.md`.
- If a visual companion may help, offer it before detailed visual questions, using the preserved wording in section 14.

Audit files are written as the dialogue proceeds, not reconstructed at the end.

## 6. Stage 1: Intake framing

Before asking the first clarifying question, dispatch A1 using `intake-prompt.md` with the initial user request and any immediately observed project context. Save the result to `/tmp/claudex/${RUN_ID}/01-intake-verdict.md`.

A1 returns exactly one status: `OK`, `REFRAME`, or `DECOMPOSE`.

- `OK`: continue to the first clarifying question.
- `REFRAME`: show the reframing before the first question and ask the user to confirm or correct it.
- `DECOMPOSE`: explain why the request is too broad for one spec, help choose the first sub-project, and then continue this pipeline for that sub-project.

Do not hide A1 disagreement. The point is to catch wrong framing before the dialogue anchors on it.

## 7. Stage 2: Dialogue

Ask questions one at a time. Append every user-visible question and every answer to `/tmp/claudex/${RUN_ID}/02-transcript.md` as they happen.

When a decision is made, append it to `/tmp/claudex/${RUN_ID}/03-decisions.md` immediately. Include:

- Decision
- Rationale
- Source: user, Claude recommendation, Codex recommendation, or both
- `Picked-over:` whenever the user rejects either model's recommendation

Whenever you are about to ask a question that offers multiple choices or carries a recommendation, draft the question internally — DO NOT show it to the user yet — then dispatch `second-opinion-prompt.md`. Only after Codex's verdict returns, present the question to the user as a single message in this shape:

```
[your question + options + your recommendation]

[Codex second opinion]: <verdict line>

Your call.
```

The question must be shown to the user exactly once, with Codex's verdict already embedded. Never announce "Dispatching Codex" with the drafted question visible — that is the duplication anti-pattern. Do not treat agreement between models as user approval.

## 8. Stage 3: Approaches

Before proposing approaches, dispatch A3 using `angle-audit-prompt.md` with `{{TRANSCRIPT}}` and `{{DECISIONS}}`. Save output to `/tmp/claudex/${RUN_ID}/04-angle-audit.md`.

A3 returns exactly one status: `CLEAR`, `GAP`, or `WRONG-DIRECTION`.

- `CLEAR`: proceed to A2.
- `GAP`: ask the missed-angle question, append the Q+A to `02-transcript.md`, append any resulting decision to `03-decisions.md`, and dispatch A3 again. Loop until `CLEAR`, `WRONG-DIRECTION`, or user override.
- `WRONG-DIRECTION`: escalate with three options: reframe and continue, proceed despite the warning, or stop.

After A3 clears, dispatch A2 using `approaches-codex-prompt.md`. A2 receives `{{TRANSCRIPT}}` and `{{DECISIONS}}` only; it does not receive Claude's draft proposals or main-conversation context.

Then prepare `/tmp/claudex/${RUN_ID}/05-approaches.md` with:

- 2-3 Claude approaches, if useful.
- A2's independent approaches.
- Attribution on each approach: `[Claude]`, `[Codex]`, `[both]`, or `[Codex(fallback)]`.
- Claude's pick and Codex's pick.

Merge only under the conservative two-condition rule: merge approaches only when they have the same user-visible behavior and the same implementation boundary. If either differs, present them separately.

## 9. Stage 4: Design convergence

Present the design in sections scaled to complexity, getting approval after each section before moving to the next. Cover:

- Problem and success criteria
- Approach (selected)
- Architecture
- Components
- Data flow
- Error handling
- Testing
- Out of scope

If the user redirects mid-dialogue, append the redirect to `02-transcript.md`, update `03-decisions.md`, and revisit any affected sections. After the user approves the final design, proceed to Stage 5 without an extra user-review gate unless the user explicitly asks to review the written spec before build.

## 10. Stage 5: Spec write + Opus review

**Bright-line rule for the orchestrator at this stage:** you NEVER use the `Write` tool to author spec body content. Every byte of the spec body comes from `codex exec` output. Your only allowed file actions at Stage 5 are: (a) writing the prompt files in `/tmp/claudex/${RUN_ID}/`; (b) running `cp` / shell redirection to clean Codex output and copy it to the canonical spec path; (c) writing the Opus reviewer's response file. If you find yourself drafting Markdown spec sections in your own response and using `Write`, stop. The contract is the contract.

Freeze `/tmp/claudex/${RUN_ID}/03-decisions.md` when Stage 4 approval is complete. From this point, do not edit it. Codex-only spec edits are allowed; Claude does not write or patch the spec body except to mechanically strip Codex wrapper text during cleanup (a `sed`/`awk` shell pass, not Markdown authoring).

Codex writes the spec using `spec-codex-prompt.md` with `{{TRANSCRIPT}}`, `{{DECISIONS}}`, `{{APPROACHES}}`, and `{{DESIGN}}`. The spec body structure is:

```
# <topic> — design
## Decisions preamble
## Problem
## Approach (selected)
## Architecture
## Components
## Data flow
## Error handling
## Testing
## Out of scope
```

The `## Decisions preamble` content must byte-match frozen `03-decisions.md`. A mismatch is DRIFT.

Canonical loop (concrete bash + Agent dispatches; pseudocode below as a roadmap):

```bash
# Build the round-1 prompt by filling spec-codex-prompt.md slots, write to:
#   /tmp/claudex/${RUN_ID}/spec-prompt-r1.md

# Round 1 — Codex writes the spec.
codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  -C "/tmp/claudex/${RUN_ID}" \
  - < "/tmp/claudex/${RUN_ID}/spec-prompt-r1.md" \
  > "/tmp/claudex/${RUN_ID}/06-spec-r1.md" \
  2>&1

# Strip Codex wrapper noise (e.g. session banner, "tokens used" footer) — shell only.
sed -n '/^# /,$p' "/tmp/claudex/${RUN_ID}/06-spec-r1.md" \
  | sed '/^tokens used/,$d' \
  > "/tmp/claudex/${RUN_ID}/06-spec-r1.clean.md"

# Copy to canonical spec path (overwrite each round; do NOT use the Write tool).
cp "/tmp/claudex/${RUN_ID}/06-spec-r1.clean.md" "${CANONICAL_SPEC_PATH}"
```

Then dispatch the Opus reviewer with the `Agent` tool (`subagent_type: "general-purpose"`, `model: "opus"`), using `spec-reviewer-prompt.md` filled with `{{TRANSCRIPT}} {{DECISIONS}} {{APPROACHES}} {{SPEC}}`. Save the reviewer's reply to `/tmp/claudex/${RUN_ID}/07-spec-r1-review.md`.

If `codex` is `MISSING` or fails at runtime, dispatch the same prompt via `Agent` (`model: "sonnet"`); the subagent's reply IS the round's spec output. Strip wrapper noise the same way and `cp` to canonical. Never substitute `Write` for `cp` here — the rule is about the *source* of the bytes, and `cp` makes that auditable.

Roadmap (read with the bash above):

```python
spec = dispatch_codex("06-spec-r1.md")
clean("06-spec-r1.md", "06-spec-r1.clean.md")
canonical_spec = overwrite_from("06-spec-r1.clean.md")
review = dispatch_opus("07-spec-r1-review.md")

match review.verdict:
    case "ready-to-execute":
        return canonical_spec
    case "fix-and-proceed":
        fix = dispatch_codex("06-spec-r1-fix.clean.md", resume=True)
        canonical_spec = overwrite_from(fix)       # no re-review
        return canonical_spec
    case "escalate":
        escalate_to_user()
    case "re-review-needed":
        pass

spec = dispatch_codex("08-spec-r2.md", resume=True)
clean("08-spec-r2.md", "08-spec-r2.clean.md")
canonical_spec = overwrite_from("08-spec-r2.clean.md")
review = dispatch_opus("09-spec-r2-review.md")

match review.verdict:
    case "ready-to-execute":
        return canonical_spec
    case "fix-and-proceed":
        fix = dispatch_codex("08-spec-r2-fix.clean.md", resume=True)
        canonical_spec = overwrite_from(fix)       # no re-review
        return canonical_spec
    case "re-review-needed" | "escalate":
        escalate_to_user()                         # NO round 3
```

Use these exact verdict strings: `ready-to-execute`, `fix-and-proceed`, `re-review-needed`, `escalate`, `WRONG-DIRECTION`.
Static vocabulary check literal: `ready-to-execute\|fix-and-proceed\|re-review-needed\|escalate\|WRONG-DIRECTION`.

The reviewer prompt is `spec-reviewer-prompt.md`. Save Opus reviews to `07-spec-r1-review.md` and `09-spec-r2-review.md`. A `fix-and-proceed` verdict has no re-review. A round-2 `re-review-needed` escalates; there is no round 3.

Codex session continuity:

```bash
codex exec resume --last - < /tmp/claudex/$RUN_ID/<prompt>.md
```

`codex exec resume` accepts `--skip-git-repo-check` and `--last`, but `resume` does not accept `-C/--sandbox`; cd into the run directory in a subshell before resume when directory context matters. If resume selects the wrong session, fall back to fresh `codex exec`; prompts embed prior artifacts inline.

If Codex outputs `WRONG-DIRECTION: <reason>` as the entire first line, stop the spec loop and escalate with three options: revisit the design, proceed despite Codex's warning, or stop.

## 11. Stage 6: Handoff to build

Write or overwrite `/tmp/claudex/${RUN_ID}/00-spec.md` from the canonical spec path. This is the binding handoff copy for build.

**Bright-line rule: do NOT invoke the `claudex:build` skill (via the `Skill` tool or any other path) until the user has picked 1 or 2 below. Approving the design is NOT approval to start the build. Saying "Starting build." before the user replies, then invoking the skill, is the auto-launch anti-pattern — it skips the inline-vs-detached choice and is a violation of this gate.**

Probe tmux explicitly via Bash:

```bash
command -v tmux >/dev/null && echo TMUX_PRESENT || echo TMUX_MISSING
```

- **TMUX_MISSING** → announce, in this exact form: `tmux not found — running build inline. Install tmux for detached builds that survive SSH drops.` Then export `RUN_ID` and invoke the `claudex:build` skill inline. Skip the prompt below.

- **TMUX_PRESENT** → present this message verbatim as a single user-visible turn, then **STOP and wait for the user's reply**:

  ```text
  Spec at <path>. How should I run the build?
    1) Inline (this session — dies if SSH drops)
    2) Detached tmux (survives SSH drops; you attach with `tmux attach -t <name>`)
  ```

  Do nothing else in that turn — no tool calls, no preamble, no "I will now…" narration. Wait for the user to reply with `1` or `2`.

  - Reply `1` → export `RUN_ID` and invoke the `claudex:build` skill inline.

  - Reply `2` → run the launcher from this skill directory (do NOT invoke the build skill in this session; detached tmux owns the build):

    ```bash
    bash scripts/start-tmux-build.sh "<spec-path>" "$RUN_ID"
    ```

    Echo the script's stdout verbatim.

The build skill keeps its direct-invocation fallback `RUN_ID="${RUN_ID:-...}"`, so direct `/claudex:build <spec>` behavior remains unchanged while brainstorming handoff preserves the shared run id.

At the end of build, `/tmp/claudex/${RUN_ID}/99-final-summary.md` should reference both brainstorm and build artifacts.

## 12. Audit trail layout

Expected brainstorm artifacts:

```text
/tmp/claudex/<run-id>/
  00-setup.md
  00-spec.md
  01-intake-verdict.md
  02-transcript.md
  03-decisions.md
  04-angle-audit.md
  05-approaches.md
  06-spec-r1.md
  06-spec-r1.clean.md
  06-spec-r1-fix.clean.md
  07-spec-r1-review.md
  08-spec-r2.md
  08-spec-r2.clean.md
  08-spec-r2-fix.clean.md
  09-spec-r2-review.md
  99-final-summary.md
```

Not every round/fix file exists in successful early exits, but the names above are canonical.

## 13. Failure modes

- **Codex missing:** use the declared fallback once per dispatch and label outputs `[Codex(fallback)]`.
- **Codex runtime failure:** fallback for that dispatch; do not block routine brainstorming.
- **A1 `DECOMPOSE`:** decompose before detailed questions.
- **A3 repeated `GAP`:** ask the missed-angle questions until clear, user override, or wrong-direction escalation.
- **A2 conflicts with Claude:** present both unless the conservative two-condition merge rule is satisfied.
- **User picks against a recommendation:** record `Picked-over:` in `03-decisions.md`.
- **Decisions preamble mismatch:** reviewer flags as DRIFT.
- **Stage 5 `WRONG-DIRECTION`:** escalate with the three options; do not proceed silently.
- **Round-2 `re-review-needed`:** escalate; no round 3.
- **User explicitly asks to review spec:** honor that request and pause before Stage 6.

## 14. Visual companion

A browser-based companion for showing mockups, diagrams, and visual options during brainstorming. Available as a tool — not a mode. Accepting the companion means it's available for questions that benefit from visual treatment; it does NOT mean every question goes through the browser.

**Offering the companion:** When you anticipate that upcoming questions will involve visual content (mockups, layouts, diagrams), offer it once for consent:
> "Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)"

**This offer MUST be its own message.** Do not combine it with clarifying questions, context summaries, or any other content. The message should contain ONLY the offer above and nothing else. Wait for the user's response before continuing. If they decline, proceed with text-only brainstorming.

**Per-question decision:** Even after the user accepts, decide FOR EACH QUESTION whether to use the browser or the terminal. The test: **would the user understand this better by seeing it than reading it?**

- **Use the browser** for content that IS visual — mockups, wireframes, layout comparisons, architecture diagrams, side-by-side visual designs
- **Use the terminal** for content that is text — requirements questions, conceptual choices, tradeoff lists, A/B/C/D text options, scope decisions

A question about a UI topic is not automatically a visual question. "What does personality mean in this context?" is a conceptual question — use the terminal. "Which wizard layout works better?" is a visual question — use the browser.

If they agree to the companion, read the detailed guide before proceeding:
`skills/brainstorming/visual-companion.md`

## 15. Key principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when something doesn't make sense
