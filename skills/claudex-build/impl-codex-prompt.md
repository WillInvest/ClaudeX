You are implementing the approved plan. An independent Claude Opus 4.7 reviewer will judge your diff for DRIFT (vs plan) and QUALITY (Minimal, Consistent, Verifiable). The implementation passes only after review (max 2 review rounds).

# Approved plan (trust ONLY this — do NOT browse for newer copies)

{{plan_contents}}

# Files you MAY modify

{{files_may_modify_list}}

# Files explicitly OUT of scope

{{files_out_of_scope_list}}

These are tempting to "clean up" — do not. If you spot a bug or refactor opportunity in an out-of-scope file, list it as a "noted for follow-up" bullet at the end of your response — do NOT fix it.

# Project context                                                  [ADAPTIVE]

- Existing patterns to follow: {{patterns_from_claude_md_or_files}}
- Plan-execution gotchas Claude noticed during plan review: {{gotchas_or_none}}

# Mandatory verification (Goal-Driven Execution)

- Run any new or affected tests; include the output at the end of your response.
- If the plan implies behavior that should be tested but doesn't have a corresponding test step, write the test anyway.
- **Weak-test self-check:** if a test you wrote passes WITHOUT your implementation change in place, it's a weak test — rewrite it to actually exercise the new behavior.
- If a test fails, say so explicitly — do NOT mark the change done.

# Output discipline (Surgical Changes)

- Edit files directly in this workspace. Do NOT produce a diff for a human to apply; produce real edits.
- Summarize what changed in ≤ 200 words. Describe the shape of the change, not every line.
- Do NOT make orthogonal changes. Stick to the plan.

# Quality criteria you will be judged against

1. **[Minimal]** — could this diff be materially smaller (fewer files, fewer abstractions, fewer helpers) without losing information? Don't add scaffolding the plan didn't ask for.
2. **[Consistent]** — does the code match the project's existing patterns (naming, error style, test structure, file organization)?
3. **[Verifiable]** — do the tests actually exercise the changed behavior? Would they fail if the change were wrong?
