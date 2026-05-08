# think-skill — design

## Decisions preamble

# 03-decisions

(empty — appended during dialogue)

## D1 — Refactor framing

**Decision:** Refactor SKILL.md toward "zero prose for load-bearing control flow" — every dispatch, verdict parse, file write, and gate transition is a script call. Carve-out: user-facing dialogue prose (questions, design narrative, gate-message wording) stays in SKILL.md because mechanizing it would make the brainstorm robotic.

**Rationale:** Push the dispatch-primitive pattern from commit 69aee67 to its limit. Prose invites improvisation; script outputs constrain it. But the actual words Claude says to the user are the brainstorm.

**Source:** Codex A1 reframing + Claude recommendation, user confirmed.

## D2 — Control substrate of SKILL.md

**Decision:** Hybrid (option C). Each Stage in SKILL.md is a Markdown section with a fixed three-part skeleton:
1. `## Inputs` — bullet list of files/vars the dispatch reads.
2. `## Dispatch` — one fenced bash block with script call(s).
3. `## Verdict → next step` — table mapping each script output to the next action (next stage, loop, escalate, halt-for-user).

Prose paragraphs explaining "why" move to a sibling `RATIONALE.md` (maintainer-only, not loaded by the agent at runtime).

**Invariant (Codex add):** Every script invoked by SKILL.md must declare a closed output schema — allowed verdict tokens, required fields, exit-code map, and next-step contract — at the top of the script and (mirrored) in the Stage's `## Verdict → next step` table.

**Rationale:** Strict per-stage shape makes any prose-paragraph leak visually obvious in PR review; keeps load-bearing SKILL.md small/homogeneous; future stages slot into the same skeleton.

**Source:** Claude recommendation, Codex AGREE + invariant addition, user confirmed.

## D3 — Script-vs-prose boundary

**Decision:** Script-owned: any write to an audit file (transcript, decisions, intake-verdict, approaches, spec, summary). Agent-controlled (Write tool, no script needed): scratch files (`.q.md`, `.r.md`, `.design.md`) because the next dispatch script validates them. Environment probes (`codex`, `tmux`) folded into one `scripts/probe.sh <name>` so the only inline bash form in SKILL.md is `bash scripts/<name>.sh`.

**Why two-part control:** A script alone does not stop the agent from skipping it. Real control = (script defines the action) + (clear rule in SKILL.md saying "the only allowed action here is bash scripts/<name>.sh"). Both halves are needed.

**Rationale:** Audit files are where a wrong byte propagates downstream into every dispatch's prompt. Protecting those files with one script-defined writer and a short matching rule gives real protection. Scratch files are validated by the receiving dispatch script, so script ownership buys nothing extra for them.

**Source:** Claude recommendation, Codex AGREE, user confirmed.

## D4 — Where safety rules live

**Decision:** Each existing safety rule in today's SKILL.md must be classified at design time as exactly one of:
- `script-enforced` — promoted to a script that mechanically refuses the bad action; the rule does not appear in SKILL.md prose at all.
- `inline-runtime-prose` — kept as one short prose sentence at the top of the affected Stage; explanation goes to RATIONALE.md, not SKILL.md.
- `deleted-with-rationale` — explicitly removed; reason recorded in RATIONALE.md.

The classified inventory is required output of Stage 4 design and is part of the spec.

**Why this matters:** A safety rule moved to RATIONALE.md alone has zero force (the agent does not read RATIONALE.md at runtime), so past failures return. Mechanical enforcement (script) is the strongest. Inline one-liner is the fallback for judgment-based rules. Deletion is allowed but must be deliberate.

**Source:** Claude recommendation, Codex AGREE + inventory invariant, user confirmed.

## D5 — Skill name and path (overrides D4 delivery)

**Decision:** The rewrite is delivered as a **new** skill at `skills/think/SKILL.md` in the claudex plugin, not as an in-place rewrite of `skills/brainstorming/SKILL.md`. Slash command becomes `/claudex:think` (shorter than `/claudex:brainstorming`).

**Independence requirement:** `think` does not inherit superpowers lineage — its description, terminology, and body content do not refer to the superpowers plugin, the upstream `brainstorming` skill, the `writing-plans` chain, or any other superpowers naming. Where today's `claudex:brainstorming` opens by citing superpowers, `think` opens fresh.

**Open question (Q5):** What happens to the existing `skills/brainstorming/` skill, and what does "independent" specifically include (description-only? hard guarantee that `think` works without superpowers installed?). Settled in next turn.

**Source:** User redirection.

## D6 — Old skill fate + meaning of independence

**Decision Part 1:** `skills/brainstorming/` becomes a one-line stub for 2 weeks pointing users at `/claudex:think`, then a follow-up cleanup PR removes it. The stub PR window: 2026-05-01 + 2 weeks = removal target 2026-05-15.

**Decision Part 2:** Independence is description + hard runtime guarantee. (a) `think`'s description, body, and rationale do not mention `superpowers`, upstream `brainstorming`, `writing-plans`, `executing-plans`, or any other superpowers naming. (b) Stage 6 handoff invokes only `claudex:build`. No fallback to `superpowers:writing-plans` or any other superpowers skill. If `claudex:build` is missing, fail loudly. (c) Cleaning the rest of the plugin's `superpowers` references (CLAUDE.md, README, other scripts) is out of scope and deferred to a follow-up PR.

**Source:** Claude recommendation, Codex AGREE, user confirmed.

## D7 — Stage structure

