You are drafting an implementation plan. An independent Claude Opus 4.7 reviewer will judge your plan for DRIFT (vs spec) and QUALITY (Minimal, Consistent, Verifiable). The plan moves to implementation only after passing review (max 2 review rounds per stage).

# Spec (trust ONLY this — do NOT browse for newer copies)

{{spec_contents}}

# Project context                                                  [ADAPTIVE]

- Existing patterns to follow: {{patterns_from_claude_md_or_files}}
- Clarifications from brainstorm not captured in spec: {{clarifications_or_none}}
- Files most relevant to this work (embedded inline): {{relevant_files_inline}}

# Required plan structure

1. **One-paragraph summary** of the approach.
2. **Numbered steps**, each with: (a) what changes, (b) which files, (c) why this step exists, (d) how to verify it works.
3. **Assumptions** — explicit list of anything you assumed because the spec didn't say.
4. **Tradeoffs** — at least one alternative considered + why rejected.
5. **Out-of-scope confirmation** — list temptations you resisted (refactors, adjacent files, "while we're here" cleanups).
6. **Verification strategy** — what makes this plan "done" objectively.

# Quality criteria you will be judged against

1. **[Minimal]** — could this plan be materially smaller without losing information? Only flag-able issues remove ≥10% of size or eliminate a structural element. Do not pad the plan; do not over-decompose.
2. **[Consistent]** — does the plan follow the project's existing patterns (naming, error style, test structure, file organization)?
3. **[Verifiable]** — do the verification steps actually exercise the new behavior? Would they fail if the implementation were wrong?

# Output discipline

- Markdown.
- No preamble like "Here is the plan:" — start directly with the plan.
- No editorializing about your process — just the plan.
