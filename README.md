# ClaudeX

**Dual-Model Harnessing OS: dual-model collaboration, persistent memory recording, and minimal context per prompt.**

ClaudeX is the public face of a Dual-Model Harnessing OS: Claude and Codex work as independent peers instead of one model carrying the whole build. Claudex shipped today as step 1, adding dual-model collaboration to the `superpowers` flow and using a model gate when the user will not read every artifact. Step 2 is CXMem, now in progress, bringing persistent memory recording so prior rounds can be found without stuffing the whole history back into each prompt. The design constraint is simple: record the work continuously, then load minimal context per prompt.

## Today: Claudex (step 1)

### Quick start

In Claude Code:

```
/plugin marketplace add WillInvest/ClaudeX
/plugin install claudex@willinvest
```

Then verify the [`codex` CLI](https://github.com/openai/codex) is available (>= 0.122.0):

```bash
codex --version
```

If `codex` is not installed, ClaudeX falls back to a Claude subagent for Codex's role — dual-vendor diversity is degraded but independent-context review is preserved.

Then in Claude Code, just describe what you want to build in natural language and the brainstorming skill auto-activates, or invoke it via the picker:

```
/claudex:brainstorming  let's think how to use AI-Agent to create a AI-DAO for blockchain
```

ClaudeX takes it from there: Claude + Codex co-brainstorm → spec → autonomous plan → autonomous impl → final summary, with terse 3-line status updates per stage and a full audit trail you can read after. The build pipeline is reachable directly via `/claudex:build`.

To update later:

```
/plugin marketplace update willinvest
/plugin update claudex
```

### How it runs

`superpowers` is a great skill library, but its design assumes the **user reads the spec and the plan**. In practice almost no one does. That single-model loop has three drift points:

1. Brainstorming offers one recommendation per question — whatever the model leans toward.
2. The spec is written by the same model that ran the brainstorm.
3. The plan is written by the same model again, against a spec the user skimmed at best.

The intended drift defense is human review. The actual drift defense is hope.

**ClaudeX replaces the missing human gate with a model gate.** Two models, different vendors, different inductive biases — Claude (Opus) and OpenAI Codex. They disagree on real things. Their disagreements catch real bugs.

In `superpowers`, one model runs the whole pipeline (brainstorm → spec → plan → impl) and the user is expected to gate at the spec. ClaudeX makes the loop multi-actor: every recommendation gets a Codex second opinion, and every artifact (plan, impl) gets an independent Opus review.

```mermaid
sequenceDiagram
    actor U as User
    participant C as Main Claude<br/>(orchestrator)
    participant X as Codex<br/>(writer)
    participant O as Opus reviewer<br/>(fresh subagent)

    U->>C: /claudex-brainstorm
    loop every recommendation
        C->>X: dispatch (2nd opinion?)
        X-->>C: AGREE / DISAGREE / ANGLE-MISSED
    end
    Note over C,X: design converges
    C->>X: dispatch (final verdict)
    X-->>C: READY / FIX / WRONG-DIRECTION
    Note over C: hand off → /claudex:build

    rect rgba(60,120,255,0.08)
        Note over C,O: PLAN stage
        C->>X: dispatch 
        X-->>C: write plan
        C->>O: dispatch
        O-->>C: review
    end
    rect rgba(60,120,255,0.08)
        Note over C,O: IMPL stage
        C->>X: dispatch 
        X-->>C: write code
        C->>O: dispatch
        O-->>C: review
    end

    C-->>U: done + audit trail
```

**The reviewer judges every artifact against three principles:**

- **Minimal** — could the artifact be materially smaller without losing information? Flag only when simplification removes ≥10% of size or eliminates a structural element (a step, a file, a helper). Not word-by-word tightening.
- **Consistent** — does it follow the project's existing patterns (naming, error style, test structure, file organization)?
- **Verifiable** — do the tests actually exercise the changed behavior? Would they fail if the implementation were wrong? Or are the assertions tautologies that pass against the artifact itself?

### Side-by-side with plain superpowers

| | superpowers | ClaudeX |
|---|---|---|
| Brainstorming recommendations | one model's lean | side-by-side Claude + Codex |
| Final-design check before spec | none | Codex verdict (`READY` / `FIX` / `WRONG-DIRECTION`) |
| Plan writer | Claude | Codex (latest model) |
| Plan reviewer | none / user | fresh Opus 4.7 subagent (DRIFT + QUALITY + VERDICT) |
| Impl writer | user / claude | Codex |
| Impl reviewer | none / user | fresh Opus 4.7 subagent |
| Drift defense if user skims | hope | model |
| Cost | 1 model | 2 models, ~2× tokens at brainstorm peaks |

## Next: CXMem (step 2)

CXMem is in progress, not shipped as a stable public surface. It records every round under `~/CXMem/projects/<X>/`: the user prompt, assistant output, tool calls, and decisions, with indexed catch-up through `project-memory.md` plus active session drill-down.

The public API is not stable, and this README intentionally avoids freezing a schema, slug protocol, or storage contract. We are dogfooding it under `claudex-imp` while the memory layer proves that persistent records can stay useful without making each prompt carry the whole project history.

## Roadmap

Future decisions are constrained by one north star: consistent memory recording across sessions plus minimal context loaded per prompt. Claudex handles the shipped dual-model harness today; CXMem is the next layer that should make the harness better at resuming, auditing, and staying small.

## Credits & license

ClaudeX is built upon [obra/superpowers](https://github.com/obra/superpowers) by Jesse Vincent — the structural skills (brainstorming, writing-plans, executing-plans, TDD, debugging, ...) are upstream's work; ClaudeX layers a multi-model collaboration pattern on top. Big thanks to the upstream project; without it there's nothing to build upon.

Released under the [MIT License](./LICENSE), preserving upstream's copyright notice.

## Feedback

Open an issue, send a PR, or just star the repo if the dual-model framing resonates. `v0.1.0` is verified end-to-end on smoke tests; battle-testing on real projects is the next step.
