# Tmux-detached build handoff for `/claudex:brainstorming`

- **Status:** ready-for-build
- **Date:** 2026-05-01
- **Author:** claude (claudex-brainstorming)

## Problem

`/claudex:brainstorming` produces a spec, then invokes `/claudex:build` inline in the same Claude Code session. Build is long-running — Codex plan + Opus review + Codex impl + Opus review, often 10–30 minutes. When the user is `ssh`ed into a host (e.g., from a Mac to `fao@.155`) and the SSH connection drops, the parent Claude Code process dies and the entire build dies with it. Re-running means re-paying the latency and tokens of the plan and impl stages, sometimes several rounds in.

The fix is a detached execution path that survives SSH drops.

## Goal

Add an inline-vs-tmux choice at the brainstorming → build handoff. The tmux path runs the build in a detached `tmux` session on the host, fully decoupled from the parent Claude Code session, so SSH drops and main-session crashes don't kill the build. Universal mechanism, no personal preferences in claudex core.

## Non-goals

- `/claudex:build` direct invocation gets no special treatment. If/when someone reports the same pain there, extract a shared helper.
- No cron reaper, no auto-cleanup, no auto-close after build. Manual cleanup only.
- No IPC report-back to the main session — that would defeat the purpose of detaching.
- No notifications, no `/note`/`/recall`-style integrations in core. Those live in a user's personal layer (see "Extension point" below) and are out of scope here.
- No alternative multiplexers (screen, zellij, dtach). tmux only. Other tools can be added later if needed.
- Resuming from a killed/crashed tmux session.

## Architecture overview

```
┌─────────────────────────────────────┐
│ /claudex:brainstorming              │
│                                     │
│ 1. produce spec                     │
│ 2. self-review                      │
│ 3. NEW: ask inline vs tmux          │
│    ├── inline → Skill→build         │  (current behavior, unchanged)
│    └── tmux   → start-tmux-build.sh │
│                       ↓             │
└───────────────────────│─────────────┘
                        │
                        ▼
   detached `tmux` session on the host
   ┌────────────────────────────────────────┐
   │ claude --permission-mode bypassPermissions          │
   │   (interactive TUI, prompt from stdin) │
   │     ↓                                  │
   │   /claudex:build <spec-path>           │
   │   <optional post-build-hook contents>  │
   │     ↓                                  │
   │   final summary printed to pane        │
   │   /tmp/claudex/<run-id>/99-final-…     │
   │     ↓ claude exits                     │
   │   exec bash  ← pane stays open         │
   └────────────────────────────────────────┘
```

Brainstorming exits as soon as `start-tmux-build.sh` returns. The detached tmux session continues independently. The user attaches with `tmux attach -t <session-name>` from any terminal at any time, including a fresh SSH after the original one died.

## Files touched (claudex repo)

| File | Change |
|---|---|
| `skills/brainstorming/SKILL.md` | Replace the existing `<!-- CLAUDEX:BEGIN — replaces upstream user-review gate + writing-plans handoff -->` block (currently lines 236–250) with the new inline-vs-tmux handoff. |
| `skills/brainstorming/scripts/start-tmux-build.sh` | NEW. Computes session name and run-id, builds the prompt with optional hook appended, launches detached tmux, prints attach instructions. |
| `skills/build/SKILL.md` | Minimal change in step 1a: honor `RUN_ID` from environment if set; otherwise compute as today. Lets the launcher know the run-id up front so the printed summary path is accurate. |

No new top-level files. No changes to other skills.

## Detailed design

### 1. Brainstorming handoff (`skills/brainstorming/SKILL.md`)

Replace the existing handoff block with:

