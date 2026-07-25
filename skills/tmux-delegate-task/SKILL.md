---
author: Hauzer S. Lee
category: devops
description: >
  Dispatch a delegate_task and automatically tail its live transcript in a
  dedicated tmux pane. Lets you watch subagent operations in real time without
  polluting your working panes.
license: MIT
metadata:
  hermes:
    scenes:
    - devops
    - hermes
    tags:
    - tmux
    - delegate
    - subagent
    - tail
    - live
name: tmux-delegate-task
platforms:
- linux
- macos
version: 2.0.0
---

# Tmux Delegate Task — Live Transcript in Tmux Pane

Dispatch a `delegate_task` subagent and automatically open a tmux pane tailing
its live transcript. All tmux operations are handled by deterministic bash
scripts — the agent only dispatches and feeds paths.

## Parameters (user-facing)

| Param | Required | Default |
|-------|----------|---------|
| `goal` | yes (single) | — |
| `context` | no | `""` |
| `role` | no | `"leaf"` |
| `tasks` | yes (batch) | — |
| `session` | no | current session |
| `window` | no | depends (see table below) |
| `pane` | no | auto-create |
| `keep` | no | `false` (close on finish) |

## Pane/Window Defaults

| You say... | session | window | pane | behavior |
|------------|---------|--------|------|----------|
| (nothing) | current | current | split new | new pane in current window |
| "infra session" | infra | **new window** | pane 0 | new window created, no split |
| "infra session, hermes window" | infra | hermes | split new | new pane in hermes |
| "infra session, hermes window, pane 3" | infra | hermes | .3 | existing pane, never close |

## Pane Lifecycle Rule

| Pane source | Default behavior | Override |
|-------------|-----------------|----------|
| Auto-created (script created it) | **Close** after delegation | User says "keep" / "don't close" |
| User-provided (`--pane` given) | **Leave untouched** | Never close |

## Execution Flow

### Phase 1: Dispatch

Call `delegate_task` with the user's `goal` (or `tasks`), `context`, and `role`.
Extract the `live_transcripts` paths from the response.

### Phase 2: Tail Setup (script)

Run `scripts/tmux-delegate-tail.sh` with the transcript path. It handles socket
detection, session/window/pane resolution, pane creation with BEFORE_COUNT/AFTER_COUNT
verification, and starts `tail -f`.

```bash
# Auto-create a pane (default for most cases):
bash <skill_dir>/scripts/tmux-delegate-tail.sh \
    '<transcript_path>' \
    --create-pane \
    [--session <name>] \
    [--window <name>] \
    [--keep]

# Use an existing pane:
bash <skill_dir>/scripts/tmux-delegate-tail.sh \
    '<transcript_path>' \
    --pane <%N> \
    [--session <name>] \
    [--window <name>]
```

If neither `--create-pane` nor `--pane` is given, the script defaults to
`--create-pane`. If both are given, `--pane` wins.

**Parse the output** — it emits `key=value` lines:

```
AUTO_PANE=true/false
PANE=%N
SESSION=name
WINDOW=name
KEEP=true/false
AUTO_WINDOW=true/false
TMUX_FLAG=-L nested
```

Store these in conversation context (not memory — they're transient) for Phase 3.

### Phase 3: Cleanup (script, later turn)

When the async delegation result re-enters the conversation, run the cleanup script
with the stored values:

```bash
bash <skill_dir>/scripts/tmux-delegate-cleanup.sh \
    "$AUTO_PANE" "$PANE" "$KEEP" "$AUTO_WINDOW" "$SESSION" "$WINDOW" "$TMUX_FLAG"
```

This kills the pane (and empty window if it was auto-created) unless `keep=true`.

### Phase 4: Report

After Phase 2:

- Delegation ID
- Tmux target: `SESSION:WINDOW.PANE`
- Transcript path
- Keep status (will auto-close or not)

## Full Example

User: "在 infra session 的 hermes 窗口跑 code review"

```
dispatch delegate_task(goal="review PR #42") → live_transcripts=["/cache/.../task-0.log"]

bash scripts/tmux-delegate-tail.sh '/cache/.../task-0.log' --session infra --window hermes
→ AUTO_PANE=true PANE=%65 SESSION=infra WINDOW=hermes KEEP=false

Report: deleg_abc123, infra:hermes.%65, auto-close on finish

[...async result arrives...]

bash scripts/tmux-delegate-cleanup.sh true %65 false false infra hermes "-L nested"
→ pane killed
```

## Error Handling

| Situation | Action |
|-----------|--------|
| Not inside tmux | Script exits with error. Abort. |
| delegate_task fails | Report failure, don't run tail script |
| split-window fails | Script exits with FATAL before any send-keys |
| cleanup kill-pane fails | Script silently ignores — pane may already be gone |

## Dependencies

- `tmux-socket` — socket detection pattern (inlined in script)
- `delegate_task` — Hermes built-in tool

## Pitfalls

- **Store script output, not memory** — `AUTO_PANE`, `PANE`, `SESSION`, etc. are
  transient per-delegation. Keep in conversation context, never in persistent memory.
- **Phase 3 is a separate turn** — when the async result arrives. Reload the stored
  variables and call the cleanup script.
- **Script handles BEFORE_COUNT/AFTER_COUNT** — the agent doesn't need to verify
  pane creation; the script does it.
