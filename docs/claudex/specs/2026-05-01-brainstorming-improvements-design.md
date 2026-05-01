# Brainstorming skill — dual-model deepening + ecosystem fit

**Date:** 2026-05-01
**Branch:** `feat/brainstorming-improvements`
**Status:** Spec — awaiting build

## Problem

The claudex `brainstorming` skill was inherited from upstream `superpowers` and patched with three `<!-- CLAUDEX:BEGIN -->` blocks (codex availability probe, per-recommendation 2nd opinion, final-design verdict + build handoff). It dispatches Codex at only **two** structural points (recommendation moments + final-design verdict) and self-reviews its own spec. Three resulting weaknesses:

1. **Wrong-problem-framing** can survive the whole dialogue because Codex first sees the problem only at the one-round final verdict, after the design has already converged. Too late to redirect cheaply.
2. **Approach proposals** are Claude-only; Codex never proposes its own approach set. The user picks from one model's option space.
3. **Spec self-review** is solo. The orphan `spec-document-reviewer-prompt.md` was provisioned for an independent reviewer but never wired in. Drift between brainstorm intent and the spec depends on Claude noticing its own omissions.

After the v0.2.x consolidation (PR #10), claudex owns only two skills (`brainstorming` and `build`). Brainstorming is the entry point of the whole pipeline and the only stage where "wrong problem" cannot be caught downstream — `build`'s plan/impl reviewer trusts the spec is right.

## Approach (selected)

**X — Full pipeline parity** (chosen over Y "minimum touchpoints" and Z "brainstorm-as-mini-build").

Brainstorming becomes a first-class stage in the same `/tmp/claudex/<run-id>/` audit pipeline as plan and impl, with the same write-then-Opus-reviews loop pattern at the spec stage. The brainstorming skill creates the `RUN_ID` and the run directory; `build` inherits both. `SKILL.md` is rewritten as a single claudex-native document — no patch markers, no upstream-prose remnants the user has to mentally subtract. Prompt templates are extracted into sibling files (parity with build's flat layout). `Y` is too timid given the user's "we know the essence, structural modify is fine" signal. `Z` would merge two marketplace-exposed skills and break `/claudex:brainstorming` muscle memory; the win isn't worth that cost on a v0.2.x increment.

Inside this approach, three new dual-model touchpoints land:

- **A1 — Intake framing review.** Once, before the first clarifying question. Codex either confirms the framing or flags `REFRAME` / `MISSING-INPUT`.
- **A2 — Independent approach proposals.** Once, when dialogue converges. Both models independently propose 2–3 approaches + a top pick + reasoning. Claude *mechanically* merges; the user resolves any disagreement. **No debate** — diversity of opinion is the value, and debate averages it away.
- **A3 — Clarifying-question angle audit.** Once, just before A2. Codex audits the question history and either confirms `COVERAGE-OK` or returns `GAP` with up to 3 missed angles to ask before approaches.

The existing per-recommendation second-opinion (`AGREE` / `DISAGREE` / `ANGLE-MISSED`) is preserved unchanged — it's the cheap, ubiquitous one and the user is already familiar with its shape.

The **spec is written by Codex, not Claude.** A fresh Opus subagent reviews it against `[transcript + decisions + approaches + spec]` using the canonical DRIFT + QUALITY (Minimal / Consistent / Verifiable) verdict template, same vocabulary as build's reviewer (`ready-to-execute` / `fix-and-proceed` / `re-review-needed` / `escalate`). Round 1 + 2 max, no round 3.

The **decisions log is the spec's preamble.** During dialogue, `03-decisions.md` accumulates the user's explicit picks at every recommendation moment plus any "do this not that" overrides. Codex's spec-write step copies the decisions verbatim into the spec body's first section. The spec is `decisions ⊕ body` — one source of truth. No spec-vs-decisions precedence ambiguity. Build's plan/impl reviewer requires no prompt update because DRIFT is checked against the spec, and decisions are inside the spec via the preamble.

## Architecture

### Pipeline

```
/claudex:brainstorming  <user request>
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 0: SETUP                                    │
│   create run-id, mkdir /tmp/claudex/<run-id>/     │
│   probe codex availability ONCE                   │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 1: INTAKE FRAMING (A1)                      │
│   dispatch Codex with raw user request +          │
│     project-context summary                       │
│   verdict: FRAMING-OK | REFRAME | MISSING-INPUT   │
│   write 01-intake-verdict.md                      │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 2: DIALOGUE                                 │
│   one-question-at-a-time (existing)               │
│   per-recommendation Codex 2nd opinion (existing) │
│   append every Q+A and Codex verdict to           │
│   02-transcript.md as it happens                  │
│   append decisions to 03-decisions.md             │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 3: APPROACHES                               │
│   A3 angle audit fires first                      │
│     verdict: COVERAGE-OK | GAP                    │
│     on GAP → ask missed-angle questions, loop     │
│   A2 fires when COVERAGE-OK                       │
│     Claude proposes internally                    │
│     Codex proposes (does NOT see Claude's draft)  │
│     mechanical merge (no debate)                  │
│     present union with attribution + both picks   │
│   user picks → 03-decisions.md + 05-approaches.md │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 4: DESIGN CONVERGENCE                       │
│   present design sections, user approves each     │
│   per-recommendation 2nd opinion fires on         │
│     sub-choices (existing)                        │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 5: SPEC WRITE + OPUS REVIEW                 │
│   FREEZE 03-decisions.md at this boundary         │
│   loop (round 1, max 2):                          │
│     codex writes spec (decisions preamble copied  │
│       verbatim from 03-decisions.md each round)   │
│     write 06-spec-rN.md + .clean.md +             │
│       canonical docs/claudex/specs/<...>.md       │
│     dispatch fresh Opus subagent                  │
│     verdict: ready-to-execute |                   │
│              fix-and-proceed |                    │
│              re-review-needed |                   │
│              escalate                             │
│   commit canonical spec only after convergence    │
└───────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────┐
│ STAGE 6: HANDOFF TO BUILD                         │
│   tmux probe → inline | detached prompt           │
│   export RUN_ID; build inherits run dir           │
└───────────────────────────────────────────────────┘
```

### Role split

| Role | Who | What they do | What they NEVER do |
|---|---|---|---|
| Orchestrator | Main Claude | Drive dialogue; dispatch Codex at A1/A2/A3 + per-recommendation; dispatch Opus reviewer at Stage 5; mechanical merge at Stage 3; escalate when blocked | Write the spec; review own brainstorm's spec; resolve user-facing disagreement silently |
| Worker (codex) | `codex exec` (latest model — currently `gpt-5.5`) | A1/A2/A3 verdicts; spec write at Stage 5; per-recommendation 2nd opinion | Self-review |
| Reviewer | Fresh Claude Opus 4.7 subagent (Agent tool, `model: "opus"`) | Independent spec review at Stage 5 — DRIFT + QUALITY + Verdict | Edit the spec; carry state across rounds |
| User | The human | Resolve genuine disagreements at Stage 3; approve design sections at Stage 4; confirm scope and priorities | — |

### Run-id and audit dir contract

- `RUN_ID = <YYYY-MM-DD-HHMM>-<slug>` set by brainstorming at Stage 0; slug is a kebab-case 2–4 word summary of the user's request.
- Audit dir: `/tmp/claudex/<run-id>/`. Created with `mkdir -p` (idempotent — safe whether brainstorm or build calls it).
- **Build handoff contract** (explicit invariants):
  - `RUN_ID` is optional for direct `/claudex:build <spec-path>` invocation. If unset, build creates its own with the existing `RUN_ID="${RUN_ID:-...}"` line (unchanged from today). Backward compatible.
  - When inherited from brainstorm: build's existing `cp <spec-path> /tmp/claudex/$RUN_ID/00-spec.md` step still runs and is the binding handoff. The spec build sees is the canonical `docs/claudex/specs/<...>.md` copy, not brainstorm's intermediate `06/08-spec-rN.clean.md`. If for any reason `00-spec.md` already exists, `cp` overwrites it — that is the intent.
  - **File numbering is partitioned**: brainstorm owns `00-09` (plus the canonical `00-spec.md` slot which build writes), build owns `10-29`, summary at `99`. No collisions by construction.
  - Brainstorm files in `00-09` are **read-only to build**. Build never modifies them. Should the user run a fresh `/claudex:build` against a spec from an old run-id, build still creates `00-spec.md` from the spec path it was given — brainstorm's record of how the spec was reached is preserved.

### Decisions-log freeze and round handling

`03-decisions.md` lifecycle:

| Phase | Behavior |
|---|---|
| Stages 0–4 | Append-only. Every per-recommendation user choice + every "do X not Y" override + the Stage-3 approach pick are appended as the user confirms them. |
| Stage 5 entry | **Frozen.** No further appends. The current contents are the decisions preamble for every spec round. |
| Stage 5 round 2 | If round 1 review surfaces a *new* genuine decision (rare; should escalate instead), `escalate` to user. Decisions are NOT silently amended in round 2. |
| Stage 5 escalation handling | If user resolves an escalation in a way that introduces a new decision, the user-resolution dialogue happens in the main session, the new decision is appended to `03-decisions.md`, then the spec round restarts with the updated preamble. Auditable; not silent. |

Codex's spec-write prompt **copies `03-decisions.md` verbatim** into the spec's "Decisions preamble" section each round. If Codex's preamble in `06-spec-rN.clean.md` does not byte-match `03-decisions.md`, that is itself a `re-review-needed` finding for the Opus reviewer.

### Stage-5 verdict matrix (round × verdict)

Both rounds use identical vocabulary. The matrix is exhaustive — every cell is specified.

| Verdict | Round 1 behavior | Round 2 behavior |
|---|---|---|
| `ready-to-execute` | Commit canonical spec; proceed to Stage 6. | Same. |
| `fix-and-proceed` | Codex applies the listed fixes via `codex exec resume --last`; output is `06-spec-r1-fix.clean.md`; **no re-review**. Commit canonical spec; proceed. | Codex applies fixes via resume; output is `08-spec-r2-fix.clean.md`; no re-review. Commit; proceed. |
| `re-review-needed` | Build round-2 prompt; Codex writes round 2 via resume; Opus re-reviews. | **Escalate.** No round 3. |
| `escalate` | Escalate immediately. No fix attempt. | Escalate. |
| `WRONG-DIRECTION` (Codex spec-write first-line) | Escalate. Three options to user: re-brainstorm / override-and-proceed / abort. | Same. (Rare in round 2 — if Codex still believes wrong-direction after a round 1 review, Codex returns it again.) |

**Who edits what** — bright-line rule:
- Codex writes and edits the spec at every round and every fix dispatch.
- Opus reviewer flags only — never edits, never proposes specific text.
- Orchestrator dispatches; never writes spec content; never silently overrides a verdict; only escalates when the matrix says to.

### A1 — Intake framing review

**Trigger:** Once, after Stage 0 setup, before any clarifying question.
**Input:** Raw user request (verbatim) + project-context summary (recent commits, files in scope, CLAUDE.md highlights — same context Claude is about to use to draft questions).
**Output template:** ≤80 words, exactly one of:
- `FRAMING-OK: <one line confirming the read>`
- `REFRAME: <tighter framing>`
- `MISSING-INPUT: <constraint or input the brainstorm should pin down first>`

**Behavior:**
- `FRAMING-OK` → log to transcript, proceed silently.
- `REFRAME` → present verbatim to user before the first question; user accepts / rejects / refines.
- `MISSING-INPUT` → fold the missing constraint into the first clarifying question.

**Artifact:** `01-intake-verdict.md`

### A2 — Independent approach proposals

**Trigger:** Once, after A3 returns `COVERAGE-OK`.
**Input to Codex dispatch:** Full `02-transcript.md` + `03-decisions.md` + framed problem statement. **Does NOT include Claude's draft proposals** — strong independence, distinguishing this from per-recommendation 2nd opinion which does include the draft.
**Output template:** 2–3 approach summaries (1–2 sentences each) + a top pick + reasoning (≤60 words on the pick). ≤500 words total.

**Merge mechanics — strict:**

The merge is mechanical, performed by Claude. The de-dup rule is deliberately conservative:

- Two proposals merge into one entry **only when both** of these are true:
  1. The one-sentence summary of each is identical (modulo wording).
  2. The architectural primitive named (e.g., "use a worker queue", "do it inline") is identical.
- When in doubt, **do NOT merge**. List both, with their respective attributions. False merges hide a genuine disagreement; redundant entries do not.

Attribution tags (exactly one per entry):
- `[both]` — proposed by both models, same gist *and* same primitive.
- `[Claude]` — proposed only by Claude.
- `[Codex]` — proposed only by real Codex (i.e., Codex CLI was reachable and `codex exec` returned successfully).
- `[Codex(fallback)]` — Codex CLI was unavailable or the dispatch failed; a fresh Claude subagent (no main-conversation context) played Codex's role for this specific dispatch. Distinguishes fallback output from genuine cross-vendor diversity.

Side-by-side presentation to user:

```
## Approaches

1. [<tag>] <one-line gist>
   <2-3 sentence elaboration>

2. [<tag>] <one-line gist>
   <2-3 sentence elaboration>

…

## Recommendations

[Claude]: pick #<n> — <≤60 word reasoning>
[Codex|Codex(fallback)]: pick #<n> — <≤60 word reasoning>
```

If both picks land on the same number, prepend a single line `Both recommend #<n>.` above the per-model reasoning. The reasoning is still shown separately (the *agreement* is signal but the *reasoning* may differ in interesting ways).

After user picks, append to `03-decisions.md`:

```
## Approach selected
- Picked: #<n> ([attribution])
- Picked-over: <list of #s rejected, including the recommended-but-rejected by either model>
- User's reasoning: <verbatim if provided, otherwise blank>
```

The **`Picked-over:` line is required** when the user picks against either model's recommendation. This makes the deliberate-rejection visible to the spec-writer + reviewer downstream.

**Edge cases:**
- Codex returns < 2 approaches → present in Claude's merge with `[Codex returned only N approach(es) — possibly under-explored.]` as a one-line note. Don't silently treat sparse output as agreement.
- User wants an approach neither model proposed → record as `Picked: user-proposed — <description>` in `03-decisions.md`.

**Artifact:** `05-approaches.md` (both raw lists + merged union + both picks + user's pick).

### A3 — Clarifying-question angle audit

**Trigger:** Event-based — fires once, just before A2, at the moment Claude believes the dialogue has covered enough ground. The orchestrator MAY re-fire mid-dialogue if it suspects drift; the *required* fire is right before A2.
**Input:** Full transcript + decisions log.
**Output template:** ≤120 words, exactly one of:
- `COVERAGE-OK: <one line>`
- `GAP: <up to 3 missed angles, each with the question that should be asked>`

**Behavior:**
- `COVERAGE-OK` → proceed to A2.
- `GAP` → ask the missed-angle questions before A2; append answers to transcript and decisions; loop A3 until `COVERAGE-OK` or user explicitly says "enough, propose approaches" (in which case the user-override is logged in `03-decisions.md`).

**Artifact:** `04-angle-audits.md` (append-only — one entry per A3 fire, with verdict and any new questions raised).

### Per-recommendation 2nd opinion

**Unchanged from current skill.** Same `AGREE / DISAGREE / ANGLE-MISSED` template, same dispatch shape, same ≤60-word cap. Triggered whenever the orchestrator is about to ask a multi-choice question (`A/B/C`, `pick X or Y`) OR carry a recommendation. Both inside Stage 2 dialogue and inside Stage 4 design convergence.

**Fallback:** Same fallback rule as A1/A2/A3 — Codex unavailable at entry → Claude subagent for all dispatches; runtime failure → Claude subagent for that one dispatch only. Attribution is shown to the user at recommendation moments only when fallback fires (so disagreement-from-genuine-diversity remains distinguishable from disagreement-from-fallback).

### Stage 5 — spec write + Opus review

**Codex spec-write dispatch:**

```bash
# Round 1 (file-id = 06):
codex exec \
  --sandbox read-only \
  --skip-git-repo-check \
  -C /tmp/claudex/<run-id> \
  - < /tmp/claudex/<run-id>/spec-prompt-r1.md \
  > /tmp/claudex/<run-id>/06-spec-r1.md \
  2>&1

# Round 2 (file-id = 08, resume codex session for context continuity):
( cd /tmp/claudex/<run-id> && \
  codex exec resume --last \
    - < /tmp/claudex/<run-id>/spec-prompt-r2.md \
    > /tmp/claudex/<run-id>/08-spec-r2.md \
    2>&1 )
```

Note: `codex exec resume` does not accept `-C/--cd` or `--sandbox` flags (only `codex exec` does), so cd into the run dir in a subshell, mirroring the build skill's plan-stage convention.

The prompt is built from `skills/brainstorming/spec-codex-prompt.md` with these slots filled:

- `{{TRANSCRIPT}}` — full `02-transcript.md`
- `{{DECISIONS}}` — full frozen `03-decisions.md` (copied verbatim into the spec preamble)
- `{{APPROACHES}}` — full `05-approaches.md`
- `{{DESIGN}}` — the agreed design as presented to and approved by user across Stage 4 sections

**First-line convention.** Codex's prompt instructs: if the design is fundamentally wrong, output `WRONG-DIRECTION: <reason>` as the entire first line and stop; otherwise the entire output is the spec body.

**Spec body structure** (Codex always produces this layout):

```
# <topic> — design

## Decisions preamble
<verbatim copy of 03-decisions.md, dated>

## Problem
## Approach (selected)
## Architecture
## Components
## Data flow
## Error handling
## Testing
## Out of scope
```

Cleanup of codex wrapper noise → `06-spec-rN.clean.md`. The clean file is also written to `docs/claudex/specs/<YYYY-MM-DD>-<topic>.md`, **overwritten** each round. **Not committed to git** until the loop converges to `ready-to-execute` or `fix-and-proceed` (final).

**Opus subagent reviewer dispatch:**

`Agent` tool with `subagent_type: "general-purpose"`, `model: "opus"`, `description: "Review spec for DRIFT and QUALITY"`. Prompt loaded from `skills/brainstorming/spec-reviewer-prompt.md` (this is the new file that **replaces** the orphan `spec-document-reviewer-prompt.md`; same purpose, content aligned with build's `reviewer-prompt.md` pattern). Slots filled: `{{TRANSCRIPT}} {{DECISIONS}} {{APPROACHES}} {{SPEC}}`.

**Verdict structure** (parity with build's reviewer):

```
## DRIFT
<empty if no drift; otherwise bulleted list of places the spec diverges from
 transcript / decisions / picked approach. Include "Decisions preamble does not
 byte-match 03-decisions.md" as a DRIFT finding if applicable.>

## QUALITY
- Minimal: <PASS / FLAG: ...>
- Consistent: <PASS / FLAG: ...>
- Verifiable: <PASS / FLAG: ...>

## Verdict
<one of: ready-to-execute | fix-and-proceed | re-review-needed | escalate>
<one-sentence justification>
```

**The loop** (canonical):

```python
artifact = codex_write_spec(round=1)
if artifact.first_line.starts_with("WRONG-DIRECTION:"):
    escalate(reasons=artifact.first_line)               # hard stop

review = opus_review(artifact, round=1)

match review.verdict:
    case "ready-to-execute":
        commit_canonical_spec()
        return                                          # → Stage 6
    case "fix-and-proceed":
        codex_apply_fix(round="fix1", feedback=review,
                        resume=True)                    # NO re-review
        commit_canonical_spec()
        return
    case "escalate":
        escalate(round=1, review=review)                # hard stop
    case "re-review-needed":
        pass                                            # → round 2

# ROUND 2 — final review allowed
artifact = codex_write_spec(round=2, feedback=review, resume=True)
if artifact.first_line.starts_with("WRONG-DIRECTION:"):
    escalate(reasons=artifact.first_line)               # hard stop
review = opus_review(artifact, round=2)

match review.verdict:
    case "ready-to-execute":
        commit_canonical_spec()
        return
    case "fix-and-proceed":
        codex_apply_fix(round="fix2", feedback=review,
                        resume=True)
        commit_canonical_spec()
        return
    case "re-review-needed" | "escalate":
        escalate(round=2, review=review)                # NO round 3
```

`codex exec resume --last` is used for fix dispatches and round-2 dispatches so Codex retains spec-writing context. Round 1 → round 2 boundary stays in the same codex session. Crossing to build (Stage 6 → plan) is a fresh `codex exec` (clean handoff between brainstorm and build, same convention as build uses between plan and impl).

### Stage 6 — handoff to build

```
[brainstorming] Spec converged: docs/claudex/specs/<date>-<topic>.md
                Run-id: <run-id>
                Audit:  /tmp/claudex/<run-id>/

How should I run the build?
  1) Inline (this session — dies if SSH drops)
  2) Detached tmux (survives SSH drops; tmux attach -t <name>)
```

**tmux missing** → announce and run inline (existing message preserved).
**Inline** → export `RUN_ID=<run-id>`, then invoke build skill. Build's existing `RUN_ID="${RUN_ID:-...}"` line picks it up.
**Detached** → `bash scripts/start-tmux-build.sh "<spec-path>" "<run-id>"`. Launcher updated to accept the optional 2nd positional arg; sets `RUN_ID` inside the tmux session before invoking `/claudex:build`. If 2nd arg absent (direct invocation without brainstorm), launcher behavior is unchanged — backward compatible.

User does NOT review the spec by default (existing rule, preserved). If user explicitly asks to review, honor it — show the spec path, pause until they say go.

The optional `~/.claude/claudex/post-build-hook.md` extension stays. `RUN_ID` is exported in the in-tmux environment so the hook can reference it.

## Components

### Skill directory after migration

```
skills/brainstorming/
  SKILL.md                          rewritten — no <!-- CLAUDEX:BEGIN --> markers
  intake-prompt.md                  A1 prompt template (NEW)
  approaches-codex-prompt.md        A2 prompt template (NEW)
  angle-audit-prompt.md             A3 prompt template (NEW)
  second-opinion-prompt.md          per-recommendation 2nd opinion template (NEW)
  spec-codex-prompt.md              Stage 5 — Codex spec-write prompt (NEW)
  spec-reviewer-prompt.md           Stage 5 — Opus reviewer prompt (NEW; replaces orphan)
  visual-companion.md               unchanged
  scripts/
    start-tmux-build.sh             updated — accepts optional run-id 2nd arg
    frame-template.html             unchanged
    helper.js                       unchanged
    server.cjs                      unchanged
    start-server.sh                 unchanged
    stop-server.sh                  unchanged
```

**File deleted:** `skills/brainstorming/spec-document-reviewer-prompt.md` (orphan; replaced).

### SKILL.md outline

```
1. Header / when-this-applies
2. Codex availability probe
3. Role split table (orchestrator / Codex / Opus reviewer / user)
4. Pipeline overview — 6-stage diagram
5. Stage 0: Setup
6. Stage 1: Intake framing (A1)
7. Stage 2: Dialogue (one-question-at-a-time + per-recommendation 2nd opinion)
8. Stage 3: Approaches (A3 first, then A2 + mechanical merge)
9. Stage 4: Design convergence
10. Stage 5: Spec write + Opus review (the loop, verdict matrix)
11. Stage 6: Handoff to build
12. Audit trail layout
13. Failure modes (codex missing, dispatch failure, repeated escalations)
14. Visual companion (link to visual-companion.md)
15. Key principles (one-question-at-a-time, YAGNI, etc.)
```

Target length: comparable to today's 293 lines, possibly shorter once the patches and duplicated heredocs are removed. The skill *gains* functionality but *loses* the structural overhead.

### Preserved verbatim from current SKILL.md

These are tested and tuned; per project's CLAUDE.md they are not to be reworded:
- The `<HARD-GATE>` block ("do NOT invoke any implementation skill ... until design is approved").
- The "This is too simple to need a design" anti-pattern guard.
- The "your human partner" terminology (if any appears in brainstorming SKILL.md).
- The visual-companion section's offer-message text and per-question-decision rule.
- The one-question-at-a-time and YAGNI-ruthlessly principles.

### Audit trail layout end-to-end

```
/tmp/claudex/<run-id>/
  # Brainstorm owns 00–09; 00-spec.md is the canonical-input slot build writes into
  00-spec.md                  build's copy of canonical spec (build writes this at handoff)
  01-intake-verdict.md        A1 verdict
  02-transcript.md            dialogue log (Q+A + per-recommendation Codex 2nd opinion)
  03-decisions.md             append-only during dialogue; frozen at Stage 5 entry
  04-angle-audits.md          append-only A3 audit history
  05-approaches.md            A2 — Claude + Codex raw lists, merged union, user's pick
  06-spec-r1.md               codex round-1 spec — raw
  06-spec-r1.clean.md         cleaned (also written to docs/claudex/specs/...)
  06-spec-r1-fix.clean.md     present iff round-1 verdict was fix-and-proceed
  07-spec-r1-review.md        Opus review round 1
  08-spec-r2.md               codex round-2 spec — raw (only if r2 triggered)
  08-spec-r2.clean.md
  08-spec-r2-fix.clean.md     present iff round-2 verdict was fix-and-proceed
  09-spec-r2-review.md
  # Build owns 10–29 (existing layout — unchanged)
  10-plan-prompt.md
  11-plan-r1.md  ...  16-plan-r2-review.md
  20-impl-prompt.md
  21-impl-r1.{log,diff,stat}  ...  25-impl-r2-review.md
  99-final-summary.md
```

### Bookkeeping discipline

The orchestrator MUST write to audit files as it goes, not at the end. Append-as-you-go means a session crash mid-dialogue does not lose the brainstorm, and the user can `cat` the run dir mid-session to see what's been captured.

| When | What is written |
|------|-----------------|
| Stage 0 setup | `mkdir -p`; record run-id |
| A1 returns | write `01-intake-verdict.md` |
| Each Q + user reply | append to `02-transcript.md` |
| Each per-recommendation Codex verdict | append to `02-transcript.md` (inline with the question) |
| User confirms a decision | append to `03-decisions.md` |
| A3 fires | append entry to `04-angle-audits.md` |
| A2 completes | write `05-approaches.md` |
| Stage 5 entry | freeze `03-decisions.md` (no further appends; subsequent rounds copy verbatim into the spec preamble) |
| Spec round n | write `06/08-spec-rN.md` + `.clean.md` + canonical `docs/claudex/specs/...` |
| Spec fix dispatch | write `06/08-spec-rN-fix.clean.md` + canonical `docs/claudex/specs/...` (overwritten) |
| Review returns | write `07/09-spec-rN-review.md` |
| Loop converges | git commit canonical spec; export `RUN_ID`; trigger handoff |

## Data flow

End-to-end data flow for a single brainstorm:

1. User invokes `/claudex:brainstorming <ask>`. Main Claude is the orchestrator.
2. Stage 0 → run-id created; codex availability probed once.
3. Stage 1 → Codex sees `[user request, project context]`; returns A1 verdict.
4. Stage 2 → orchestrator drafts each clarifying question; if it's a multi-choice or recommendation, dispatches per-recommendation 2nd opinion (Codex sees `[transcript-so-far, drafted question, Claude's recommendation]`); user reply appended.
5. Stage 3 → A3 fires (Codex sees `[transcript, decisions]`); on `GAP`, more questions; loop until `COVERAGE-OK`. Then A2 fires: Claude proposes internally, Codex's dispatch is given `[transcript, decisions, framed problem]` — **NOT** Claude's draft — and returns its proposals; mechanical merge; user picks.
6. Stage 4 → orchestrator presents design sections; per-recommendation 2nd opinion fires inside on sub-choices; user approves each.
7. Stage 5 → freeze `03-decisions.md`; Codex spec-write sees `[transcript, decisions, approaches, design]`; Opus reviewer subagent sees `[transcript, decisions, approaches, spec]`; loop per the verdict matrix.
8. Stage 6 → on convergence, commit canonical spec; export `RUN_ID`; user picks inline or detached; build inherits.

## Error handling

### Failure modes

| Failure | Detection | Behavior |
|---|---|---|
| Codex CLI not installed at session start | `command -v codex` returns non-zero at Stage 0 probe | One-time message: *"Codex CLI not detected — a Claude subagent will play Codex's role for this brainstorm. Dual-vendor diversity is degraded; independent-context review is preserved. Install codex (`npm install -g @openai/codex`) for the full dual-model behavior."* All Codex touchpoints (A1/A2/A3/per-recommendation/spec-write) dispatch via Agent tool with `subagent_type: "general-purpose"` and `model: "sonnet"`. Subagent's output is treated as Codex's reply. Attribution at A2 becomes `[Codex(fallback)]`; at recommendation moments, the verdict prefix becomes `[Codex(fallback) 2nd opinion]:` so user can distinguish. |
| Single Codex dispatch fails at runtime (auth, network) | Non-zero exit + non-empty stderr from `codex exec` | Note to user in one short line (`Codex dispatch failed (network) — Claude subagent for this call.`); fall back to Claude-subagent for that one call only; resume real Codex for subsequent calls. Do not block the brainstorm. |
| **Fallback isolation invariant** | Per-call check | A Claude subagent playing Codex's role for A2 MUST be dispatched with **only** the input slots Codex would have seen (`[transcript, decisions, framed problem]`) — not the main-conversation context. The Agent tool dispatch is a fresh subagent, so this is the default; the spec-codex-prompt.md and approaches-codex-prompt.md MUST be self-contained (no references to "look at the conversation above"). The same constraint applies to all fallback dispatches; A2's is the strictest because of the strong-independence rule. |
| Round-2 review is `re-review-needed` or `escalate` | Verdict matrix | Escalate to user with three options: continue iterating (override skill rule, NOT recommended) / abort / revise scope. No round 3. |
| Codex `WRONG-DIRECTION` on spec-write | First line of codex output | Escalate with three options: re-brainstorm from scratch / override Codex and proceed (manual spec edit by user) / abort. No silent override by orchestrator. |
| Two consecutive Codex invocations fail at the same site | Two failed runtime calls in a row | Escalate; do not retry a third time. |

### Escalation format (in main session)

```
[brainstorming] Escalating at <stage>, round <N>.

Issue: <≤2 sentences>

Options:
1. <continue iterating with X>
2. <override and proceed>
3. <revise scope to Y>
4. <abort>

Audit trail: /tmp/claudex/<run-id>/
```

Wait for user response. **Silence is not approval.**

## Testing

Skills shape agent behavior, so testing is behavior verification, not code coverage. Three layers:

### Layer 1 — smoke checks (deterministic, fast)

- `bash -n scripts/start-tmux-build.sh` (syntax) + dry-run with `RUN_ID` arg present + absent.
- `find skills/brainstorming -name '*.md' -print` shows the new prompt files; `spec-document-reviewer-prompt.md` is gone.
- `grep -L '{{TRANSCRIPT}}\|{{DECISIONS}}\|{{SPEC}}' skills/brainstorming/spec-reviewer-prompt.md` returns nothing missing.
- `grep -r 'CLAUDEX:BEGIN' skills/brainstorming/` returns no matches.
- Direct build invocation without brainstorm: `/claudex:build <known-good-spec>` still creates its own run-id and runs to completion. Backward compat sanity.

### Layer 2 — end-to-end manual run

User picks a small actual feature and runs `/claudex:brainstorming <ask>`. Verify in order:

- Stage 0: `RUN_ID` set, `/tmp/claudex/<run-id>/` exists, codex probe runs once.
- Stage 1: `01-intake-verdict.md` written; on `REFRAME`, user sees verdict before first question.
- Stage 2: every Q + user reply lands in `02-transcript.md`; per-recommendation 2nd opinion appears alongside each multi-choice question.
- Stage 3: A3 fires before A2; on `GAP`, missed-angle questions are asked; A2 produces `05-approaches.md` with `[Claude]/[Codex]/[both]` attribution and side-by-side picks.
- Stage 4: design sections presented one at a time; user approves each.
- Stage 5: Codex writes spec → Opus subagent returns canonical-structured verdict (DRIFT / QUALITY / Verdict). On `ready-to-execute`, no round 2.
- Stage 5 boundary: `03-decisions.md` is byte-stable across Stage 4 → 5; Codex's preamble in `06-spec-r1.clean.md` byte-matches `03-decisions.md`.
- Stage 6: tmux probe; user picks inline or detached; on detached, `tmux attach` confirms `RUN_ID=<run-id>` in env and that build's plan stage starts in the same `/tmp/claudex/<run-id>/`.
- Audit: `99-final-summary.md` references both brainstorm and build artifacts; full file layout from this spec is present.

Run once for inline mode and once for detached mode.

### Layer 3 — adversarial subagent test (eval evidence)

Use upstream `superpowers:writing-skills` testing pattern: dispatch a fresh subagent (no conversation history) with the new SKILL.md as the only context and a representative user prompt. Assert each behavior:

| Expected behavior | Why it matters |
|---|---|
| Subagent runs `command -v codex` once before any dispatch | Codex availability protocol intact |
| Subagent dispatches A1 before any clarifying question | Intake-framing-first ordering enforced |
| When user picks an approach against either model's recommendation, `03-decisions.md` shows `Picked-over: ...` line | Disagreement-capture preserved |
| When Codex returns `WRONG-DIRECTION` from spec-write, subagent escalates with the three options — does NOT proceed silently | Hard-gate against silent override |
| On `re-review-needed` round-2 verdict, subagent escalates — does NOT attempt a round 3 | Round-cap enforced |
| Without a "go" signal between Stage 4 approval and Stage 5 spec write, subagent does NOT pause for a separate "may I proceed" gate | The user-review-gate-between-stages was deliberately removed; rewrite preserves that |
| Codex's preamble in spec rounds byte-matches `03-decisions.md`; if it does not, the Opus reviewer flags as DRIFT | Decisions-as-preamble integrity |
| At Stage 3, Codex's dispatch transcript shows it did NOT receive Claude's draft proposals | A2 strong-independence preserved |

Run on at least 3 fresh sessions with varied prompts (small feature, vague request, explicit user-redirect mid-dialogue). Failure on any assertion → fix the SKILL.md prose and re-run the affected test. **≥ 2 of 3 sessions must fully pass; the third may have at most one near-miss with noted rationale.**

### Pass criteria

All three layers green on at least one full pass before merging. Layer 3 ≥ 2 of 3 sessions full pass. Capture the per-session pass/fail table for the PR.

### What we are NOT testing

- That Codex makes "good" recommendations (model-quality property, not skill property).
- That the Opus reviewer never has a false positive on DRIFT (same).
- That build's plan and impl stages still pass review (covered by build's own tests; this rewrite only changes brainstorm and the run-id chain).

## Out of scope

- **Modifying the build skill's reviewer prompt.** Build's plan/impl reviewer DRIFT-checks against the spec; decisions are inside the spec via the preamble; no prompt change needed.
- **Changing `/claudex:build`'s direct-invocation behavior.** Backward compatibility for `/claudex:build <spec>` without a prior brainstorm is preserved by `RUN_ID="${RUN_ID:-...}"`.
- **Cost/latency tuning** (axis D from brainstorm). Skipping Codex on trivial questions, batching second-opinion dispatches, transcript caching — none of these in scope. Revisit only if A1/A2/A3 add unacceptable latency in measurement.
- **Brainstorm-as-mini-build merge** (axis Z). Merging `/claudex:brainstorming` into `/claudex:build` was considered and rejected for this v0.2.x increment.
- **Time-based A3 trigger.** Only event-based (just before A2). Time-based "every N questions" was considered and rejected as too noisy. The orchestrator may manually re-fire A3 mid-dialogue if drift is suspected; not a required trigger.
- **Reviewer proposing specific edits.** Opus subagent flags only — never edits, never proposes specific text. Preserves the role split.
- **Round 3.** Round-2 final. Beyond that, escalate.