```markdown
<!-- CLAUDEX:BEGIN — replaces upstream user-review gate + writing-plans handoff -->

**Handoff to build (inline or detached tmux):**

After the spec self-review pass, do NOT ask the user to review the spec. Decide the execution path:

1. Probe `command -v tmux >/dev/null`.
   - **Missing**: announce `tmux not found — running build inline. Install tmux for detached builds that survive SSH drops.` Then invoke the `build` skill (Skill tool, name: `build`) and stop. Do not invoke `writing-plans`.
   - **Present**: ask the user:
     ```
     Spec at <path>. How should I run the build?
       1) Inline (this session — dies if SSH drops)
       2) Detached tmux (survives SSH drops; you attach with `tmux attach -t <name>`)
     ```

2. **Inline (1)**: announce `Spec at <path>. Starting build inline.` Invoke the `build` skill. Same as the prior behavior.

3. **Detached tmux (2)**: invoke the launcher script via Bash. The launcher lives at `scripts/start-tmux-build.sh` next to this `SKILL.md`. Resolve its path using `$CLAUDE_PLUGIN_ROOT` if the harness exposes it; otherwise fall back to `dirname` of the skill file (the existing visual-companion scripts at `skills/brainstorming/scripts/{start,stop}-server.sh` use the same convention — the implementer should match whatever pattern is already proven there).
   ```bash
   bash "<launcher-path>" "<spec-path>"
   ```
   Echo the script's stdout verbatim to the user. Do NOT invoke the `build` skill in this session — the detached tmux owns the build now.

If the user explicitly asks to review the spec before proceeding, honor that — show the spec path and pause until the user says go. The default is to proceed without pausing.

**Optional personal extension (not in core, not shipped):** if `~/.claude/claudex/post-build-hook.md` exists and is non-empty, the launcher appends its contents to the in-tmux prompt after `/claudex:build <spec-path>`. Use this for personal post-build behaviors (note capture, notifications, etc.) without modifying claudex. An empty file is treated as no hook.

<!-- CLAUDEX:END -->
```

### 2. Launcher (`skills/brainstorming/scripts/start-tmux-build.sh`)

```bash
#!/usr/bin/env bash
# Launches /claudex:build for SPEC_PATH inside a detached tmux session.
# Prints the session name and operating instructions to stdout.
set -euo pipefail

SPEC_PATH="${1:?usage: start-tmux-build.sh <spec-path>}"
[[ -f "$SPEC_PATH" ]] || { echo "error: spec not found: $SPEC_PATH" >&2; exit 1; }
command -v tmux >/dev/null || { echo "error: tmux not on PATH" >&2; exit 1; }
command -v claude >/dev/null || { echo "error: claude CLI not on PATH" >&2; exit 1; }

# --- 1. Derive slug from spec basename (strip date prefix and -design.md suffix). ---
spec_base="$(basename "$SPEC_PATH" .md)"
# 2026-05-01-tmux-build-handoff-design  ->  tmux-build-handoff
slug="$(echo "$spec_base" \
  | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//' \
  | sed -E 's/-design$//')"

# --- 2. Compute run-id and session name. ---
# Run-id format mirrors build/SKILL.md step 1a (UTC, minute precision)
# so the build skill can honor the injected RUN_ID and produce paths
# matching what the launcher prints.
RUN_ID="$(date -u +%Y-%m-%d-%H%M)-${slug}"
# Session name uses local-time second precision to keep tmux-session
# names distinct even within the same minute. Different format from RUN_ID
# is intentional — different purposes.
HMS="$(date +%H%M%S)"
SESSION_NAME="claudex-build-${slug}-${HMS}"

# Collision guard: if SESSION_NAME already exists, append -2, -3, ...
n=2
while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
  SESSION_NAME="claudex-build-${slug}-${HMS}-${n}"
  n=$((n+1))
done

# --- 3. Build the prompt as a tmpfile (no shell substitution into tmux command). ---
PROMPT_FILE="$(mktemp -t claudex-prompt.XXXXXX)"
trap 'rm -f "$PROMPT_FILE"' EXIT

{
  printf '/claudex:build %s\n' "$SPEC_PATH"
  HOOK="$HOME/.claude/claudex/post-build-hook.md"
  if [[ -s "$HOOK" ]]; then
    printf '\n--- post-build hook (%s) ---\n' "$HOOK"
    cat "$HOOK"
  fi
} > "$PROMPT_FILE"

# --- 4. Launch detached. Read prompt from stdin so quoting is safe. ---
# Inside the tmux pane:
#   claude reads its initial prompt from $PROMPT_FILE via stdin
#   when claude exits, `exec bash` keeps the pane open for inspection
#
# RUN_ID is exported so the in-tmux build skill picks it up (build/SKILL.md 1a).
# The literal $PROMPT_FILE path is interpolated NOW into the tmux command;
# the file lives until the script's EXIT trap fires, but tmux has already
# read it via the launched shell's stdin redirection. To keep the file
# alive across shell startup we copy it to a stable location first.
STABLE_PROMPT="/tmp/claudex/prompts/${RUN_ID}.prompt.md"
mkdir -p "$(dirname "$STABLE_PROMPT")"
cp "$PROMPT_FILE" "$STABLE_PROMPT"

tmux new-session -d -s "$SESSION_NAME" \
  "RUN_ID='${RUN_ID}' claude --permission-mode bypassPermissions < '${STABLE_PROMPT}' ; exec bash"

# --- 5. Report. ---
cat <<EOF
[claudex] Build running in tmux session: ${SESSION_NAME}
  Attach:    tmux attach -t ${SESSION_NAME}
  Detach:    Ctrl-b d
  Summary:   /tmp/claudex/${RUN_ID}/99-final-summary.md  (after build)
  Audit:     /tmp/claudex/${RUN_ID}/
  Kill:      tmux kill-session -t ${SESSION_NAME}

Run-id: ${RUN_ID}
EOF
```

