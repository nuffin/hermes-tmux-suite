#!/bin/bash
# tmux-delegate-tail — Set up a tmux pane to tail a delegate_task live transcript.
#
# Usage:
#   tmux-delegate-tail <transcript> --create-pane [--session S] [--window W] [--keep]
#   tmux-delegate-tail <transcript> --pane P          [--session S] [--window W]
#
# --create-pane and --pane are mutually exclusive. One is required.
#
# Defaults:
#   No --session     → current session
#   No --window      → if session ≠ current: new window; else: current window
#   --pane           → KEEP=true implicitly (never close user's pane)
#
# Output (key=value, one per line):
#   AUTO_PANE=true/false
#   PANE=%N
#   SESSION=name
#   WINDOW=name
#   KEEP=true/false
#   AUTO_WINDOW=true/false
#   TMUX_FLAG=-L nested

set -euo pipefail

TRANSCRIPT="${1:?Usage: $0 <transcript_path> --create-pane [--session S] [--window W] [--keep]}"
shift

SESSION=""
WINDOW=""
PANE=""
KEEP=false
CREATE_PANE=false
USER_PANE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --create-pane) CREATE_PANE=true; shift ;;
        --pane)        PANE="$2"; USER_PANE=true; shift 2 ;;
        --session)     SESSION="$2"; shift 2 ;;
        --window)      WINDOW="$2";  shift 2 ;;
        --keep)        KEEP=true;    shift ;;
        *) shift ;;
    esac
done

if [ "$CREATE_PANE" = false ] && [ "$USER_PANE" = false ]; then
    # Neither given — default to creating a pane
    CREATE_PANE=true
fi
if [ "$CREATE_PANE" = true ] && [ "$USER_PANE" = true ]; then
    # Both given — --pane wins (user explicitly named a pane)
    CREATE_PANE=false
fi

# ── Detect tmux context ────────────────────────────────────────────────

if [ -z "${TMUX:-}" ]; then
    echo "ERROR: not inside tmux" >&2
    exit 1
fi

SOCKET_PATH=$(tmux display-message -p '#{socket_path}' 2>/dev/null)
SOCKET_NAME=$(basename "$SOCKET_PATH")
if [ "$SOCKET_NAME" != "default" ]; then
    TMUX_FLAG="-L $SOCKET_NAME"
else
    TMUX_FLAG=""
fi

CURRENT_SESSION=$(tmux $TMUX_FLAG display-message -p '#{session_name}')
CURRENT_WINDOW=$(tmux $TMUX_FLAG display-message -p '#{window_name}')

# ── Resolve session ────────────────────────────────────────────────────

if [ -z "$SESSION" ]; then
    SESSION="$CURRENT_SESSION"
fi

tmux $TMUX_FLAG has-session -t "$SESSION" 2>/dev/null || {
    echo "ERROR: session '$SESSION' does not exist" >&2
    exit 1
}

# ── Resolve window ─────────────────────────────────────────────────────

AUTO_WINDOW=false

if [ -z "$WINDOW" ]; then
    if [ "$SESSION" != "$CURRENT_SESSION" ]; then
        SHORT_NAME=$(basename "$TRANSCRIPT" .log | sed 's/^task-/t/' | head -c20)
        WINDOW="${SHORT_NAME}-log"
        tmux $TMUX_FLAG new-window -d -t "$SESSION" -n "$WINDOW"
        AUTO_WINDOW=true
    else
        WINDOW="$CURRENT_WINDOW"
    fi
fi

# ── Resolve pane ───────────────────────────────────────────────────────

AUTO_PANE=false

if [ "$USER_PANE" = true ]; then
    # User-provided — never close
    AUTO_PANE=false
    KEEP=true
elif [ "$AUTO_WINDOW" = true ]; then
    # New window — use its pane 0
    PANE="${SESSION}:${WINDOW}.0"
    AUTO_PANE=true
else
    # Split a new pane in session:window
    WIN_IDX=$(tmux $TMUX_FLAG list-windows -t "$SESSION" \
        -F '#{window_index}' -f "#{==:#{window_name},$WINDOW}")
    BEFORE_COUNT=$(tmux $TMUX_FLAG list-panes -t "${SESSION}:${WIN_IDX}" | wc -l)
    tmux $TMUX_FLAG split-window -v -l 8 -t "${SESSION}:${WIN_IDX}"
    AFTER_COUNT=$(tmux $TMUX_FLAG list-panes -t "${SESSION}:${WIN_IDX}" | wc -l)
    if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
        PANE=$(tmux $TMUX_FLAG display-message -t "${SESSION}:${WIN_IDX}" -p '#{pane_id}')
        AUTO_PANE=true
    else
        echo "FATAL: split-window failed in ${SESSION}:${WINDOW}" >&2
        exit 1
    fi
fi

# ── Run tail ───────────────────────────────────────────────────────────

tmux $TMUX_FLAG send-keys -t "$PANE" "tail -f '$TRANSCRIPT'" Enter

# ── Report ─────────────────────────────────────────────────────────────

echo "AUTO_PANE=$AUTO_PANE"
echo "PANE=$PANE"
echo "SESSION=$SESSION"
echo "WINDOW=$WINDOW"
echo "KEEP=$KEEP"
echo "AUTO_WINDOW=$AUTO_WINDOW"
echo "TMUX_FLAG=$TMUX_FLAG"