**Decision:** `think` keeps the 6-stage flow (Setup, Intake, Dialogue, Approaches, Design, Spec, Handoff — the same six as today's `claudex:brainstorming`) but tightens two specific places:

1. **A1 self-skip.** A new script `scripts/intake-skip-check.sh` runs before A1 and returns `SKIP` or `RUN` based on input shape (word count, paragraph count, multi-subsystem signals). If `SKIP`, A1 is not dispatched. The skip decision and reason are written to `01-intake-verdict.md` so the audit shows skip was deliberate.
2. **A3 one-shot.** A3 runs at most once per brainstorm. If A3 returns `GAP`, the orchestrator surfaces the gap once and the user decides whether to address it; A3 is not re-dispatched. This is enforced by `scripts/dispatch-codex-angle-audit.sh` via a state file (e.g., `04-angle-audit.md` exists ⇒ no second dispatch) — not by agent prose.
3. Stage 5 max 2 review rounds (unchanged from today).

The thresholds, signals, and one-shot enforcement live in the scripts, not in SKILL.md prose — "tighten" cannot become agent discretion that silently bypasses rigor.

**Source:** Claude recommendation, Codex AGREE + script-owned-verdicts invariant, user confirmed.

## D8 — Visual companion (revised from Q7)

**Decision:** `think` does not include the browser-based visual companion. The companion files (`visual-companion.md`, `server.cjs`, `helper.js`, `frame-template.html`, `start-server.sh`, `stop-server.sh`) are not ported. Instead, SKILL.md Stage 2 includes one short instruction encouraging the agent to embed **inline** visualizations directly in the chat:

- Mermaid diagrams (```` ```mermaid ... ``` ````) for flows, architectures, dependencies.
- Markdown tables for comparisons or option matrices.

**Why:** The user reports never opening the browser URL the companion serves. The valuable part is the visual content (diagrams, tables); the browser delivery mechanism adds complexity without value. Inline visualization is rendered by every Markdown-aware client (CC terminal, web, IDE extensions) without spinning up a Node.js server.

**Effect on D6 stub:** The deprecated `claudex:brainstorming` stub returns to the simple one-line form (no need to soften to a deprecation banner per C2). The browser companion is removed from the codebase entirely when the stub is removed at 2026-05-15.

**Source:** User redirection on Q7.

## D9 — Codex CLI contract and failure behavior

**Decision (option A — fail loud everywhere):** `think` halts on any Codex-related failure. Specifically:

- **Stage 0 probe failure (codex CLI missing on PATH):** halt with install instructions (`npm install -g @openai/codex` or equivalent). The brainstorm cannot start.
- **Runtime dispatch failure (any `codex exec` returns non-zero):** halt with the codex stderr tail attached. The user can investigate and re-run.
- **Unparsable verdict (dispatch script exit 5 — schema violation):** halt loudly with the raw output for inspection.

**No Claude subagent fallback for any Codex role in `think`.** The `[Codex(fallback)]` pattern from today's `claudex:brainstorming` is removed entirely.

**Why:** Brainstorm is interactive — the user is at the computer and can address halts by retrying, installing missing tools, or fixing network. Robustness against transient failures is needed for the unattended implementation phase (`claudex:build`), not for interactive brainstorm.

**Effect on D6 part (b):** D6 already required Stage 6 to fail loudly when `claudex:build` is missing. D9 extends the same fail-loud principle to Codex itself. Both are bright-line.

**Picked-over:** Claude's recommendation C (hybrid) and Codex's AGREE with C.

**Source:** User redirection.

## D10 — Stage 6 handoff contract

**Decision (option A — match today's contract exactly):** `think` Stage 6 writes the canonical spec to `/tmp/claudex/${RUN_ID}/00-spec.md` and exports `RUN_ID` to the environment before invoking `claudex:build`. The on-disk shape and env-var semantics match what today's `claudex:brainstorming` produces. No manifest file, no schema-version field, no marker file. `claudex:build` is not modified.

**If a future need arises** (e.g., build invoked from non-brainstorm sources needing to verify gates), an explicit `00-handoff.json` manifest is the right shape — but that is its own PR with its own changes to `claudex:build`.

**Source:** Claude recommendation, Codex AGREE, user confirmed.

## D11 — Plugin registration of `think`

**Decision:** No plugin metadata changes are required for `/claudex:think` to work — Claude Code auto-discovers skills from `skills/<name>/SKILL.md` using the `name:` frontmatter.

**Additional file added:** `commands/think.md` mirroring the existing `commands/build.md` pattern, so the user can invoke `/think` (shorter, no namespace) in addition to `/claudex:think`. This addresses the user's stated "brainstorming is too long" complaint at both levels.

Files in this PR that touch plugin registration:
- `skills/think/SKILL.md` (new) — auto-registers `/claudex:think`.
- `commands/think.md` (new) — adds `/think` alias.
- `skills/brainstorming/SKILL.md` (modified) — becomes one-line stub redirecting to `/claudex:think`.
- `.claude-plugin/plugin.json` (unchanged).
- `.claude-plugin/marketplace.json` (will be checked; likely unchanged but we will verify in spec).

**Source:** Investigation, no user input needed (low-risk research finding).

## D12 — Merge-blocking verification bar for `think`

**Decision:** The PR that introduces `skills/think/` cannot merge until **all** of the following are produced and attached:

1. **One real end-to-end `/think` run** on a non-trivial brainstorm subject of any kind. The full audit directory at `/tmp/claudex/<run-id>/` is captured (or summarized in the PR description) with all expected artifacts present (00-setup, 01-intake-verdict, 02-transcript, 03-decisions, 04-angle-audit, 05-approaches, 06-spec-r1.clean, 07-spec-r1-review, 00-spec, 99-final-summary).
2. **Coverage check:** the run touches every new script (intake-skip-check, dispatch-codex-angle-audit, record-turn, record-decision, freeze-decisions, probe, gate-design-approval, gate-user-build-choice — final list per Stage 4 design) at least once. A sentence in the PR description maps each new script to the run's audit step where it fired.
3. **Verdict-token coverage:** every closed-schema verdict token defined by any new dispatch script must appear at least once across the audit (or be explicitly noted as "rare-path verdict not exercised in this run; covered by script-level schema unit test instead").
4. **Gate-transition check:** the audit shows each gate transition at least once (intake skip OR run, A3 clear OR gap, design approved, opus-review verdict, user build choice 1 or 2).
5. **Stage 6 hard-stop demonstration:** the user's `1` or `2` reply is shown in the transcript before `claudex:build` is invoked. (No silent auto-launch.)

If any of these are missing, the PR is not ready.

**Rationale:** Restates the Q4/D4 merge safeguard that was tied to the in-place rewrite plan. The safeguard belongs to the substance of the change, not to the delivery shape, and applies equally to the new-skill plan.

**Source:** Q4/D5 carried forward; A3 surfaced that it had been dropped after D6 redirection. Auto-recorded as low-risk consistency restoration.

## D13 — Internal reuse of `skills/brainstorming/` in `think`

**Decision:** `think` copies verbatim from `skills/brainstorming/` the components that are already claudex-native and have no internal superpowers references:

- Prompt templates: `intake-prompt.md`, `second-opinion-prompt.md`, `angle-audit-prompt.md`, `approaches-codex-prompt.md`, `spec-codex-prompt.md`, `spec-reviewer-prompt.md`.
- Dispatch scripts: `scripts/dispatch-codex-2nd-opinion.sh`, `scripts/dispatch-codex-spec-write.sh`, `scripts/build-opus-spec-review-prompt.sh`.
- Launcher: `scripts/start-tmux-build.sh`.

**Verification step (required at PR time):** `grep -ri 'superpowers\|writing-plans\|executing-plans' skills/think/` returns zero matches. The grep result is part of the PR description.

**Net new in `think`** (not copied — written fresh):
- `SKILL.md` (per-stage skeleton, 6 stages).
- `RATIONALE.md` (maintainer-only "why" content).
- `scripts/intake-skip-check.sh` (D7).
- `scripts/dispatch-codex-angle-audit.sh` (D7 — wraps angle-audit with one-shot enforcement).
- `scripts/record-turn.sh`, `scripts/record-decision.sh`, `scripts/freeze-decisions.sh` (D3 audit-file writers).
- `scripts/probe.sh` (D3 unified env probe).
- `scripts/gate-design-approval.sh`, `scripts/gate-user-build-choice.sh` (D4 script-enforced safety rules — final list per Stage 4 design).

**NOT copied** (deleted with `skills/brainstorming/` at the 2026-05-15 cleanup PR per D8):
- `visual-companion.md`, `server.cjs`, `helper.js`, `frame-template.html`, `start-server.sh`, `stop-server.sh`.

**Source:** A3 GAP, auto-decided as low-risk.

## D14 — `/think` alias scope (revises D11)

**Decision:** This PR registers ONLY the namespaced `/claudex:think` command (auto-discovered from `skills/think/SKILL.md`). It does NOT add `commands/think.md`. The unnamespaced `/think` alias is deferred indefinitely.

**Why:** "Think" is a generic verb. Adding `/think` globally creates a collision risk with any other plugin (current or future) that uses the same alias. The user's "brainstorming is too long" complaint is already addressed: `/claudex:think` (15 chars) is significantly shorter than `/claudex:brainstorming` (22 chars). If the user later confirms they want the shorter unnamespaced form, adding `commands/think.md` is a one-line follow-up PR.

**Revises D11:** D11 listed `commands/think.md` as a new file to add. Remove that line; the only registration change is the new `skills/think/SKILL.md`.

**Source:** A3 GAP, auto-decided as low-risk preference for the conservative default.

## D15 — Stage numbering convention (clarifies D7)

**Decision:** `think` keeps today's `claudex:brainstorming` stage numbering: 7 numbered stages (Stage 0 Setup, Stage 1 Intake, Stage 2 Dialogue, Stage 3 Approaches, Stage 4 Design, Stage 5 Spec, Stage 6 Handoff). Stage 0 is bookkeeping; Stages 1-6 are the substantive brainstorm flow.

Audit-file numbering is a separate convention from stage numbering:
- `00-setup.md` (Stage 0)
- `01-intake-verdict.md` (Stage 1; may be `01-intake-skip.md` if intake-skip-check.sh returns SKIP per D7)
- `02-transcript.md` (continuous, Stages 1-6)
- `03-decisions.md` (continuous, Stages 1-6, frozen at end of Stage 4)
- `04-angle-audit.md` (Stage 3)
- `05-approaches.md` (Stage 3)
- `06-spec-r1.md`, `06-spec-r1.clean.md`, `06-spec-r1-fix.clean.md` (Stage 5 round 1)
- `07-spec-r1-review.md` (Stage 5 round 1 review)
- `08-spec-r2.md`, `08-spec-r2.clean.md`, `08-spec-r2-fix.clean.md` (Stage 5 round 2)
- `09-spec-r2-review.md` (Stage 5 round 2 review)
- `00-spec.md` (Stage 6 binding handoff copy of canonical spec)
- `99-final-summary.md` (after `claudex:build` finishes)

D7's wording "6-stage flow" should read "the same 7-numbered-stage flow (Stage 0 Setup through Stage 6 Handoff)" — same flow as today's `claudex:brainstorming`.

**Source:** A3 GAP, auto-clarified.

## D16 — Codex failure model (revises D9)

**Decision:** Two-mode failure handling based on Stage 0 probe outcome:

- **Stage 0 codex missing (CODEX_MISSING)** → Claude subagent fallback for the entire brainstorm. Each Codex role (recommendation 2nd opinion, spec writer, Opus reviewer) is played by a fresh Claude subagent. Outputs labeled `[Codex(fallback)]` in audit. Brainstorm continues. The subagent's reply must produce the same closed-schema verdict tokens as the dispatch script's contract; if not, exit 5 still halts (schema violation is always a halt).
- **Stage 0 codex present (CODEX_READY)** → any subsequent runtime dispatch failure (`codex exec` exit non-zero, dispatch script exit 4) halts the brainstorm. No mid-stream subagent fallback. The principle: consistent dispatcher identity throughout the brainstorm; switching dispatchers mid-flow corrupts the audit's "second opinion = different vendor" guarantee.
- **Unparsable verdict (dispatch script exit 5)** → always halts, regardless of dispatcher identity. Schema violation is the failure the rewrite exists to catch.

**Why:** Today's permissive blanket fallback weakens the dual-vendor guarantee silently. Pure fail-loud (D9 original) is too brittle for users without codex installed at all. The two-mode split: if you never had codex, subagent is the consistent dispatcher; if you did have codex, do not silently downgrade mid-brainstorm.

**Source:** User redirection in Turn 29.

## D17 — Stages and Codex roles in `think` (revises D7, D15)

**Decision:** `think` has **6 numbered stages** (revises D15's 7-stage convention):

- Stage 0 — Setup (probe codex, create RUN_ID, init audit files)
- Stage 1 — Dialogue (one question at a time, per-recommendation 2nd opinion)
- Stage 2 — Approaches (Claude proposes 2-3, user picks)
- Stage 3 — Design (sectioned, user-approved per section)
- Stage 4 — Spec write + Opus review (Codex writes, fresh Opus subagent reviews; max 2 review rounds)
- Stage 5 — Handoff to `claudex:build` (gated 1/2 user choice)

**Removed entirely:**

- A1 intake framing (no `intake-prompt.md`, no `01-intake-verdict.md`, no `intake-skip-check.sh`).
- A2 independent proposer (no `approaches-codex-prompt.md`; Stage 2 is Claude-only proposing approaches).
- A3 angle audit (no `angle-audit-prompt.md`, no `04-angle-audit.md`, no `dispatch-codex-angle-audit.sh`).

**Codex roles that remain:**

- Per-recommendation 2nd opinion at Stage 1 dialogue (`dispatch-codex-2nd-opinion.sh`, prompt template `second-opinion-prompt.md` copied from brainstorming/).
- Spec writer at Stage 4 (`dispatch-codex-spec-write.sh`, prompt template `spec-codex-prompt.md` copied).
- Opus reviewer at Stage 4 (`build-opus-spec-review-prompt.sh`, prompt template `spec-reviewer-prompt.md` copied).

**Why simpler is better here (per user):** A1/A2/A3 added quality but also added 5+ Codex round-trips per brainstorm and made the skill significantly more complex. The recommendation 2nd opinion is the highest-value dual-vendor check (catches the largest fraction of bad recommendations per token spent); the Stage 4 Codex writer + Opus reviewer is the highest-value structural check (catches drift in the spec). The two checks the user kept are the load-bearing ones.

**Effect on audit-file naming:** `01-intake-verdict.md` removed. `04-angle-audit.md` removed. Other files renumbered by content, not by old slot:
- `00-setup.md`
- `02-transcript.md` (continuous, Stages 1-5)
- `03-decisions.md` (continuous, frozen at end of Stage 3)
- `05-approaches.md` (Stage 2 — Claude-only)
- `06-spec-r1.md`, `06-spec-r1.clean.md`, `06-spec-r1-fix.clean.md` (Stage 4 round 1)
- `07-spec-r1-review.md`
- `08-spec-r2.md`, `08-spec-r2.clean.md`, `08-spec-r2-fix.clean.md` (Stage 4 round 2)
- `09-spec-r2-review.md`
- `00-spec.md` (Stage 5 binding handoff copy)
- `99-final-summary.md`

**Source:** User redirection in Turn 29; explicit removal of A1+A3, and Claude's interpretation of "I want the codex give second opinion" as scoping Codex to recommendation-2nd-opinion + Stage 4 pipeline only (i.e., A2 also removed). User can override the A2 removal if intended otherwise.

## D18 — Stage 2 (Approaches) — Codex extends-or-challenges (hybrid)

**Decision (option B):** Stage 2 has one Codex dispatch.

Flow:
1. Claude proposes 2-3 approaches in a single message, written to scratch file `.approaches-claude.md` via Write tool.
2. Orchestrator dispatches `scripts/dispatch-codex-approaches-extend.sh` with the transcript, decisions, and Claude's proposals as inputs.
3. Codex returns one of:
   - `EXTEND: <new approach D, summary, tradeoffs, risk>` — Codex adds a fresh approach Claude missed.
   - `CRITIQUE: <which approach, what changes>` — Codex modifies or refines one of Claude's existing approaches.
   - `AGREE: <one-line confirmation>` — no changes needed; Claude's proposals are sound as-is.
4. Orchestrator merges Claude's proposals + Codex's contribution into `05-approaches.md` with attribution per approach (`[Claude]`, `[Codex]`, `[both]` if Codex critiques became part of an existing approach).
5. User picks from the merged set (typically 3-4 approaches). Choice recorded via `record-decision.sh`.

**New artifacts required:**

- `skills/think/approaches-extend-prompt.md` (NEW prompt template — replaces today's `approaches-codex-prompt.md` which proposed independently rather than extending). Slots: `{{TRANSCRIPT}}`, `{{DECISIONS}}`, `{{CLAUDE_APPROACHES}}`.
- `skills/think/scripts/dispatch-codex-approaches-extend.sh` (NEW dispatch script). Closed schema: verdict tokens `EXTEND:` / `CRITIQUE:` / `AGREE:`. Exit codes: 0 ok / 2 usage / 3 codex-missing / 4 runtime-fail / 5 unparsable.

**Removed from D17's plan:**

- D17 said no Codex at Stage 2. D18 supersedes that — Stage 2 has one Codex dispatch (hybrid extends-or-challenges, not the original A2 independent-proposer pattern).

**Why hybrid instead of pure independent (A) or pure 2nd opinion (C):** A's rank-sum machinery introduces fake precision (two subjective opinions summed do not become objective) and adds 2 dispatches + scoring + aggregation. C makes Codex reactive only — cannot propose new approaches Claude missed. Hybrid B keeps Codex generative (can introduce a new approach) with one dispatch.

**Effect on SKILL.md outline (Section 5 of design):** Stage 2's `### Dispatch` block changes from "Claude proposes, no Codex dispatch" to a `bash scripts/dispatch-codex-approaches-extend.sh ...` call after Claude writes `.approaches-claude.md`. Verdict table gains the EXTEND / CRITIQUE / AGREE rows.

**Total script count revised:** 9 (was 8 in Section 3 of design — the new `dispatch-codex-approaches-extend.sh` is the 9th).

**Source:** User picked B. Codex AGREE.

## D19 — Stage 2 Codex pattern revised (revises D18)

**Decision (option C — pure 2nd opinion):** Stage 2 uses the same Codex dispatch shape as Stage 1's recommendation 2nd opinion.

Flow:
1. Claude proposes 2-3 approaches in a single message, including its own pick + one-sentence reasoning. The full text is written to `.q.md` (the "question" = "here are 2-3 approaches; my pick is X because Y; do you agree?"). The pick + reasoning is written to `.r.md` (the "recommendation").
2. Orchestrator runs `dispatch-codex-2nd-opinion.sh` (the same script used at Stage 1 — no new script, no new prompt template).
3. Codex returns one of `AGREE: …`, `DISAGREE: …`, `ANGLE-MISSED: …`.
4. Orchestrator presents Claude's proposals + pick + reasoning + Codex's verdict in one message. User picks from the proposals (or asks to revise).
5. Choice recorded via `record-decision.sh`. The merged content (proposals + Codex verdict text) is written to `05-approaches.md` for spec-time read.

**Why C over B (hybrid):** Consistency. Every stage that has Codex involvement uses the same dispatch shape (Claude has a recommendation; Codex AGREE/DISAGREE/ANGLE-MISSED). Stage 2 acting differently (Codex generative-extends) breaks the uniformity that the script-as-control rewrite is testing. Cost is that Codex is reactive only at Stage 2 — but the user's "consistency with previous stages" intent is the load-bearing reason here.

**Effect on script catalog (revises D18):**
- `dispatch-codex-approaches-extend.sh` is NOT added. Removed from D18's plan.
- `approaches-extend-prompt.md` is NOT added. Removed from D18's plan.
- Existing `dispatch-codex-2nd-opinion.sh` and `second-opinion-prompt.md` (copied verbatim from `skills/brainstorming/` per D13) are reused at Stage 2.
- Total script count: back to **8** (the 4 copied + 4 new audit/gate writers + 1 unified probe = 9, minus the now-unneeded extend dispatch = 8). Final: 8 scripts in `skills/think/scripts/`.

**Source:** User redirection in Turn 31; preference for cross-stage consistency over Codex generativity at Stage 2.

## D20 — Recommendation-trigger rule (broadens today's pattern)

**Decision:** The Codex 2nd opinion at Stage 1 dialogue (and any equivalent confirmation point in Stages 2-5) fires for **every user-decision-requesting turn**, not only for turns that carry an explicit Claude recommendation.

**Triggers (require 2nd opinion before showing to user):**

- Any question that asks the user to pick from options (`A / B / C`, `1 / 2`, etc.).
- Any question that asks the user to confirm or reject a proposal ("does this look right?", "shall I continue?").
- Any question that asks the user's preference ("which would you prefer?").
- Any presentation of a design section, an approach set, a spec preview, or a gate choice — anything where the user is being asked to weigh in.

**NOT triggered (no 2nd opinion needed):**

- Pure informational explanations the orchestrator is confident about (e.g., explaining why the `.clean.md` file exists, or what an exit code is). User did not ask the orchestrator to weigh tradeoffs — the orchestrator is just answering a factual question.
- Acknowledgments of user input ("Recorded D20. Continuing to Section 8.").
- Status updates that report what the orchestrator just did (no decision requested from the user).

**Reason (from user):** Reading long content the orchestrator may have gotten wrong is wasted effort. Codex pre-screening catches mistakes before the user commits attention. Cost (more dispatches per brainstorm) is acceptable to the user.

**RATIONALE.md "Recommendation trigger" section is updated:** the trigger is now "user-decision-requesting turn," not "turn with multiple choices OR a recommendation." The pre-D20 wording becomes a subset of D20.

**Effect on script catalog:** none. Same `dispatch-codex-2nd-opinion.sh` script. The trigger is a wording change in the SKILL.md Stage 1 prose line and the RATIONALE.md explanation. The mechanical contract is unchanged.

**Source:** User redirection in Turn 32.

## D21 — Clarifies D20: strict 2nd-opinion application within the decision space

**Decision:** No exceptions within the D20 trigger set. Every user-visible turn that asks the user to decide (pick, confirm, prefer, approve a section, accept a verdict, choose a path, etc.) MUST have a Codex 2nd opinion dispatched before the turn is shown.

The carve-out for purely informational explanations (the orchestrator answering a factual question, acknowledging input, reporting status) still applies — D20 already drew that line.

**Effect:** SKILL.md Stage 1's one-line prose at the top reads (final wording): *"Every user-decision-requesting turn requires a Codex 2nd opinion before it is shown. Pure factual or informational replies do not."* RATIONALE.md "Recommendation trigger" section embeds the rule as: trigger = is the orchestrator asking the user to decide? Yes ⇒ dispatch first; no ⇒ skip.

**Source:** User reinforcement in Turn 33. Strictness is the user's preference; orchestrator does not negotiate this rule down.

## D22 — Stage 4 design approved

**Decision:** All 8 design sections are approved by the user (Sections 1-8, with 8.10 added per Codex's ANGLE-MISSED catch).

The converged design is the union of D1-D21. No outstanding open questions.

Next action (autonomous): write `.design.md` summary, freeze decisions, dispatch Codex final-design verdict (per `claudex:brainstorming` skill protocol that this brainstorm is being run under), present verdict to user, then proceed to Stage 5 spec write.

**Source:** User "yes" in Turn 33.

## D23 — Codex final-design FIX items applied (supersedes parts of D17)

The decisions log is frozen (per D17 + Stage 3 close). This entry is appended as `03-decisions.md.amendments` so the spec writer reads it alongside the frozen log. The amendments file is loaded by the spec writer same as 03-decisions.md.

**Applied F1 (script count fix):** Final catalog of `skills/think/scripts/` is **10 scripts** = 4 copied verbatim + 6 new.

- Copied verbatim from `skills/brainstorming/scripts/` (D13 verified by zero `superpowers` grep matches):
  1. `dispatch-codex-2nd-opinion.sh` — used at Stage 1 (every recommendation/decision turn per D20/D21) AND Stage 2 (per D19) AND any other decision turn in Stages 3/4/5.
  2. `dispatch-codex-spec-write.sh` — Stage 4 only.
  3. `build-opus-spec-review-prompt.sh` — Stage 4 only.
  4. `start-tmux-build.sh` — Stage 5 only (detached build path).
- New scripts:
  5. `probe.sh <codex|tmux|claudex-build>` — Stage 0 + Stage 5.
  6. `record-turn.sh` — only writer of `02-transcript.md`.
  7. `record-decision.sh` — only writer of `03-decisions.md` (refuses after `03-decisions.frozen` marker exists).
  8. `freeze-decisions.sh` — writes `03-decisions.frozen` marker at end of Stage 3.
  9. `gate-design-approval.sh` — Stage 4 entry gate (refuses without `.design-approved` marker).
  10. `gate-user-build-choice.sh` — Stage 5 launch gate (refuses without literal `1` or `2` in `.user-build-choice`).

**Applied F2 (Opus reviewer wording fix):** D16 fallback applies only to true Codex roles, which are TWO: (i) recommendation 2nd opinion at every D20/D21-triggered decision turn (`dispatch-codex-2nd-opinion.sh`), and (ii) Stage 4 spec writer (`dispatch-codex-spec-write.sh`). The Opus reviewer is a Claude/Opus role run via the Agent tool with model="opus"; it does NOT use the codex CLI and is unaffected by `CODEX_STATE`. Restated: in `CODEX_MISSING` mode, only roles (i) and (ii) get a Claude subagent fallback; the Opus reviewer runs identically in both modes.

**Applied F3 (D17 role summary supersedure):** Codex/dispatch roles in `think` (final list, supersedes the partial list in D17):
- `dispatch-codex-2nd-opinion.sh`: invoked at every user-decision-requesting turn per D20+D21 — covers Stage 1 (each clarifying question), Stage 2 (approach validation per D19), Stage 3 (each design-section approval), Stage 4 (Opus verdict presentation if it triggers a user-decision turn), Stage 5 (the inline-vs-tmux choice presentation).
- `dispatch-codex-spec-write.sh`: Stage 4 only, rounds 1, 2, fix1, fix2.
- Opus reviewer (Agent tool, model="opus"): Stage 4 only, after each spec round. Not affected by `CODEX_STATE`.

**Applied F4 (removed-stage references in design summary):** Rewriting `.design.md` to remove every mention of A1, A2, A3, intake framing, intake-skip-check, angle audit, `01-intake-verdict.md`, `04-angle-audit.md`, `dispatch-codex-angle-audit.sh`, `intake-skip-check.sh`, `dispatch-codex-approaches-extend.sh`. None of these exist in the final design.

**Applied F5 (CODEX_MISSING + D20/D21 wording):** Final wording of the recommendation-trigger rule (this is the canonical phrasing for SKILL.md and RATIONALE.md): *"Every user-decision-requesting turn requires a 2nd-opinion dispatch before showing the turn to the user. The dispatch uses `scripts/dispatch-codex-2nd-opinion.sh`. If `CODEX_STATE=READY` (Stage 0 probe), the dispatch invokes `codex exec`. If `CODEX_STATE=MISSING`, the dispatch invokes a Claude subagent (Agent tool, model='sonnet') with the same prompt template, and the verdict line is labeled `[Codex(fallback)] AGREE/DISAGREE/ANGLE-MISSED: ...` in audit and user-visible output. In both modes the closed-schema verdict tokens are the same; an unparsable verdict (exit 5) halts in both modes."*

**Source:** Codex final-design FIX verdict, all 5 items applied per user "go" in Turn 34.

## Problem

`claudex:brainstorming` currently mixes durable control flow with prose instructions. The failure mode is that the orchestrator can improvise around important steps such as second-opinion dispatches, verdict parsing, audit writes, frozen decisions, spec handoff, and build launch gates.

This work creates a new claudex-native `think` skill that keeps user-facing dialogue flexible but moves load-bearing workflow behavior into scripts with closed output schemas.

Success criteria:

- `/claudex:think` is auto-discovered from `skills/think/SKILL.md`.
- `skills/think/` contains no superpowers lineage references.
- Every audit write, Codex dispatch, environment probe, and build gate is script-owned.
- Every user-decision-requesting turn gets a 2nd-opinion dispatch before being shown.
- `CODEX_STATE=MISSING` uses a consistent Claude subagent (Agent tool, model='sonnet') fallback labeled `[Codex(fallback)]` in audit and user-visible output from the start; `CODEX_STATE=READY` halts on later Codex runtime failures.
- Stage 5 produces the same `/tmp/claudex/${RUN_ID}/00-spec.md` and `RUN_ID` handoff contract consumed by `claudex:build`.
- The old `skills/brainstorming/SKILL.md` becomes a one-line deprecation stub pointing to `/claudex:think`.

## Approach (selected)

Use a full script-orchestrated rewrite as a new skill at `skills/think/`.

`SKILL.md` is structured like a small runtime function: each stage declares inputs, dispatches script calls, and maps closed-schema verdicts to next actions. The scripts own the parts that must be predictable. The skill body keeps only the minimal runtime prose needed for user dialogue and judgment-based safety rules.

This preserves the useful part of the current brainstorm flow while removing the over-complex intake, independent approaches proposer, browser visual companion, and angle-audit stages. The remaining high-value checks are:

- recommendation 2nd opinion for every user-decision-requesting turn;
- Codex spec writing;
- Opus review of the generated spec;
- explicit user gate before build launch.

## Architecture

`think` has six numbered stages:

- Stage 0 — Setup: create `RUN_ID`, initialize audit files, probe `codex`, `tmux`, and `claudex:build`.
- Stage 1 — Dialogue: ask one decision point at a time, with a required 2nd-opinion dispatch before every user-decision-requesting turn.
- Stage 2 — Approaches: Claude proposes 2-3 approaches and a pick, sends that recommendation through the same 2nd-opinion dispatch, then records the user’s choice.
- Stage 3 — Design: write and approve sectioned design content, dispatching 2nd opinions before section approvals, then freeze decisions.
- Stage 4 — Spec write + Opus review: Codex writes the spec, Opus reviews it, and the loop runs for at most two rounds.
- Stage 5 — Handoff: require literal user choice `1` or `2`, copy the canonical spec to `00-spec.md`, export `RUN_ID`, and invoke `claudex:build` inline or detached.

Responsibilities:

- Orchestrator: main Claude conversation agent; owns user dialogue, scratch files, and calling scripts.
- Codex 2nd opinion: validates decision-requesting turns through `dispatch-codex-2nd-opinion.sh`.
- Codex spec writer: produces spec rounds through `dispatch-codex-spec-write.sh`.
- Opus reviewer: fresh Claude/Opus subagent reviewing spec quality.
- Audit scripts: append transcript and decisions, freeze decisions, validate gates.
- Probe script: normalizes environment readiness into closed verdicts.

## Components

`skills/think/SKILL.md`:

- Purpose: runtime instruction file for `/claudex:think`.
- Shape: each stage uses `## Inputs`, `## Dispatch`, and `## Verdict → next step`.
- Constraint: no load-bearing ad hoc shell or prose-controlled gate transitions.

`skills/think/RATIONALE.md`:

- Purpose: maintainer-only explanation of why the workflow is shaped this way.
- Required sections: script/prose boundary, safety-rule inventory, recommendation-trigger rule, Codex failure model, visual companion removal.

Roles:

- Orchestrator: main Claude conversation agent. Handles user dialogue, writes scratch files, and invokes the stage scripts.
- Recommendation 2nd opinion: Codex via `dispatch-codex-2nd-opinion.sh`, or Claude subagent (Agent tool, model='sonnet') fallback labeled `[Codex(fallback)]` in audit and user-visible output when `CODEX_STATE=MISSING`.
- Spec writer: Codex via `dispatch-codex-spec-write.sh`, or Claude subagent (Agent tool, model='sonnet') fallback labeled `[Codex(fallback)]` in audit and user-visible output when `CODEX_STATE=MISSING`.
- Opus reviewer: fresh Opus subagent via Agent tool. It does not use the Codex CLI and is unaffected by `CODEX_STATE`.
- User: approves decisions, approaches, design sections, and the final build-launch choice.

Prompt templates:

- `second-opinion-prompt.md`: copied from `skills/brainstorming/`; prompt for AGREE / DISAGREE / ANGLE-MISSED verdicts.
- `spec-codex-prompt.md`: copied from `skills/brainstorming/`; prompt for spec writing.
- `spec-reviewer-prompt.md`: copied from `skills/brainstorming/`; prompt for Opus review.

Script catalog:

Every script's first 30 lines contain a comment block declaring usage, allowed verdict tokens, exit-code map, files read, files written, and the SKILL.md verdict-table-row contract it satisfies. Per-script descriptions below assume this header invariant.

- `dispatch-codex-2nd-opinion.sh`: copied from `skills/brainstorming/scripts/`; fires in Stages 1, 2, 3, 4, and 5 for every user-decision-requesting turn.
- `dispatch-codex-spec-write.sh`: copied from `skills/brainstorming/scripts/`; fires in Stage 4 for spec rounds and fixes.
- `build-opus-spec-review-prompt.sh`: copied from `skills/brainstorming/scripts/`; fires in Stage 4 before each Opus review.
- `start-tmux-build.sh`: copied from `skills/brainstorming/scripts/`; fires in Stage 5 when the user selects detached build mode.
- `probe.sh <codex|tmux|claudex-build>`: new; fires in Stage 0 for environment checks and Stage 5 for build readiness.
- `record-turn.sh`: new; fires throughout Stages 1-5 as the only writer of `02-transcript.md`.
- `record-decision.sh`: new; fires throughout Stages 1-3 as the only writer of `03-decisions.md`.
- `freeze-decisions.sh`: new; fires at the end of Stage 3 to create `03-decisions.frozen`.
- `gate-design-approval.sh`: new; fires at Stage 4 entry to require `.design-approved`.
- `gate-user-build-choice.sh`: new; fires at Stage 5 launch to require literal `1` or `2` in `.user-build-choice`.

## Data flow

Stage 0 creates `/tmp/claudex/${RUN_ID}/` and writes `00-setup.md`. It probes Codex once and records `CODEX_STATE=READY` or `CODEX_STATE=MISSING`.

Throughout Stages 1-5, `record-turn.sh` appends user-visible turns to `02-transcript.md`. Stage decisions are appended through `record-decision.sh` until Stage 3 ends. `freeze-decisions.sh` then writes `03-decisions.frozen`; later decision writes must fail.

Stage 2 writes Claude’s approaches and the 2nd-opinion verdict into `05-approaches.md`.

Stage 3 writes `.design.md` and `.design-approved` after user approval. Stage 4 cannot begin until `gate-design-approval.sh` succeeds.

Stage 4 reads transcript, decisions, approaches, and approved design. `dispatch-codex-spec-write.sh` writes spec round artifacts:

- `06-spec-r1.md`
- `06-spec-r1.clean.md`
- optional `06-spec-r1-fix.md`
- optional `06-spec-r1-fix.clean.md`
- round 2 equivalents if needed

`build-opus-spec-review-prompt.sh` writes reviewer prompt artifacts, and the Opus subagent writes review artifacts such as `07-spec-r1-review.md` and `09-spec-r2-review.md`.

The accepted canonical spec is copied to `docs/claudex/specs/<date>-<topic>-design.md` (carryover from today's claudex:brainstorming canonical-spec path; not changed by this design).

Stage 5 writes the user’s literal choice to `.user-build-choice`. `gate-user-build-choice.sh` validates it. The canonical spec is then copied to `/tmp/claudex/${RUN_ID}/00-spec.md`, `RUN_ID` is exported, and `claudex:build` is invoked inline for `1` or through tmux for `2`.

## Error handling

Two-mode Codex CLI failure model:

- `CODEX_STATE=MISSING`: true Codex roles use Claude subagent (Agent tool, model='sonnet') fallback labeled `[Codex(fallback)]` in audit and user-visible output for the whole brainstorm. Outputs must use the same closed-schema verdict tokens.
- `CODEX_STATE=READY`: any later `codex exec` runtime failure halts. No mid-flow fallback is allowed.
- Any unparsable dispatch output halts in both modes.

The Opus reviewer is not part of Codex failure handling because it is always a Claude/Opus subagent role.

Hard failures:

- `claudex:build` missing at Stage 5.
- invalid or missing `.design-approved`.
- invalid or missing `.user-build-choice`.
- duplicate transcript turn number.
- duplicate decision ID.
- decision write attempted after freeze.
- spec review reaches the second round and still requires escalation.
- Stage 4 spec writer emits `WRONG-DIRECTION:` as the entire first line of its body — the brainstorm halts and the user picks revisit/proceed-anyway/stop.
- copied `skills/think/` files contain `superpowers`, `writing-plans`, or `executing-plans`.

Failures must surface with enough stderr, raw output, or audit path context for the user to retry or inspect.

## Testing

Merge-blocking verification requires one real end-to-end `/claudex:think` run on a non-trivial subject. The PR must include or summarize the full audit directory.

Required live-run checks:

| Check | Required evidence |
|---|---|
| End-to-end run | `/tmp/claudex/<run-id>/` contains expected setup, transcript, decisions, approaches, design, spec, review, handoff, and final summary artifacts. |
| New script coverage | Every new script fires at least once in the live end-to-end run. Script-level tests are not a substitute for this requirement. |
| Design approved gate transition | `gate-design-approval.sh` exits 0 after `.design-approved` exists, and Stage 4 begins only after that success. |
| Opus-review verdict gate transition | Each review file, including `07-spec-r1-review.md` and `09-spec-r2-review.md` when round 2 runs, contains the explicit Opus verdict line used for the next transition. |
| User build choice gate transition | The audit shows the user’s literal `1` or `2` reply before `gate-user-build-choice.sh` succeeds and before any build action starts. |
| Stage 5 hard stop | No build launches before the user choice gate succeeds. |
| `CODEX_MISSING` fallback | Either a second live run with Codex unavailable or an equivalent scripted test shows Claude subagent (Agent tool, model='sonnet') fallback labeled `[Codex(fallback)]` in audit and user-visible output. |

Required script-level and invariant checks:

| Check | Required evidence |
|---|---|
| Verdict-token coverage | Every closed-schema verdict token is either exercised in the live run or explicitly covered by script-level tests. Rare-path carveouts apply only to verdict tokens, not to script firing. |
| `CODEX_READY` runtime failure | A test shows later Codex failure halts rather than falling back. |
| Design gate refusal | `gate-design-approval.sh` refuses Stage 4 dispatch when `.design-approved` marker is missing, with exit 3. |
| Decision freeze refusal | `record-decision.sh` refuses writes after `03-decisions.frozen`. |
| Build choice literal enforcement | `gate-user-build-choice.sh` accepts only literal `1` or `2` and rejects other content. |
| Superpowers independence | `grep -ri 'superpowers\|writing-plans\|executing-plans' skills/think/` returns zero matches. |
| Brainstorming stub | `skills/brainstorming/SKILL.md` is a one-line stub pointing to `/claudex:think`. |
| Rationale presence | `RATIONALE.md` exists with script/prose boundary, safety-rule inventory, recommendation-trigger rule, Codex failure model, and visual companion removal sections. |
| Script headers | Every new script has the required schema header in its first 30 lines. |
| SKILL.md size | `SKILL.md` remains compact, roughly 180 lines. |

## Out of scope

This work does not add an unnamespaced `/think` alias.

This work does not clean unrelated superpowers references elsewhere in the plugin, such as README, CLAUDE.md, or unrelated scripts.

This work does not add a `00-handoff.json` manifest or change `claudex:build`.

This work does not port the browser visual companion. Inline Mermaid diagrams and Markdown tables are enough for visual treatment during `think`.

This work does not remove the full `skills/brainstorming/` directory immediately. It only stubs the skill now; full removal is deferred to the cleanup PR targeted for 2026-05-15.