Notes on the implementation:

- **Quoting safety.** The build prompt is written to a tmpfile and stabilized at `/tmp/claudex/prompts/<run-id>.prompt.md`. The tmux command reads it via shell `<` redirection. No `$(cat …)` substitution into a double-quoted tmux command — addresses the brittleness Codex flagged.
- **`RUN_ID` propagation.** Exported into the tmux pane's environment via the prefix `RUN_ID='…' claude …`. The build skill is updated (see §3) to honor it.
- **Session-name collision.** Suffix is `HHMMSS` not `HHMM`, plus a `has-session`-guarded `-2/-3/...` retry. Two launches in the same second still get distinct names.
- **Hook boundary.** Hook content is preceded by a blank line and a visible header `--- post-build hook (<path>) ---` so it never accidentally merges with `/claudex:build <spec-path>` on the same logical line.
- **Pane stays open.** `; exec bash` after `claude` keeps the pane alive after Claude exits, so the user can `cat` the summary, inspect the audit trail, or just scroll back through the build trace.
- **No cleanup of `$STABLE_PROMPT`.** Lives in `/tmp/claudex/prompts/`, cleaned by tmpfs reboot. Tiny files; not worth the complexity of trap-based cleanup that would have to outlive the parent script.

### 3. Build skill change (`skills/build/SKILL.md`, step 1a)

Current step 1a (line ~141) computes `RUN_ID` unconditionally:

```bash
RUN_ID="$(date -u +%Y-%m-%d-%H%M)-<slug>"
mkdir -p /tmp/claudex/$RUN_ID
cp <spec-path> /tmp/claudex/$RUN_ID/00-spec.md
```

Change to honor an injected `RUN_ID` from environment, falling back to computing a fresh one:

```bash
RUN_ID="${RUN_ID:-$(date -u +%Y-%m-%d-%H%M)-<slug>}"
mkdir -p /tmp/claudex/$RUN_ID
cp <spec-path> /tmp/claudex/$RUN_ID/00-spec.md
```

That's the only build-skill change. When invoked inline (no `RUN_ID` in env), behavior is identical to today. When invoked from the tmux launcher, `RUN_ID` is pre-set and the launcher's printed summary path matches reality.

### 4. CLI invocation details

Required Claude CLI behavior:

- `claude --permission-mode bypassPermissions` starts an interactive TUI session that does not prompt for any tool permission. This is required because the detached pane has no attached user to answer permission prompts; `auto` and `acceptEdits` still raise prompts for non-edit actions (reads outside cwd, network, MCP tools).
- Reads the initial prompt from stdin when stdin is a non-TTY (TUI still launches; the prompt is treated as the first user message). This is how `claude < file` works today.
- Tools execute live; the user can attach via `tmux attach` and interact (or `Ctrl-c`, `/exit`, etc.) at any time.

If the CLI's `--permission-mode bypassPermissions` semantics or stdin-prompt behavior change in a future release, the launcher will need a corresponding update. The build implementation should verify the current CLI's behavior with `claude --help` and a one-shot smoke test before shipping.

