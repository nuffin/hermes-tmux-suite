---
author: Hauzer S. Lee
category: devops
description: >-
  Dispatch a delegate_task and tail its live transcript in a tmux pane, or
  directly run hermes chat -q in a dedicated tmux pane. Two modes — use
  delegate_task for complex multi-step tasks, use hermes chat -q for focused
  single-shot tasks the user wants to watch.
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
    - chat
name: tmux-delegate-task
platforms:
- linux
- macos
version: 2.2.0
---

# Tmux Delegate Task — Live Transcript in Tmux Pane

Dispatch work to a tmux pane so the user can watch progress in real time.

## Two Dispatch Modes

| Mode | When to use | How |
|------|-------------|-----|
| **Delegate + Tail** | Complex multi-step task, wants transcript saved | `delegate_task` + tail script |
| **Direct `hermes chat -q`** | Simple focused task, user wants to watch real-time output | `tmux send-keys` + `hermes chat -q '...'` |

## Parameters (user-facing)

For Delegate + Tail mode:

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

---

## Mode A: Delegate + Tail (complex tasks)

### Execution Flow

#### Phase 1: Dispatch

Call `delegate_task` with the user's `goal` (or `tasks`), `context`, and `role`.
Extract the `live_transcripts` paths from the response.

#### Phase 2: Tail Setup (script)

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

#### Phase 3: Cleanup (script, later turn)

When the async delegation result re-enters the conversation, run the cleanup script
with the stored values:

```bash
bash <skill_dir>/scripts/tmux-delegate-cleanup.sh \
    "$AUTO_PANE" "$PANE" "$KEEP" "$AUTO_WINDOW" "$SESSION" "$WINDOW" "$TMUX_FLAG"
```

This kills the pane (and empty window if it was auto-created) unless `keep=true`.

#### Phase 4: Report

After Phase 2:

- Delegation ID
- Tmux target: `SESSION:WINDOW.PANE`
- Transcript path
- Keep status (will auto-close or not)

### Full Example (Delegate + Tail)

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

---

## Mode B: Direct `hermes chat -q` in tmux pane (simple tasks)

For focused, single-shot tasks where the user wants to see the agent working
in a tmux pane without setting up transcript tailing or cleanup.

### Execution Flow

#### Step 1: Create tmux window/pane

```bash
tmux new-window -t <session> -n <name>
```

Or for an existing window/session, skip this step.

#### Step 2: Send `hermes chat -q` to the pane

```bash
tmux send-keys -t <session>:<window> 'cd /path/to/project && hermes chat -q "Your prompt here. Single line or use \\n for newlines."' Enter
```

**CRITICAL quoting rules:**
- The prompt text must be wrapped in **double quotes** inside `tmux send-keys`:
  `tmux send-keys -t S:W "hermes chat -q \"...prompt...\"" Enter`
- Keep the prompt short enough to fit in a single shell line
- If the prompt is too long for a single line, write it to a temp file and use xargs:
  ```bash
  echo 'Your multi-line prompt here' > /tmp/prompt.txt
  tmux send-keys -t S:W "hermes chat -q \"\$(cat /tmp/prompt.txt)\"" Enter
  ```
- DO NOT use `-f` or `-z` flags — they don't exist on `hermes chat`
- DO NOT use single quotes around the prompt inside tmux send-keys — the shell event loop processes them incorrectly

#### Step 3: Return to user immediately

After dispatching, report:
- Tmux target: `SESSION:WINDOW`
- What the agent was asked to do

Do NOT wait for completion. The user will watch the pane themselves.

#### Step 4: Cleanup (optional)

On user request, close the pane:
```bash
tmux kill-pane -t SESSION:WINDOW
```

Or if the window only had one pane and was auto-created:
```bash
tmux kill-window -t SESSION:WINDOW
```

### Full Example (Direct `hermes chat -q`)

User: "delegate 两个 tmux pane 去执行两个任务：commit PS 和重新生成图"

```
# Task 1: PS commit
tmux new-window -t agora-code -n ps-commit
tmux send-keys -t agora-code:ps-commit 'cd ~/studio/hermes/projects/hermes-personal-suite && git add -A && git commit -m "..." && git push' Enter

# Task 2: Regenerate diagrams
tmux new-window -t agora-runtime -n doc-diagrams
tmux send-keys -t agora-runtime:doc-diagrams 'cd /home/hauzer/studio/hermes/projects/agora && hermes chat -q "Regenerate 6 SVGs: architecture_d2 d3 d4 data-model_d1 product-requirements_d1 technical-design_d1. Read ASCII from .md docs. Hand-craft SVG with rect+line+text+arrow markers. Dark theme: bg #0f1117 boxes #1e2130 accent #8b5cf6 providers #10b981. Overwrite files. Verify XML."' Enter
```

### Pitfalls (Direct Mode)

- **🔴 Shell quoting is the #1 failure point.** `tmux send-keys` + multi-line `hermes chat -q` with double-quote nesting is fragile. Always prefer a single-line prompt. For long prompts, use the temp-file pattern above.
- **No auto-cleanup.** Unlike Delegate + Tail mode, there's no script to auto-close the pane. The user must close it themselves or ask.
- **No transcript saved.** The agent's output only lives in the tmux scrollback. If the user wants a permanent record, use Delegate + Tail mode.
- **Pane lifecycle:** Don't close a pane the user is actively watching. Only close on explicit request.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Not inside tmux | Script exits with error. Abort. |
| delegate_task fails | Report failure, don't run tail script |
| split-window fails | Script exits with FATAL before any send-keys |
| cleanup kill-pane fails | Script silently ignores — pane may already be gone |
| tmux send-keys + hermes chat -q stuck in > prompt | Send Ctrl+C to kill, re-send with proper quoting |

## Dependencies

- `tmux-socket` — socket detection pattern (inlined in script)
- `delegate_task` — Hermes built-in tool (Mode A only)
- `hermes chat -q` — CLI chat in non-interactive mode (Mode B only)

## Pitfalls

- **Store script output, not memory** — `AUTO_PANE`, `PANE`, `SESSION`, etc. are
  transient per-delegation. Keep in conversation context, never in persistent memory.
- **Phase 3 is a separate turn** — when the async result arrives. Reload the stored
  variables and call the cleanup script.
- **Script handles BEFORE_COUNT/AFTER_COUNT** — the agent doesn't need to verify
  pane creation; the script does it.
- **🔴 Don't split-then-pane** — 禁止先 `tmux split-window`（产生空 pane）再
  `--pane <.N>` 传 index。index 不稳定且留空 pane 挡用户视线。两种正确方式：
  - 用户指定了已有 pane → `--pane <.N>` 直接用
  - 没有指定 → `--create-pane` 让脚本自动创建和管理
- **🔴 Never try `hermes chat -f` or `hermes chat -z`.** These flags don't exist.
  The only correct way to pass a non-interactive prompt is `hermes chat -q "..."`.
