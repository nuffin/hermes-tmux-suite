---
author: Hauzer S. Lee
category: devops
description: >
  Detect the active tmux socket from the current environment and provide the
  correct -L/-S flag for tmux commands. Use this skill whenever a skill or
  script needs to create, attach, or send commands to a tmux session — it
  ensures commands reach the right tmux server (especially in nested setups).
license: MIT
metadata:
  hermes:
    scenes:
    - devops
    tags:
    - tmux
    - socket
    - nested
    - devops
    - utility
name: tmux-socket
platforms:
- linux
- macos
version: 1.0.0
---

# Tmux Socket Detection

When running inside tmux, all `tmux` commands automatically route to the
same server. But when scripts or skills need to construct tmux commands
explicitly, they must know the socket to target — especially in nested
setups where `tmux -L nested` is required.

## Detection Snippet

Paste this at the top of any script or use it to prefix tmux commands:

```bash
# Detect tmux socket flag
if [ -n "$TMUX" ]; then
    SOCKET_PATH=$(tmux display-message -p '#{socket_path}' 2>/dev/null)
    SOCKET_NAME=$(basename "$SOCKET_PATH")
    if [ "$SOCKET_NAME" != "default" ]; then
        TMUX_FLAG="-L $SOCKET_NAME"
    else
        TMUX_FLAG=""
    fi
else
    TMUX_FLAG=""
fi
```

Then prefix all tmux commands with `$TMUX_FLAG`:

```bash
tmux $TMUX_FLAG new-session -d -s my-session
tmux $TMUX_FLAG send-keys -t my-session:0 "command" Enter
tmux $TMUX_FLAG has-session -t eir-runtime
```

## How It Works

`$TMUX` contains the socket path in format `/path,/pid,/window_id`.
`tmux display-message -p '#{socket_path}'` returns the canonical socket
path (e.g., `/tmp/tmux-1000/nested`).

| Socket | basename | TMUX_FLAG |
|--------|----------|-----------|
| `/tmp/tmux-1000/default` | `default` | `""` (empty, implicit) |
| `/tmp/tmux-1000/nested` | `nested` | `-L nested` |
| Not in tmux | — | `""` (empty) |

## One-liner (for inline use in skills)

```bash
TMUX_FLAG=$(if [ -n "$TMUX" ]; then S=$(tmux display -p '#{socket_path}' 2>/dev/null); N=$(basename "$S"); [ "$N" != "default" ] && echo "-L $N"; fi)
```

## Usage in Skills

Skills that create or interact with tmux sessions should reference this
skill and adopt the `$TMUX_FLAG` pattern. Key consumers:

- `eir-service-management` — all `tmux send-keys` and `tmux list-windows`
- `eir-bridge-architecture` — tmux deployment
- `eir-bridge-frontend` — bridge restart via tmux
- `independent-service-clusters` — `tmux new-session` creation
- `gui-terminal-launcher` — `tmux new-session` for desktop terminals
- `service-companion-process` — pane management
- `service-manager` — service lifecycle via tmux

## Pitfalls

- **`$TMUX` is always set inside tmux** — but it points to the current
  server. If you're in the nested session, `$TMUX` correctly points to
  the nested socket. No need for manual override.
- **`basename` on socket path is reliable** — tmux always creates sockets
  as `/tmp/tmux-<uid>/<name>`. The default is literally named `default`.
- **Don't hardcode `-L`** — the user may switch between default and nested
  sockets. Always detect.