## Failure modes

| Failure | Behavior |
|---|---|
| `tmux` not on PATH | Brainstorming announces and falls back to inline build. |
| `claude` not on PATH (host) | Launcher exits non-zero with `error: claude CLI not on PATH`; brainstorming surfaces the error to the user. |
| `claude` not on PATH inside the tmux pane (different env) | Pane shows `claude: command not found` then drops to `bash` via `exec bash`. User attaches to investigate. |
| Spec path doesn't exist | Launcher exits non-zero with `error: spec not found: <path>`. |
| Hook file exists but contains broken instructions | Auto-mode Claude inside the pane reports the issue, exits, pane drops to bash. The hook is the user's problem; core does not validate it. |
| Session-name collision | Launcher's `has-session` loop adds `-2/-3/...` suffix automatically. |
| Two launches same second, same slug | Resolved by the collision guard above. |
| Build crashes mid-run | Detached pane shows the crash trace; pane stays open via `exec bash`. User attaches, reads, decides next steps. |
| User detaches and forgets the session | Session persists until `tmux kill-session` or host reboot. `tmux ls \| grep claudex-build` lists them. |

## Testing

After implementation:

1. **Unit-style smoke test of the launcher** (no spec, no claude):
   - Stub `claude` with a script that just prints its argv and stdin to a log; verify the launcher constructs the right prompt and tmux command.
   - Verify slug derivation for several spec basenames.
   - Verify collision guard by pre-creating a `tmux new-session -d` with the expected name and re-launching.
2. **End-to-end with a tiny real spec.**
   - Create a one-line trivial spec (e.g., "add a comment to README.md").
   - Run brainstorming through to handoff, choose tmux.
   - Verify session is created, pane runs `/claudex:build`, build completes, summary file exists at the printed path.
   - Verify `RUN_ID` env propagation: the path the launcher printed matches the path the build skill actually used.
3. **Hook test.**
   - Create `~/.claude/claudex/post-build-hook.md` with a single line like `echo hook-was-here > /tmp/claudex-hook-test.flag`.
   - Re-run end-to-end. Verify the prompt file shows the separator + hook contents. Verify the auto-mode Claude actually executed the hook line.
4. **tmux-missing fallback.**
   - Temporarily mask tmux (e.g., `PATH=/usr/bin claude` with tmux removed). Re-run brainstorming through handoff. Verify inline path runs and finishes, with the announced fallback notice.
5. **Inline path regression.**
   - With tmux present, choose option 1. Verify behavior is identical to pre-change (sanity check that the new branch didn't break the existing one).

## Extension point (informational, not in core)

The `~/.claude/claudex/post-build-hook.md` file is an opt-in extension point. It is NOT shipped, NOT documented in user-facing READMEs as a recommended setup, and NOT validated by core. Personal users (e.g., the original requester) can populate it with whatever they want appended to the in-tmux prompt — for example:

```
After /claudex:build finishes:
1. Run /note to capture the session into the vault. Skip if cwd isn't in the vault.
2. Send a WeChat summary: cc-connect send -p hao -m "Build done: <slug>. Audit: /tmp/claudex/<run-id>/. Tmux: <session-name>."
3. Exit Claude with /exit.
```

The skills referenced (`/note`, `cc-connect`, etc.) live entirely in the user's personal layer at `~/.claude/skills/` and on PATH respectively; claudex core never references them and never depends on them existing.

## Migration / rollout

- Land the launcher script and SKILL.md change together. The build-skill `RUN_ID`-honoring change can ship in the same PR.
- No version bump needed — this is additive. Existing inline behavior is preserved as option 1.
- Document the new option in the project README under whatever section already covers `/claudex:brainstorming` and `/claudex:build`.

## Out of scope (restated for the implementer)

- Cron-based session reaping
- Auto-close after build
- Report-back IPC to the main session
- Personal note/recall/wechat skills (these belong in `~/.claude/skills/` and `~/.claude/claudex/post-build-hook.md`)
- `/claudex:build` direct invocation getting the same prompt
- Non-tmux multiplexers
- Resume from killed/crashed tmux session
